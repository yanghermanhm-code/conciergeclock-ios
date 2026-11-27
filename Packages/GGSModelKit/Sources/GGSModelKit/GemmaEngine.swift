import Foundation
import GGSModelCore
import LiteRTLM

/// Runs a downloaded Gemma model on the iPhone with Google's LiteRT-LM. One request at a time;
/// each request is a fresh conversation, so nothing carries over between questions.
///
/// Loading takes several seconds (longer the first time, while LiteRT-LM prepares its GPU
/// cache), so the engine stays loaded until `unload()` (apps call it on memory warnings and
/// when they go to the background).
public actor GemmaEngine {
    public struct Options: Sendable {
        public var maxOutputTokens: Int
        public var temperature: Float
        public var topK: Int
        public var topP: Float
        /// A JSON schema the reply must follow (constrained decoding), or nil for free text.
        public var jsonSchema: String?
        /// Most seconds the reply may take; after that the request is abandoned and the
        /// engine reset (a hung call must not block every later request).
        public var timeoutSeconds: Double

        public init(maxOutputTokens: Int = 1024, temperature: Float = 0.4, topK: Int = 40, topP: Float = 0.95, jsonSchema: String? = nil, timeoutSeconds: Double = 150) {
            self.maxOutputTokens = maxOutputTokens
            self.temperature = temperature
            self.topK = topK
            self.topP = topP
            self.jsonSchema = jsonSchema
            self.timeoutSeconds = timeoutSeconds
        }
    }

    public enum EngineError: Error, Sendable {
        case modelNotInstalled
        case emptyReply
        case timedOut
        /// The model could not be loaded with its vision part (it has none, or this iPhone
        /// lacks the memory): pictures cannot be read on this iPhone.
        case visionUnavailable
    }

    public let store: SharedModelStore
    public let capability: DeviceCapability
    /// Where LiteRT-LM keeps its compiled GPU cache (per app; rebuilt if deleted).
    public let cacheDirectory: URL

    private var engine: Engine?
    public private(set) var loadedSpec: ModelSpec?
    public private(set) var loadedBackend: ModelSpec.Backend?
    /// Whether the loaded engine can look at images (its vision part is loaded). Only loaded
    /// when a picture is read: it needs more memory.
    public private(set) var loadedWithVision = false
    /// Set when loading the vision part failed, so later pictures fall back to text at once.
    public private(set) var visionFailed = false
    /// Interactive requests (marking the answer a student is waiting for) go to the front of
    /// the queue and interrupt background work (writing questions), which is retried later.
    public enum Priority: Sendable {
        case interactive, background
    }

    /// One request at a time (the actor alone would interleave requests at each await).
    private var busy = false
    private var waiters: [(priority: Priority, continuation: CheckedContinuation<Void, Never>)] = []
    private var current: (priority: Priority, task: Task<String, Error>)?
    /// Set after a request hung on the GPU: later loads use the CPU, which is slower but steady.
    public private(set) var forceCPU = false

    public init(store: SharedModelStore = .shared, capability: DeviceCapability = .current, cacheDirectory: URL? = nil) {
        self.store = store
        self.capability = capability
        self.cacheDirectory = cacheDirectory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("LiteRTLM", isDirectory: true)
    }

    /// Loads `spec` (unloading any other model). Tries the GPU when the iPhone has the memory
    /// for it, and falls back to the CPU if the GPU backend fails to start.
    public func load(_ spec: ModelSpec, vision: Bool = false) async throws {
        if loadedSpec == spec, engine != nil, loadedWithVision || !vision { return }
        if vision, visionFailed { throw EngineError.visionUnavailable }
        unload()
        guard store.isInstalled(spec), let path = store.fileURL(for: spec)?.path else { throw EngineError.modelNotInstalled }
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let preferred: ModelSpec.Backend = forceCPU ? .cpu : capability.backend(for: spec)
        let order: [ModelSpec.Backend] = preferred == .gpu ? [.gpu, .cpu] : [.cpu]
        var lastError: Error?
        for backend in order {
            do {
                let config = try EngineConfig(
                    modelPath: path,
                    backend: backend == .gpu ? .gpu : .cpu(),
                    visionBackend: vision ? (backend == .gpu ? .gpu : .cpu()) : nil,
                    // Room for the instructions, the passage and the reply.
                    maxNumTokens: 6144,
                    cacheDir: cacheDirectory.path
                )
                let candidate = Engine(engineConfig: config)
                // Loading can take a while the first time (GPU cache), but never forever.
                try await Self.race(Task { try await candidate.initialize() }, seconds: 180)
                engine = candidate
                loadedSpec = spec
                loadedBackend = backend
                loadedWithVision = vision
                return
            } catch {
                lastError = error
            }
        }
        if vision {
            visionFailed = true
            throw EngineError.visionUnavailable
        }
        throw lastError ?? EngineError.modelNotInstalled
    }

    /// Frees the model's memory.
    public func unload() {
        engine = nil
        loadedSpec = nil
        loadedBackend = nil
        loadedWithVision = false
    }

    /// Loads `spec` if needed, then answers. Requests wait their turn; interactive ones first.
    /// - Parameter imageFile: an image (absolute path) Gemma looks at with the prompt. The
    ///   engine is reloaded with its vision part the first time; `visionUnavailable` if that fails.
    public func run(_ spec: ModelSpec, system: String, prompt: String, imageFile: String? = nil, options: Options = Options(), priority: Priority = .background) async throws -> String {
        await acquire(priority)
        defer { release() }
        try Task.checkCancellation()
        try await load(spec, vision: imageFile != nil)
        guard let engine else { throw EngineError.modelNotInstalled }
        let work = Task { try await Self.converse(engine: engine, system: system, prompt: prompt, imageFile: imageFile, options: options) }
        current = (priority, work)
        defer { current = nil }
        do {
            return try await withTaskCancellationHandler {
                try await Self.race(work, seconds: options.timeoutSeconds)
            } onCancel: {
                work.cancel()
            }
        } catch EngineError.timedOut {
            // The runtime did not answer: drop this engine (a new one is made next time) and
            // stop using the GPU, the likeliest cause of a hang.
            work.cancel()
            if loadedBackend == .gpu { forceCPU = true }
            unload()
            throw EngineError.timedOut
        }
    }

    /// The work's result, or `timedOut` after `seconds` — without waiting for work that
    /// ignores cancellation.
    private nonisolated static func race<T: Sendable>(_ work: Task<T, Error>, seconds: Double) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let once = Once<T>(continuation)
            Task { do { once.resume(.success(try await work.value)) } catch { once.resume(.failure(error)) } }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                once.resume(.failure(EngineError.timedOut))
            }
        }
    }

    private final class Once<T: Sendable>: @unchecked Sendable {
        private var continuation: CheckedContinuation<T, Error>?
        private let lock = NSLock()
        init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }
        func resume(_ result: Result<T, Error>) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(with: result)
        }
    }

    /// Loads the model ahead of time (e.g. when a study session starts), so the first answer
    /// is not kept waiting for it.
    public func prewarm(_ spec: ModelSpec) async {
        await acquire(.interactive)
        defer { release() }
        try? await load(spec)
    }

    private func acquire(_ priority: Priority) async {
        guard busy else {
            busy = true
            return
        }
        if priority == .interactive {
            // Interrupt background work so the student is not kept waiting.
            if let current, current.priority == .background { current.task.cancel() }
            let firstBackground = waiters.firstIndex { $0.priority == .background } ?? waiters.endIndex
            await withCheckedContinuation { waiters.insert((priority, $0), at: firstBackground) }
        } else {
            await withCheckedContinuation { waiters.append((priority, $0)) }
        }
    }

    private func release() {
        if waiters.isEmpty {
            busy = false
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }

    /// Builds the conversation, message and response format here, outside the actor, so no
    /// non-Sendable LiteRT-LM value crosses an isolation boundary.
    private nonisolated static func converse(engine: Engine, system: String, prompt: String, imageFile: String?, options: Options) async throws -> String {
        let sampler = try SamplerConfig(topK: options.topK, topP: options.topP, temperature: options.temperature)
        let config = ConversationConfig(
            systemMessage: Message(system, role: .system),
            samplerConfig: sampler,
            enableResponseFormat: options.jsonSchema != nil
        )
        let conversation = try await engine.createConversation(with: config)
        let schema = options.jsonSchema
        let maxTokens = options.maxOutputTokens
        let text = try await withTaskCancellationHandler {
            let format = try schema.map { try ResponseFormat.json(schema: $0) }
            // The image comes before the text, as Gemma expects.
            let message = imageFile.map { Message(contents: [.imageFile($0), .text(prompt)]) } ?? Message(prompt)
            let reply = try await conversation.sendMessage(message, maxOutputTokens: maxTokens, responseFormat: format)
            return reply.toString
        } onCancel: {
            try? conversation.cancel()
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EngineError.emptyReply }
        return trimmed
    }
}

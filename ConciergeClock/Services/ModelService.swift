import ConciergeCore
import Foundation
import GGSModelCore
import GGSModelKit
import Observation
import UIKit

/// The offline AI model (Gemma) for ConciergeClock: which model to use on this iPhone, its
/// download, and the engine that runs it. The model file is shared with Greater Good
/// Software's other apps through the App Group in GGSModelCore, so a model PrepPilot,
/// FocusFound or FotoPhilter already downloaded is ready here too. Same service as PrepPilot's.
@MainActor
@Observable
final class ModelService {
    /// One downloader per app process (its background URLSession has a fixed identifier).
    static let downloader = ModelDownloader()

    /// For `.backgroundTask(.urlSession(...))`: a download finished while the app was closed.
    static var sessionIdentifier: String { downloader.sessionIdentifier }

    static func handleBackgroundEvents() async {
        await downloader.handleBackgroundEvents()
    }

    let capability = DeviceCapability.current
    let engine = GemmaEngine()
    var downloader: ModelDownloader { Self.downloader }
    private let settings: SettingsStore
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(settings: SettingsStore) {
        self.settings = settings
        let engine = self.engine
        // Free the model's memory when iOS asks, and while the app is in the background
        // (Nightstand Mode, Phase 3, loads it again a few minutes before the alarm).
        for name in [UIApplication.didReceiveMemoryWarningNotification, UIApplication.didEnterBackgroundNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { await engine.unload() }
            })
        }
    }

    // MARK: Which model

    /// The model the settings ask for (automatic = what this iPhone runs well), or nil when
    /// this iPhone cannot run one.
    var chosenSpec: ModelSpec? {
        if let id = settings.settings.localModel.modelID, let spec = ModelCatalog.spec(id: id), capability.canRun(spec) {
            return spec
        }
        return capability.recommendedModel
    }

    /// The model in use now: chosen, downloaded and turned on.
    var activeSpec: ModelSpec? {
        guard settings.settings.useOfflineAI, let spec = chosenSpec, downloader.state(spec) == .installed else { return nil }
        return spec
    }

    var isSupported: Bool { capability.recommendedModel != nil }

    /// Whether the offline AI is ready to use.
    var isReady: Bool { activeSpec != nil }

    /// The model behind ConciergeCore's `TextGenerating`, or nil to use the built-in rules.
    /// `interactive` for work the user is waiting for (a spoken reply): it goes ahead of
    /// background work (preparing tomorrow's briefing).
    func textGenerator(interactive: Bool = false) -> (any TextGenerating)? {
        activeSpec.map { GemmaTextGenerator(engine: engine, spec: $0, priority: interactive ? .interactive : .background) }
    }

    /// Loads the model in the background, so the next reply does not wait for it.
    func prewarm() {
        guard let spec = activeSpec else { return }
        let engine = self.engine
        Task.detached(priority: .userInitiated) { await engine.prewarm(spec) }
    }

    /// Re-reads the shared folder (another app may have downloaded or deleted a model).
    func refresh() {
        downloader.refresh()
    }

    // MARK: Self-test

    /// One measured step of "Test offline AI".
    struct TestStep: Identifiable, Sendable {
        enum Kind: Sendable { case load, plainReply, speed, jsonReply }
        let id = UUID()
        let kind: Kind
        let ok: Bool
        let seconds: Double
        /// Load: "GPU"/"CPU"; speed: words per second; otherwise the error, if any.
        let detail: String
    }

    /// Loads the model and times a plain reply, a longer reply (speed) and a JSON reply (the
    /// format the importance ranking uses), to see on this iPhone what works and how fast.
    /// Every step has a time limit.
    func selfTest(progress: @escaping @MainActor (TestStep) -> Void) async {
        guard let spec = chosenSpec, downloader.state(spec) == .installed else { return }
        let engine = self.engine
        await engine.unload()

        var started = Date()
        await engine.prewarm(spec)
        let backend = await engine.loadedBackend
        progress(TestStep(kind: .load, ok: backend != nil, seconds: Date().timeIntervalSince(started),
                          detail: backend.map { $0 == .gpu ? "GPU" : "CPU" } ?? "—"))
        guard backend != nil else { return }

        func timed(_ kind: TestStep.Kind, prompt: String, system: String = "Answer briefly.", tokens: Int,
                   check: @escaping (String) -> String?) async {
            started = Date()
            do {
                let options = GemmaEngine.Options(maxOutputTokens: tokens, temperature: 0, jsonSchema: nil, timeoutSeconds: 90)
                let reply = try await engine.run(spec, system: system, prompt: prompt, options: options, priority: .interactive)
                let seconds = Date().timeIntervalSince(started)
                if let problem = check(reply) {
                    progress(TestStep(kind: kind, ok: false, seconds: seconds, detail: problem))
                } else if kind == .speed {
                    let words = reply.split(whereSeparator: \.isWhitespace).count
                    progress(TestStep(kind: kind, ok: true, seconds: seconds, detail: String(format: "%.1f", Double(words) / max(seconds, 0.1))))
                } else {
                    progress(TestStep(kind: kind, ok: true, seconds: seconds, detail: ""))
                }
            } catch {
                progress(TestStep(kind: kind, ok: false, seconds: Date().timeIntervalSince(started), detail: String(describing: error)))
            }
        }

        await timed(.plainReply, prompt: "Reply with the single word OK.", tokens: 8) { $0.isEmpty ? "empty reply" : nil }
        await timed(.speed, prompt: "Write three short sentences a butler might say when waking someone up.", tokens: 120) {
            $0.count < 20 ? "reply too short" : nil
        }
        let schema = #"{"type":"object","properties":{"important":{"type":"boolean"},"reason":{"type":"string"}},"required":["important","reason"]}"#
        await timed(.jsonReply, prompt: "Event: \"Job interview with Acme\" at 9:30. Is it important?",
                    system: "Answer briefly. Reply with only one JSON object that matches this JSON schema, and no other text:\n" + schema,
                    tokens: 60) { reply in reply.contains("\"important\"") ? nil : "no JSON in the reply" }
    }

    func download(_ spec: ModelSpec) {
        downloader.download(spec, cellular: !settings.settings.modelDownloadWiFiOnly)
    }

    func delete(_ spec: ModelSpec) throws {
        Task { await engine.unload() }
        try downloader.delete(spec)
    }
}

/// Gemma behind ConciergeCore's `TextGenerating`.
struct GemmaTextGenerator: TextGenerating {
    let engine: GemmaEngine
    let spec: ModelSpec
    var priority: GemmaEngine.Priority = .background

    var modelName: String { spec.displayName }

    func generate(system: String, prompt: String, jsonSchema: String?, maxTokens: Int, temperature: Double) async throws -> String {
        var instructions = system
        // LiteRT-LM's enforced JSON can be very slow on iPhone (PrepPilot's finding), so the
        // schema goes in the instructions and the reader tolerates text around the JSON.
        if let jsonSchema {
            instructions += "\n\nReply with only one JSON object that matches this JSON schema, and no other text:\n" + jsonSchema
        }
        let options = GemmaEngine.Options(
            maxOutputTokens: maxTokens, temperature: Float(temperature), jsonSchema: nil,
            timeoutSeconds: priority == .interactive ? 45 : 150
        )
        return try await engine.run(spec, system: instructions, prompt: prompt, options: options, priority: priority)
    }
}

import Foundation
import Observation

/// Downloads models into the shared store with a background URLSession, so a download keeps
/// going when the app is closed and resumes after an interruption. The file is checked
/// against its SHA-256 before it is used.
@MainActor
@Observable
public final class ModelDownloader: NSObject {
    public enum State: Equatable, Sendable {
        case idle
        /// 0…1, and bytes received so far.
        case downloading(progress: Double, received: Int64)
        /// Stopped by the student or by the network; can resume.
        case paused
        /// Downloaded; checking the SHA-256.
        case verifying
        case installed
        case failed(ModelDownloadFailure)
    }

    public private(set) var states: [String: State] = [:]

    public let store: SharedModelStore
    public let sessionIdentifier: String
    /// Resume data per model id, kept in this app's caches (only this app can resume it).
    private var resumeData: [String: Data] = [:]
    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private var tasks: [String: URLSessionDownloadTask] = [:]
    @ObservationIgnored private var backgroundCompletion: (() -> Void)?
    @ObservationIgnored private var eventsFinishedEarly = false

    public init(store: SharedModelStore = .shared, sessionIdentifier: String = (Bundle.main.bundleIdentifier ?? "app") + ".models") {
        self.store = store
        self.sessionIdentifier = sessionIdentifier
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        if store.isShared { configuration.sharedContainerIdentifier = SharedModelStore.appGroup }
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        for spec in ModelCatalog.all {
            states[spec.id] = store.isInstalled(spec) ? .installed : .idle
            if let data = try? Data(contentsOf: resumeURL(spec)) { resumeData[spec.id] = data; states[spec.id] = .paused }
        }
        // Reattach to downloads that kept running while the app was closed.
        session.getAllTasks { [weak self] tasks in
            let found: [(String, URLSessionDownloadTask)] = tasks.compactMap { task in
                guard let task = task as? URLSessionDownloadTask, let id = task.taskDescription else { return nil }
                return (id, task)
            }
            Task { @MainActor in
                for (id, task) in found {
                    self?.tasks[id] = task
                    self?.states[id] = .downloading(progress: task.progress.fractionCompleted, received: task.countOfBytesReceived)
                }
            }
        }
    }

    public func state(_ spec: ModelSpec) -> State {
        states[spec.id] ?? .idle
    }

    /// Re-reads the store (another app may have downloaded or deleted a model).
    public func refresh() {
        for spec in ModelCatalog.all where tasks[spec.id] == nil {
            if store.isInstalled(spec) {
                states[spec.id] = .installed
            } else if states[spec.id] == .installed {
                states[spec.id] = .idle
            }
        }
    }

    /// Starts or resumes a download. `cellular` false keeps it to Wi-Fi.
    public func download(_ spec: ModelSpec, cellular: Bool) {
        guard tasks[spec.id] == nil, !store.isInstalled(spec) else { return }
        guard store.isAvailable else { states[spec.id] = .failed(.appGroupMissing); return }
        let needed = spec.sizeBytes * 2 // download + a moment with both files
        guard SharedModelStore.freeBytes() >= needed else { states[spec.id] = .failed(.notEnoughSpace(needed: needed)); return }
        let task: URLSessionDownloadTask
        if let data = resumeData[spec.id] {
            task = session.downloadTask(withResumeData: data)
        } else {
            var request = URLRequest(url: spec.downloadURL)
            request.allowsCellularAccess = cellular
            request.allowsExpensiveNetworkAccess = cellular
            task = session.downloadTask(with: request)
        }
        task.taskDescription = spec.id
        task.countOfBytesClientExpectsToReceive = spec.sizeBytes
        tasks[spec.id] = task
        resumeData[spec.id] = nil
        try? FileManager.default.removeItem(at: resumeURL(spec))
        states[spec.id] = .downloading(progress: 0, received: 0)
        task.resume()
    }

    public func pause(_ spec: ModelSpec) {
        guard let task = tasks.removeValue(forKey: spec.id) else { return }
        states[spec.id] = .paused
        task.cancel { [weak self] data in
            Task { @MainActor in self?.saveResumeData(data, for: spec) }
        }
    }

    public func cancel(_ spec: ModelSpec) {
        tasks.removeValue(forKey: spec.id)?.cancel()
        resumeData[spec.id] = nil
        try? FileManager.default.removeItem(at: resumeURL(spec))
        states[spec.id] = store.isInstalled(spec) ? .installed : .idle
    }

    public func delete(_ spec: ModelSpec) throws {
        cancel(spec)
        try store.delete(spec)
        states[spec.id] = .idle
    }

    /// For SwiftUI's `.backgroundTask(.urlSession(...))`: returns when the system has
    /// delivered all events of a download that finished while the app was closed.
    public func handleBackgroundEvents() async {
        if eventsFinishedEarly {
            eventsFinishedEarly = false
            return
        }
        await withCheckedContinuation { continuation in
            backgroundCompletion = { continuation.resume() }
        }
    }

    // MARK: Private

    private func resumeURL(_ spec: ModelSpec) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(spec.fileName + ".resume")
    }

    private func saveResumeData(_ data: Data?, for spec: ModelSpec) {
        guard let data else { return }
        resumeData[spec.id] = data
        try? data.write(to: resumeURL(spec))
    }

    fileprivate func progressed(_ id: String, written: Int64, expected: Int64) {
        guard tasks[id] != nil else { return }
        let total = expected > 0 ? expected : (ModelCatalog.spec(id: id)?.sizeBytes ?? 1)
        states[id] = .downloading(progress: min(1, Double(written) / Double(total)), received: written)
    }

    fileprivate func downloaded(_ id: String, to staged: URL?) {
        tasks[id] = nil
        guard let spec = ModelCatalog.spec(id: id), let staged else {
            states[id] = .failed(.network)
            return
        }
        states[id] = .verifying
        let store = self.store
        Task.detached(priority: .utility) {
            let result: State
            do {
                try store.install(downloadedFile: staged, as: spec)
                result = .installed
            } catch {
                // Wrong size or checksum: the bad file is deleted; the student can try again.
                result = .failed(.checksum)
            }
            await MainActor.run { self.states[id] = result }
        }
    }

    fileprivate func failed(_ id: String, resumeData data: Data?, cancelled: Bool) {
        guard tasks.removeValue(forKey: id) != nil || data != nil else { return }
        if let spec = ModelCatalog.spec(id: id) { saveResumeData(data, for: spec) }
        if cancelled { return }
        states[id] = data != nil ? .paused : .failed(.network)
    }

    fileprivate func finishedBackgroundEvents() {
        if let backgroundCompletion {
            backgroundCompletion()
            self.backgroundCompletion = nil
        } else {
            eventsFinishedEarly = true
        }
    }
}

public enum ModelDownloadFailure: Equatable, Sendable {
    case network
    case checksum
    case appGroupMissing
    case notEnoughSpace(needed: Int64)
}

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription else { return }
        Task { @MainActor in self.progressed(id, written: totalBytesWritten, expected: totalBytesExpectedToWrite) }
    }

    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        // The temporary file disappears when this method returns: move it now.
        var staged: URL?
        let store = self.store
        if let spec = ModelCatalog.spec(id: id), let partial = store.partialURL(for: spec),
           (downloadTask.response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false {
            _ = try? store.prepareFolder()
            try? FileManager.default.removeItem(at: partial)
            if (try? FileManager.default.moveItem(at: location, to: partial)) != nil { staged = partial }
        }
        let result = staged
        Task { @MainActor in self.downloaded(id, to: result) }
    }

    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let id = task.taskDescription else { return }
        let nsError = error as NSError
        let data = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let cancelled = nsError.code == NSURLErrorCancelled && data == nil
        Task { @MainActor in self.failed(id, resumeData: data, cancelled: cancelled) }
    }

    nonisolated public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in self.finishedBackgroundEvents() }
    }
}

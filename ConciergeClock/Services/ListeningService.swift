import AVFoundation
import Foundation
import Speech

/// Listens for one spoken reply with Apple's speech recognition, on the iPhone (on-device
/// recognition is required when the language supports it, so nothing is sent to Apple). What
/// was said is returned as text and never stored.
@MainActor
final class ListeningService {
    enum Permission: Equatable {
        case granted, denied, notDetermined
    }

    private let microphone = MicrophoneTap()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Microphone and speech recognition together.
    static var permission: Permission {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let microphone = AVAudioApplication.shared.recordPermission
        if speech == .authorized, microphone == .granted { return .granted }
        if speech == .denied || speech == .restricted || microphone == .denied { return .denied }
        return .notDetermined
    }

    /// Asks for the microphone and speech recognition (each once).
    static func requestPermission() async -> Bool {
        let microphone = await AVAudioApplication.requestRecordPermission()
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in continuation.resume(returning: status) }
        }
        return microphone && speech == .authorized
    }

    /// The recogniser for the briefing language (the accent's locale for English), preferring
    /// recognition on the iPhone. Nil when the language cannot be recognised on this iPhone.
    static func recognizer(for locales: [String]) -> SFSpeechRecognizer? {
        for identifier in locales {
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier)), recognizer.isAvailable,
               recognizer.supportsOnDeviceRecognition {
                return recognizer
            }
        }
        return nil
    }

    /// Listens until the person stops talking (about 1.5 s of silence after words), or
    /// `timeout` seconds pass with nothing said. Returns the words heard ("" for nothing).
    /// The conversation audio session (play and record, loudspeaker) must already be active.
    func listen(with recognizer: SFSpeechRecognizer, timeout: TimeInterval = 8) async -> String {
        stop()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .confirmation
        // Starting the microphone can block, so it happens on the audio queue.
        guard await microphone.start(feeding: request) else { return "" }
        self.request = request

        let collector = TranscriptCollector()
        task = recognizer.recognitionTask(with: request) { @Sendable result, error in
            if let result {
                collector.update(result.bestTranscription.formattedString, final: result.isFinal)
            }
            if error != nil { collector.update(nil, final: true) }
        }

        // Poll: finished, silent for 1.5 s after speech, or timed out.
        let started = Date()
        while true {
            try? await Task.sleep(for: .milliseconds(200))
            let state = collector.state
            if state.final || Task.isCancelled { break }
            if let last = state.lastChange, !state.text.isEmpty, Date().timeIntervalSince(last) > 1.5 { break }
            if state.text.isEmpty, Date().timeIntervalSince(started) > timeout { break }
            if Date().timeIntervalSince(started) > timeout + 12 { break }
        }
        let text = collector.state.text
        stop()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stop() {
        microphone.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}

/// The microphone, run on the audio queue (starting and stopping it can block the main thread).
/// Every use of `engine` happens on that one serial queue.
private final class MicrophoneTap: @unchecked Sendable {
    private var engine: AVAudioEngine?

    /// Feeds the microphone into `request`. False when the microphone cannot start.
    func start(feeding request: SFSpeechAudioBufferRecognitionRequest) async -> Bool {
        // The request accepts buffers from the audio thread (Apple's documented use).
        nonisolated(unsafe) let feed = request
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SpeechService.audioQueue.async {
                self.stopNow()
                let engine = AVAudioEngine()
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0 else {
                    continuation.resume(returning: false)
                    return
                }
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
                    feed.append(buffer)
                }
                engine.prepare()
                do {
                    try engine.start()
                } catch {
                    input.removeTap(onBus: 0)
                    continuation.resume(returning: false)
                    return
                }
                self.engine = engine
                continuation.resume(returning: true)
            }
        }
    }

    func stop() {
        SpeechService.audioQueue.async { self.stopNow() }
    }

    /// On the audio queue only.
    private func stopNow() {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
    }
}

/// Collects recognition results from the recogniser's own queue.
private final class TranscriptCollector: @unchecked Sendable {
    struct State {
        var text = ""
        var final = false
        var lastChange: Date?
    }

    private let lock = NSLock()
    private var current = State()

    var state: State {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func update(_ text: String?, final: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if let text, text != current.text {
            current.text = text
            current.lastChange = Date()
        }
        if final { current.final = true }
    }
}

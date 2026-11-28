import AVFoundation
import ConciergeCore
import Foundation

/// Records the butler's alarm announcement into each ring's own alarm sound, so that even with
/// ConciergeClock closed the alarm says which alarm it is, what comes next, and asks: dismiss,
/// or remind again? (Then "Respond" opens the app to listen for the answer.)
///
/// Files are `Library/Sounds/ccring-<ring id>.wav`; files of rings that no longer exist are
/// removed. If speech cannot be recorded (no voice for the language), the plain alarm sound is
/// used instead.
@MainActor
final class RingSoundRenderer {
    private let synthesizer = AVSpeechSynthesizer()

    static func fileName(for ringID: UUID) -> String {
        "ccring-\(ringID.uuidString).wav"
    }

    /// Writes the announcement sound for one ring. Returns the file name, or nil to use the
    /// plain sound.
    func render(ringID: UUID, announcement: Briefing, persona: Persona, sound: AlarmSound) async -> String? {
        guard let folder = SoundLibrary.folder else { return nil }
        let text = announcement.lines.map(\.text).joined(separator: " ")
        guard let speech = await speechSamples(text, persona: persona),
              let samples = AlarmToneSynthesizer.announcement(sound: sound, speech: speech.samples, speechRate: speech.rate) else { return nil }
        let name = Self.fileName(for: ringID)
        let url = folder.appendingPathComponent(name)
        let data = AlarmToneSynthesizer.wav(samples: samples)
        let written = await Task.detached(priority: .utility) { () -> Bool in
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return (try? data.write(to: url, options: .atomic)) != nil
        }.value
        return written ? name : nil
    }

    /// Whether a recent recording exists for this ring (re-recorded at most hourly, so the
    /// "next item" stays current without redoing every ring on every change).
    static func isFresh(ringID: UUID, now: Date = Date()) -> Bool {
        guard let folder = SoundLibrary.folder else { return false }
        let path = folder.appendingPathComponent(fileName(for: ringID)).path
        guard let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date else { return false }
        return now.timeIntervalSince(date) < 3600
    }

    /// Deletes recordings of rings that are not scheduled any more.
    static func prune(keeping ringIDs: Set<UUID>) {
        guard let folder = SoundLibrary.folder else { return }
        let keep = Set(ringIDs.map(fileName(for:)))
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        where name.hasPrefix("ccring-") && !keep.contains(name) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    /// The speech as mono samples, using the persona's voice and delivery.
    private func speechSamples(_ text: String, persona: Persona) async -> (samples: [Float], rate: Double)? {
        guard !text.isEmpty, let voice = VoiceCatalog.voice(for: persona) else { return nil }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        let prosody = Prosody.forPersona(persona)
        utterance.rate = prosody.rate
        utterance.pitchMultiplier = prosody.pitch
        let collector = SpeechBufferCollector()
        return await withCheckedContinuation { (continuation: CheckedContinuation<(samples: [Float], rate: Double)?, Never>) in
            collector.continuation = continuation
            synthesizer.write(utterance) { @Sendable buffer in
                collector.append(buffer)
            }
            // Safety net: never wait more than 20 seconds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { collector.finish() }
        }
    }
}

/// Gathers the synthesiser's audio buffers (delivered on its own queue).
private final class SpeechBufferCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var rate: Double = 22_050
    private var done = false
    var continuation: CheckedContinuation<(samples: [Float], rate: Double)?, Never>?

    func append(_ buffer: AVAudioBuffer) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        let count = Int(pcm.frameLength)
        // A zero-length buffer marks the end.
        guard count > 0 else {
            finish()
            return
        }
        lock.lock()
        rate = pcm.format.sampleRate
        if let floats = pcm.floatChannelData {
            samples.append(contentsOf: UnsafeBufferPointer(start: floats[0], count: count))
        } else if let ints = pcm.int16ChannelData {
            samples.append(contentsOf: UnsafeBufferPointer(start: ints[0], count: count).map { Float($0) / 32_768 })
        }
        lock.unlock()
    }

    func finish() {
        lock.lock()
        guard !done else {
            lock.unlock()
            return
        }
        done = true
        let result = samples.isEmpty ? nil : (samples: samples, rate: rate)
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: result)
    }
}

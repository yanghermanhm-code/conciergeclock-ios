import AVFoundation
import ConciergeCore
import Foundation
import Observation

/// The alarm sounds as files. iOS (AlarmKit) can only ring with a custom sound that is a file in
/// the app's `Library/Sounds/` folder, so each synthesised sound is rendered there once (in the
/// background, at launch) and re-rendered only when the sound design changes. Also plays
/// previews in the alarm editor.
@MainActor
@Observable
final class SoundLibrary {
    /// The sound being previewed, if any.
    private(set) var previewing: AlarmSound?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var stopTask: Task<Void, Never>?

    /// `Library/Sounds/` in the app's container.
    nonisolated static var folder: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    /// The rendered file for `sound`, or nil for the iPhone default / not rendered yet.
    nonisolated static func fileURL(for sound: AlarmSound) -> URL? {
        guard let name = sound.fileName, let folder else { return nil }
        let url = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Renders every missing sound and removes files of older sound designs. Safe to call often.
    func prepare() {
        Task.detached(priority: .utility) {
            Self.renderMissing()
        }
    }

    /// Renders what is missing now (used before scheduling an alarm with a custom sound).
    nonisolated static func renderMissing() {
        guard let folder else { return }
        let manager = FileManager.default
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let wanted = Set(AlarmSound.allCases.compactMap(\.fileName))
        for name in (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
        where name.hasPrefix("concierge-") && !wanted.contains(name) {
            try? manager.removeItem(at: folder.appendingPathComponent(name))
        }
        for sound in AlarmSound.allCases {
            guard let name = sound.fileName else { continue }
            let url = folder.appendingPathComponent(name)
            guard !manager.fileExists(atPath: url.path), let data = AlarmToneSynthesizer.wav(sound) else { continue }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: Preview

    /// Plays the first seconds of `sound` (tap again to stop).
    func togglePreview(_ sound: AlarmSound) {
        if previewing == sound {
            stopPreview()
            return
        }
        stopPreview()
        guard sound.isSynthesised else { return }
        Task {
            // Render on demand if the launch render has not finished yet, and use the playback
            // audio session so the preview is heard in silent mode (off the main thread: these
            // calls can block).
            let file = await Task.detached(priority: .userInitiated) { () -> URL? in
                if Self.fileURL(for: sound) == nil { Self.renderMissing() }
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
                try? session.setActive(true)
                return Self.fileURL(for: sound)
            }.value
            guard let file, let player = try? AVAudioPlayer(contentsOf: file) else { return }
            self.player = player
            previewing = sound
            player.play()
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                self?.stopPreview()
            }
        }
    }

    func stopPreview() {
        stopTask?.cancel()
        player?.stop()
        player = nil
        previewing = nil
    }
}

@testable import ConciergeCore
import XCTest

final class SoundTests: XCTestCase {
    func testEverySynthesisedSoundRendersAFullLoudWAV() throws {
        for sound in AlarmSound.allCases where sound.isSynthesised {
            let samples = try XCTUnwrap(AlarmToneSynthesizer.render(sound, sampleRate: 8_000, duration: 6), sound.rawValue)
            XCTAssertEqual(samples.count, 48_000, sound.rawValue)
            let peak = samples.map(abs).max() ?? 0
            XCTAssertEqual(peak, 0.89, accuracy: 0.01, sound.rawValue)
            // Still sounding in the second half (the motif repeats).
            let secondHalf = samples[24_000..<44_000].map(abs).max() ?? 0
            XCTAssertGreaterThan(secondHalf, 0.05, sound.rawValue)
        }
    }

    func testDefaultsAndFiles() {
        XCTAssertNil(AlarmToneSynthesizer.render(.iPhoneDefault))
        XCTAssertNil(AlarmSound.iPhoneDefault.fileName)
        XCTAssertEqual(AlarmSound.resolve("nonsense"), .conciergeBell)
        XCTAssertEqual(AlarmSound.resolve("chime.soft"), .chime)
        XCTAssertEqual(Alarm().soundID, "bell.concierge")
        XCTAssertEqual(AlarmSound.conciergeBell.fileName, "concierge-bell-concierge-v1.wav")
        let wav = AlarmToneSynthesizer.wav(.digital)
        XCTAssertEqual(wav.map { String(decoding: $0.prefix(4), as: UTF8.self) }, "RIFF")
    }

    func testAnnouncementMixesChimeAndSpeechToFullLength() throws {
        // One second of a 440 Hz tone at 24 kHz stands in for the speech.
        let speech = (0..<24_000).map { Float(sin(Double($0) * 2 * .pi * 440 / 24_000)) * 0.3 }
        let mixed = try XCTUnwrap(AlarmToneSynthesizer.announcement(sound: .chime, speech: speech, speechRate: 24_000, duration: 10))
        XCTAssertEqual(mixed.count, Int(10 * AlarmToneSynthesizer.sampleRate))
        // The speech is normalised to full level: it is as loud as the chime's peak.
        XCTAssertGreaterThan(mixed.map(abs).max() ?? 0, 0.8)
        XCTAssertNil(AlarmToneSynthesizer.announcement(sound: .chime, speech: [], speechRate: 24_000))
        XCTAssertEqual(AlarmToneSynthesizer.resample([0, 1, 0, -1], from: 2, to: 1).count, 2)
    }
}

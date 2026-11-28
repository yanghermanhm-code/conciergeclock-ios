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
}

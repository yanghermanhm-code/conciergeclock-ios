import Foundation

/// The sounds an alarm can ring with. Every one except the iPhone's default is synthesised on
/// the device (`AlarmToneSynthesizer`), so the app ships no audio files and no sound can go
/// missing. Raw values are stored in alarms and backups: never rename them.
public enum AlarmSound: String, CaseIterable, Identifiable, Sendable {
    /// A concierge's service bell, rung twice, then again: the signature sound.
    case conciergeBell = "bell.concierge"
    /// Westminster quarters, as a grandfather clock chimes them (a public-domain melody).
    case grandfatherClock = "clock.westminster"
    /// Rising tuned-tube chimes (FocusFound's "Pleasant Chime").
    case chime = "chime.soft"
    /// Gentle at first, then louder and brighter.
    case gentleRise = "chime.rising"
    /// A struck acoustic bell with a long ring.
    case acousticBell = "bell.acoustic"
    /// A Tibetan-style singing bowl.
    case singingBowl = "bowl.singing"
    /// A rising wooden marimba arpeggio.
    case marimba = "marimba.wood"
    /// A short music-box melody.
    case musicBox = "musicbox.bright"
    /// Classic digital alarm-clock beeps.
    case digital = "beep.digital"
    /// The iPhone's own alarm sound.
    case iPhoneDefault = "system.default"

    public var id: String { rawValue }

    public static let `default`: AlarmSound = .conciergeBell

    /// Unknown or empty identifiers fall back to the default sound.
    public static func resolve(_ id: String?) -> AlarmSound {
        id.flatMap(AlarmSound.init(rawValue:)) ?? .default
    }

    /// Whether the app renders this sound (everything but the iPhone default).
    public var isSynthesised: Bool { self != .iPhoneDefault }

    /// File name of the rendered copy in `Library/Sounds/`. The version suffix lets a change to
    /// the synthesis replace old files.
    public var fileName: String? {
        guard isSynthesised else { return nil }
        return "concierge-\(rawValue.replacingOccurrences(of: ".", with: "-"))-v\(AlarmToneSynthesizer.version).wav"
    }
}

/// Renders the alarm sounds with additive synthesis (decaying sine partials plus a short
/// strike), repeating each sound's motif to fill `AlarmToneSynthesizer.duration`. Pure Swift and
/// deterministic, so every iPhone gets the same sound and it can be unit-tested. The instrument
/// models come from FocusFound's ChimeSynthesizer.
public enum AlarmToneSynthesizer {
    /// Bump when the sound design changes, so cached files are re-rendered.
    public static let version = 1
    public static let sampleRate: Double = 22_050
    /// Length of every rendered alarm sound: under the 30-second limit iOS puts on custom alert
    /// sounds.
    public static let duration: Double = 28

    /// Mono samples in -1…1, peak-normalised to about -1 dBFS. Nil for the iPhone default.
    public static func render(_ sound: AlarmSound, sampleRate: Double = AlarmToneSynthesizer.sampleRate, duration: Double = AlarmToneSynthesizer.duration) -> [Float]? {
        guard let motif = motif(for: sound) else { return nil }
        var buffer = [Float](repeating: 0, count: Int(duration * sampleRate))
        var offset = 0.0
        var repetition = 0
        while offset < duration {
            // "Gentle rise" starts quietly and reaches full level after about 12 seconds.
            let level = sound == .gentleRise ? min(1, 0.25 + Double(repetition) * 0.25) : 1
            for var note in motif.notes {
                note.start += offset
                note.gain *= level
                add(note, to: &buffer, sampleRate: sampleRate)
            }
            offset += motif.period
            repetition += 1
        }
        normalise(&buffer, peak: 0.89)
        fadeOut(&buffer, seconds: 0.4, sampleRate: sampleRate)
        return buffer
    }

    /// An alarm sound with the butler's announcement in it, for when the app is closed: a short
    /// burst of `sound`, the speech, a pause, again until `duration`. `speech` is mono at
    /// `speechRate` and is resampled. Returns nil when there is no speech (use the plain sound).
    public static func announcement(sound: AlarmSound, speech: [Float], speechRate: Double, duration: Double = AlarmToneSynthesizer.duration) -> [Float]? {
        guard !speech.isEmpty, speechRate > 0 else { return nil }
        let chime = render(sound == .iPhoneDefault ? .conciergeBell : sound, duration: 3) ?? []
        var voice = resample(speech, from: speechRate, to: sampleRate)
        normalise(&voice, peak: 0.89)
        var output: [Float] = []
        let total = Int(duration * sampleRate)
        let gap = [Float](repeating: 0, count: Int(0.4 * sampleRate))
        let pause = [Float](repeating: 0, count: Int(1.5 * sampleRate))
        while output.count < total {
            output += chime.map { $0 * 0.75 } + gap + voice + pause
        }
        output = Array(output.prefix(total))
        fadeOut(&output, seconds: 0.4, sampleRate: sampleRate)
        return output
    }

    /// Linear-interpolation resampling (speech only needs to stay intelligible).
    static func resample(_ samples: [Float], from source: Double, to target: Double) -> [Float] {
        guard source != target, !samples.isEmpty else { return samples }
        let ratio = source / target
        let count = Int(Double(samples.count) / ratio)
        return (0..<count).map { index in
            let position = Double(index) * ratio
            let lower = Int(position)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(position - Double(lower))
            return samples[lower] * (1 - fraction) + samples[upper] * fraction
        }
    }

    /// Mono samples as a WAV file at the synthesiser's sample rate.
    public static func wav(samples: [Float]) -> Data {
        WAVEncoder.encode(samples, sampleRate: Int(sampleRate))
    }

    /// The rendered sound as a WAV file.
    public static func wav(_ sound: AlarmSound) -> Data? {
        render(sound).map { WAVEncoder.encode($0, sampleRate: Int(sampleRate)) }
    }

    struct Motif {
        var notes: [Note]
        /// Seconds from one repetition to the next.
        var period: Double
    }

    // MARK: Sound design

    struct Partial {
        /// Frequency as a multiple of the note's base frequency.
        var ratio: Double
        var amplitude: Double
        /// Time for the partial to decay to 1/e, in seconds.
        var decay: Double
        /// Small frequency offset in Hz, used for slow "beating" shimmer.
        var detune: Double = 0
    }

    struct Note {
        var start: Double
        var frequency: Double
        var gain: Double
        var attack: Double
        var partials: [Partial]
        /// Loudness of the initial strike noise (0 = none).
        var strike: Double = 0
    }

    static func motif(for sound: AlarmSound) -> Motif? {
        // Instrument models.
        let tube: [Partial] = [
            Partial(ratio: 1, amplitude: 1, decay: 2.2),
            Partial(ratio: 1, amplitude: 0.25, decay: 2.0, detune: 1.1),
            Partial(ratio: 2.756, amplitude: 0.32, decay: 0.9),
            Partial(ratio: 5.404, amplitude: 0.10, decay: 0.35),
        ]
        let bell: [Partial] = [
            Partial(ratio: 0.5, amplitude: 0.35, decay: 3.6),
            Partial(ratio: 0.5, amplitude: 0.18, decay: 3.2, detune: 0.9),
            Partial(ratio: 1.0, amplitude: 0.60, decay: 2.3),
            Partial(ratio: 1.0, amplitude: 0.25, decay: 2.0, detune: 1.4),
            Partial(ratio: 1.2, amplitude: 0.45, decay: 1.8),
            Partial(ratio: 1.5, amplitude: 0.28, decay: 1.4),
            Partial(ratio: 2.0, amplitude: 0.55, decay: 1.25),
            Partial(ratio: 2.51, amplitude: 0.20, decay: 0.8),
            Partial(ratio: 3.01, amplitude: 0.14, decay: 0.55),
            Partial(ratio: 4.07, amplitude: 0.09, decay: 0.4),
        ]
        // A small brass desk bell: bright, inharmonic, quick ring.
        let serviceBell: [Partial] = [
            Partial(ratio: 1, amplitude: 1, decay: 1.4),
            Partial(ratio: 1, amplitude: 0.3, decay: 1.2, detune: 2.2),
            Partial(ratio: 2.32, amplitude: 0.55, decay: 0.8),
            Partial(ratio: 4.25, amplitude: 0.35, decay: 0.45),
            Partial(ratio: 6.63, amplitude: 0.18, decay: 0.25),
        ]
        let bowl: [Partial] = [
            Partial(ratio: 1, amplitude: 1, decay: 5.0),
            Partial(ratio: 1, amplitude: 0.6, decay: 4.6, detune: 1.6),
            Partial(ratio: 2.81, amplitude: 0.5, decay: 3.4),
            Partial(ratio: 2.81, amplitude: 0.3, decay: 3.0, detune: 2.3),
            Partial(ratio: 5.18, amplitude: 0.22, decay: 2.0),
        ]
        let bar: [Partial] = [
            Partial(ratio: 1, amplitude: 1, decay: 0.45),
            Partial(ratio: 3.93, amplitude: 0.25, decay: 0.12),
            Partial(ratio: 9.2, amplitude: 0.07, decay: 0.05),
        ]
        let tine: [Partial] = [
            Partial(ratio: 1, amplitude: 1, decay: 1.1),
            Partial(ratio: 6.27, amplitude: 0.16, decay: 0.25),
            Partial(ratio: 17.55, amplitude: 0.04, decay: 0.08),
        ]
        // A square-ish beep (odd harmonics) that stops sharply.
        let beep: [Partial] = [
            Partial(ratio: 1, amplitude: 1, decay: 0.09),
            Partial(ratio: 3, amplitude: 0.33, decay: 0.09),
            Partial(ratio: 5, amplitude: 0.2, decay: 0.09),
        ]
        func notes(_ list: [(Double, Double)], partials: [Partial], gain: Double = 0.85, attack: Double = 0.003, strike: Double = 0) -> [Note] {
            list.map { Note(start: $0.0, frequency: $0.1, gain: gain, attack: attack, partials: partials, strike: strike) }
        }

        switch sound {
        case .iPhoneDefault:
            return nil
        case .conciergeBell:
            // Ding … ding-ding, then a pause.
            return Motif(notes: notes([(0, 2093.0), (0.9, 2093.0), (1.15, 2093.0)], partials: serviceBell, gain: 0.9, attack: 0.001, strike: 0.12), period: 3.2)
        case .grandfatherClock:
            // Westminster quarters (E4 G#4 F#4 B3 | E4 F#4 G#4 E4) on a deep bell.
            let e4 = 329.63, gs4 = 415.30, fs4 = 369.99, b3 = 246.94
            let melody = [e4, gs4, fs4, b3, e4, fs4, gs4, e4]
            let times = [0.0, 0.7, 1.4, 2.1, 3.3, 4.0, 4.7, 5.4]
            return Motif(notes: notes(Array(zip(times, melody)), partials: bell, gain: 0.8, attack: 0.002, strike: 0.15), period: 8.0)
        case .chime, .gentleRise:
            return Motif(notes: notes([(0, 1046.50), (0.20, 1318.51), (0.42, 1567.98), (0.95, 2093.0)], partials: tube), period: 2.6)
        case .acousticBell:
            return Motif(notes: notes([(0, 329.63)], partials: bell, gain: 1, attack: 0.002, strike: 0.18), period: 3.5)
        case .singingBowl:
            return Motif(notes: notes([(0, 196.0)], partials: bowl, gain: 1, attack: 0.06, strike: 0.04), period: 6.0)
        case .marimba:
            return Motif(notes: notes([(0, 392.0), (0.14, 493.88), (0.28, 587.33), (0.44, 783.99)], partials: bar, gain: 0.9, attack: 0.002, strike: 0.05), period: 1.6)
        case .musicBox:
            return Motif(notes: notes([(0, 1318.51), (0.24, 1046.50), (0.48, 1567.98), (0.72, 1318.51), (1.05, 2093.0)], partials: tine, attack: 0.001), period: 2.4)
        case .digital:
            // Four quick beeps, then a pause, like a bedside alarm clock.
            return Motif(notes: notes([(0, 2000.0), (0.13, 2000.0), (0.26, 2000.0), (0.39, 2000.0)], partials: beep, gain: 0.7, attack: 0.002), period: 1.0)
        }
    }

    // MARK: Rendering

    static func add(_ note: Note, to buffer: inout [Float], sampleRate: Double) {
        let startIndex = Int(note.start * sampleRate)
        guard startIndex < buffer.count else { return }
        let attackSamples = max(1, Int(note.attack * sampleRate))
        var random = ToneRandom(seed: UInt64(note.frequency * 1000))
        var noiseState = 0.0

        // A note is silent after about five times its longest decay: stop there (long sounds
        // repeat their motif many times, so this keeps rendering fast).
        let longest = note.partials.map(\.decay).max() ?? 1
        let endIndex = min(buffer.count, startIndex + Int((longest * 5 + 0.05) * sampleRate))
        for i in startIndex..<endIndex {
            let t = Double(i - startIndex) / sampleRate
            var value = 0.0
            for partial in note.partials {
                let frequency = note.frequency * partial.ratio + partial.detune
                // Skip partials above Nyquist (they would alias).
                guard frequency < sampleRate / 2 else { continue }
                value += partial.amplitude * exp(-t / partial.decay) * sin(2 * .pi * frequency * t)
            }
            // Short, low-passed noise burst for the "strike" of a mallet or clapper.
            if note.strike > 0, t < 0.03 {
                noiseState += 0.35 * (random.nextSigned() - noiseState)
                value += note.strike * noiseState * exp(-t / 0.006) * 4
            }
            let ramp = i - startIndex < attackSamples ? Double(i - startIndex) / Double(attackSamples) : 1
            buffer[i] += Float(value * note.gain * ramp)
        }
    }

    static func normalise(_ buffer: inout [Float], peak: Float) {
        let maxValue = buffer.reduce(Float(0)) { max($0, abs($1)) }
        guard maxValue > 0 else { return }
        let scale = peak / maxValue
        for i in buffer.indices { buffer[i] *= scale }
    }

    static func fadeOut(_ buffer: inout [Float], seconds: Double, sampleRate: Double) {
        let count = min(buffer.count, Int(seconds * sampleRate))
        guard count > 0 else { return }
        let start = buffer.count - count
        for i in 0..<count {
            buffer[start + i] *= Float(1 - Double(i + 1) / Double(count))
        }
    }
}

/// Small deterministic random generator (xorshift64*), so synthesis is reproducible.
struct ToneRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }

    /// Uniform value in -1…1.
    mutating func nextSigned() -> Double {
        Double(next() >> 11) / Double(1 << 53) * 2 - 1
    }
}


/// Writes mono 16-bit PCM WAV data. Used to store the rendered alarm sounds in `Library/Sounds/`,
/// where iOS (AlarmKit) plays them even when Concierge Clock is closed. Same encoder as FocusFound.
public enum WAVEncoder {
    public static func encode(_ samples: [Float], sampleRate: Int) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample
        var data = Data(capacity: 44 + dataSize)

        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))                                   // fmt chunk size
        append(UInt16(1))                                    // PCM
        append(UInt16(1))                                    // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * bytesPerSample))          // byte rate
        append(UInt16(bytesPerSample))                       // block align
        append(UInt16(16))                                   // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize))
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append(Int16((clamped * Float(Int16.max)).rounded()))
        }
        return data
    }
}

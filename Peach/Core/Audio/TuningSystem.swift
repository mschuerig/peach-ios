import Foundation

/// Defines how intervals map to cent offsets from 12-TET.
///
/// An enum (not a protocol) so it can drive a future Settings picker via
/// `CaseIterable`. Currently only `.equalTemperament`; adding a case
/// (e.g. `.justIntonation`) supplies non-zero cent deviations.
enum TuningSystem: Hashable, Sendable, CaseIterable, Codable {
    case equalTemperament

    func centOffset(for interval: Interval) -> Double {
        switch self {
        case .equalTemperament:
            return Double(interval.semitones) * 100.0
        }
    }

    // MARK: - Frequency Bridge (Logical → Physical)

    private static let referenceMIDINote = 69
    private static let semitonesPerOctave = 12.0
    private static let centsPerSemitone = 100.0
    private static let octaveRatio = 2.0

    func frequency(for note: DetunedMIDINote, referencePitch: Frequency) -> Frequency {
        let semitones = Double(note.note.rawValue - Self.referenceMIDINote)
            + note.offset.rawValue / Self.centsPerSemitone
        return Frequency(referencePitch.rawValue * pow(Self.octaveRatio, semitones / Self.semitonesPerOctave))
    }

    func frequency(for note: MIDINote, referencePitch: Frequency) -> Frequency {
        frequency(for: DetunedMIDINote(note), referencePitch: referencePitch)
    }
}

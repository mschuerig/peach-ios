import Foundation

/// Defines how intervals map to cent offsets from 12-TET.
///
/// An enum (not a protocol) so it can drive the Settings picker via
/// `CaseIterable`. Adding a new case supplies non-zero cent deviations
/// and a `displayName` — no changes to interval or training logic required.
enum TuningSystem: Hashable, Sendable, CaseIterable, Codable {
    case equalTemperament
    case justIntonation

    func centOffset(for interval: Interval) -> Double {
        switch self {
        case .equalTemperament:
            return Double(interval.semitones) * 100.0
        case .justIntonation:
            switch interval {
            case .prime:        return 0.0
            case .minorSecond:  return 111.731
            case .majorSecond:  return 203.910
            case .minorThird:   return 315.641
            case .majorThird:   return 386.314
            case .perfectFourth: return 498.045
            case .tritone:      return 590.224
            case .perfectFifth: return 701.955
            case .minorSixth:   return 813.686
            case .majorSixth:   return 884.359
            case .minorSeventh: return 1017.596
            case .majorSeventh: return 1088.269
            case .octave:       return 1200.0
            }
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

    // MARK: - Display

    var displayName: String {
        switch self {
        case .equalTemperament: String(localized: "Equal Temperament")
        case .justIntonation: String(localized: "Just Intonation")
        }
    }

    // MARK: - Storage Identifiers

    var storageIdentifier: String {
        switch self {
        case .equalTemperament: return "equalTemperament"
        case .justIntonation: return "justIntonation"
        }
    }

    static func fromStorageIdentifier(_ id: String) -> TuningSystem? {
        switch id {
        case "equalTemperament": return .equalTemperament
        case "justIntonation": return .justIntonation
        default: return nil
        }
    }
}

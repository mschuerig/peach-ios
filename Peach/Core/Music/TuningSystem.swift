import Foundation

/// Defines how intervals map to cent offsets from 12-TET.
///
/// An enum (not a protocol) so it can drive the Settings picker via
/// `CaseIterable`. Adding a new case supplies non-zero cent deviations
/// and a `displayName` — no changes to interval or training logic required.
enum TuningSystem: Hashable, Sendable, CaseIterable, Codable {
    case equalTemperament
    case justIntonation

    func centOffset(for interval: Interval) -> Cents {
        switch self {
        case .equalTemperament:
            return Cents(Double(interval.semitones) * 100.0)
        case .justIntonation:
            switch interval {
            case .prime:        return Cents(0.0)
            case .minorSecond:  return Cents(111.731)
            case .majorSecond:  return Cents(203.910)
            case .minorThird:   return Cents(315.641)
            case .majorThird:   return Cents(386.314)
            case .perfectFourth: return Cents(498.045)
            case .tritone:      return Cents(590.224)
            case .perfectFifth: return Cents(701.955)
            case .minorSixth:   return Cents(813.686)
            case .majorSixth:   return Cents(884.359)
            case .minorSeventh: return Cents(1017.596)
            case .majorSeventh: return Cents(1088.269)
            case .octave:       return Cents(Cents.perOctave)
            }
        }
    }

    // MARK: - Frequency Bridge (Logical → Physical)

    private static let referenceMIDINote = 69

    /// Decomposes MIDI distance into octaves + remainder interval, then computes
    /// the total cent offset using tuning-system-specific interval sizes.
    /// Remainder is always 0–11 via Euclidean mod, so Interval(rawValue:)! is safe.
    private func totalCentOffset(for note: DetunedMIDINote) -> Cents {
        let distance = note.note.rawValue - Self.referenceMIDINote
        let remainder = ((distance % 12) + 12) % 12
        let octaves = (distance - remainder) / 12
        guard let interval = Interval(rawValue: remainder) else {
            preconditionFailure("Euclidean mod produced out-of-range remainder \(remainder)")
        }
        return Cents(Double(octaves) * Cents.perOctave + centOffset(for: interval).rawValue + note.offset.rawValue)
    }

    func frequency(for note: DetunedMIDINote, referencePitch: Frequency) -> Frequency {
        let cents = totalCentOffset(for: note)
        return Frequency(referencePitch.rawValue * pow(2.0, cents.rawValue / Cents.perOctave))
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

    // MARK: - String Identifier

    var identifier: String {
        switch self {
        case .equalTemperament: return "equalTemperament"
        case .justIntonation: return "justIntonation"
        }
    }

    nonisolated init?(identifier: String) {
        switch identifier {
        case "equalTemperament": self = .equalTemperament
        case "justIntonation": self = .justIntonation
        default: return nil
        }
    }
}

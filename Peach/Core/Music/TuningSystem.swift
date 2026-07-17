import Foundation

/// Defines how intervals map to cent offsets from 12-TET.
///
/// An enum (not a protocol) so it can drive the Settings picker via
/// `CaseIterable`. Adding a new case supplies non-zero cent deviations
/// and a `displayName` — no changes to interval or training logic required.
nonisolated enum TuningSystem: Hashable, Sendable, CaseIterable, Codable {
    case equalTemperament
    case justIntonation

    func centOffset(for interval: Interval) -> Cents {
        switch self {
        case .equalTemperament:
            return Double(interval.semitones) * Cents.perSemitone
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
            case .octave:       return Cents.perOctave
            }
        }
    }

    // MARK: - Frequency Bridge (Logical → Physical, Absolute)

    /// Decomposes MIDI distance into octaves + remainder interval, then computes
    /// the total cent offset using tuning-system-specific interval sizes.
    /// Remainder is always 0–11 via Euclidean mod, so Interval(rawValue:)! is safe.
    private func totalCentOffset(for note: DetunedMIDINote) -> Cents {
        let distance = note.note - MIDINote.a4
        let remainder = ((distance % 12) + 12) % 12
        let octaves = (distance - remainder) / 12
        guard let interval = Interval(rawValue: remainder) else {
            preconditionFailure("Euclidean mod produced out-of-range remainder \(remainder)")
        }
        return Double(octaves) * Cents.perOctave + centOffset(for: interval) + note.offset
    }

    /// Absolute A-rooted bridge: the note's pitch measured from A4 against this
    /// tuning system's interval table. Must NOT be used for interval-trial
    /// playback — under `.justIntonation` the result depends on the note's
    /// position relative to A (the root lottery Story 87.1 removed); interval
    /// trials derive the target from the reference tone via
    /// `frequency(for:detunedBy:from:)` instead. Retained as the single-note
    /// logical → physical conversion (e.g. Settings previews) and for a future
    /// drone/tonal-context discipline where a fixed scale root is the point.
    func frequency(for note: DetunedMIDINote, referencePitch: Frequency) -> Frequency {
        let cents = totalCentOffset(for: note)
        return referencePitch * pow(2.0, cents / Cents.perOctave)
    }

    func frequency(for note: MIDINote, referencePitch: Frequency) -> Frequency {
        frequency(for: DetunedMIDINote(note), referencePitch: referencePitch)
    }

    // MARK: - Frequency Bridge (Reference-Relative)

    /// Signed size of a directed interval in this tuning system:
    /// the pure-ratio size under `.justIntonation`, `semitones × 100` under
    /// `.equalTemperament`; negative when descending.
    func intervalCents(for interval: DirectedInterval) -> Cents {
        let magnitude = centOffset(for: interval.interval)
        return interval.direction == .up ? magnitude : -magnitude
    }

    /// Reference-relative bridge for interval-trial playback: derives the
    /// target frequency from the reference tone the listener just heard, so
    /// the in-tune point depends only on the directed interval — never on the
    /// reference note's position relative to A. Detune is applied on top of
    /// the in-tune point.
    func frequency(for interval: DirectedInterval, detunedBy offset: Cents, from reference: Frequency) -> Frequency {
        let cents = intervalCents(for: interval) + offset
        return reference * pow(2.0, cents / Cents.perOctave)
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

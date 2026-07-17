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
    /// trials derive the target via the root-relative bridge
    /// `frequency(for:from:referencePitch:)` instead. Retained as the single-note
    /// logical → physical conversion (e.g. Settings previews) and for a future
    /// drone/tonal-context discipline where a fixed scale root is the point.
    func frequency(for note: DetunedMIDINote, referencePitch: Frequency) -> Frequency {
        let cents = totalCentOffset(for: note)
        return referencePitch * pow(2.0, cents / Cents.perOctave)
    }

    func frequency(for note: MIDINote, referencePitch: Frequency) -> Frequency {
        frequency(for: DetunedMIDINote(note), referencePitch: referencePitch)
    }

    // MARK: - Frequency Bridge (Root-Relative)

    /// Signed size of a directed interval in this tuning system:
    /// the pure-ratio size under `.justIntonation`, `semitones × 100` under
    /// `.equalTemperament`; negative when descending.
    func intervalCents(for interval: DirectedInterval) -> Cents {
        let magnitude = centOffset(for: interval.interval)
        return interval.direction == .up ? magnitude : -magnitude
    }

    /// Root-relative bridge for interval-trial playback. Explicit rules:
    /// (1) the tuning system's interval sizes derive from an implicit scale
    /// built on `root` — under `.justIntonation` the 5-limit just scale
    /// (whose per-interval ratio choices the table encodes); under
    /// `.equalTemperament` the root choice is immaterial (root-invariant);
    /// (2) the interval is reckoned from `root`, ascending or descending per
    /// its direction; (3) `root`'s own pitch is its equal-tempered pitch in
    /// every tuning system (absolute placement of a contextless tone is
    /// imperceptible, and an A-rooted alternative would reintroduce the root
    /// lottery Story 87.1 removed); (4) the cent offset detunes the far tone
    /// in pitch space on top of the pure in-tune point.
    ///
    /// Interval trials pass the trial's reference note as `root` — the scale
    /// is re-rooted at every trial, and `root` MUST be the note the trial's
    /// other frequency math anchors on. Either note of a dyad as root yields
    /// the same *sounding interval* (cent relationship between the tones),
    /// but NOT the same target frequency: rule (3) pins the root to equal
    /// temperament, so the pair's absolute placement shifts by the
    /// interval's tuning deviation (e.g. ~13.7¢ for a JI major third).
    /// Anchoring the rest of the trial on one note while rooting this bridge
    /// on the other silently collapses the tuning system toward ET. A future
    /// discipline with a root that persists across notes (drone / tonal
    /// context) needs a root distinct from the sounding notes and must use
    /// the absolute A-rooted bridge instead.
    func frequency(for interval: DetunedDirectedInterval, from root: MIDINote, referencePitch: Frequency) -> Frequency {
        let rootFrequency = TuningSystem.equalTemperament.frequency(for: root, referencePitch: referencePitch)
        let cents = intervalCents(for: interval.interval) + interval.offset
        return rootFrequency * pow(2.0, cents / Cents.perOctave)
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

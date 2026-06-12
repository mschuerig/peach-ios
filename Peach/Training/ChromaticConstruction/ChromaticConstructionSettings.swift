import Foundation

/// Configuration for a chromatic-construction training run.
///
/// The set of `outerIntervals` lets the user enable one or both directions
/// (e.g. `{.up(.perfectFifth)}`, `{.down(.perfectFifth)}`, or both). The
/// session draws one element per trial via `randomElement()`, mirroring
/// `PitchDiscriminationSettings.intervals`.
///
/// `referencePitch` is the A reference (e.g. 440 Hz, 432 Hz) — the only
/// non-derivable musical input that varies across users. The tuning system
/// is *not* a field: the discipline is implicitly equal-tempered, and the
/// session calls `TuningSystem.equalTemperament.frequency(...)` directly at
/// the MIDI→Frequency bridge.
struct ChromaticConstructionSettings: Sendable {
    let lowerAnchor: MIDINote
    let outerIntervals: Set<DirectedInterval>
    let referencePitch: Frequency

    init(
        lowerAnchor: MIDINote,
        outerIntervals: Set<DirectedInterval>,
        referencePitch: Frequency
    ) {
        precondition(!outerIntervals.isEmpty, "outerIntervals must not be empty")
        self.lowerAnchor = lowerAnchor
        self.outerIntervals = outerIntervals
        self.referencePitch = referencePitch
    }

    /// Builds settings from a `UserSettings` snapshot. Only `referencePitch`
    /// is pulled from user settings; the rest is supplied by the screen.
    static func from(
        _ userSettings: any UserSettings,
        lowerAnchor: MIDINote,
        outerIntervals: Set<DirectedInterval>
    ) -> ChromaticConstructionSettings {
        ChromaticConstructionSettings(
            lowerAnchor: lowerAnchor,
            outerIntervals: outerIntervals,
            referencePitch: userSettings.referencePitch
        )
    }
}

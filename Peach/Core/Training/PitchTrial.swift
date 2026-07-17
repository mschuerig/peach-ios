/// The logical core shared by both pitch disciplines' trials: a reference
/// note and the directed interval reckoned from it. Frequency derivation
/// lives here so the reference-sounds-equal-tempered rule (Story 87.1) has a
/// single home — a divergence between the disciplines would be an audible
/// cross-discipline inconsistency no per-discipline test could catch.
protocol PitchTrial {
    var referenceNote: MIDINote { get }
    var interval: DirectedInterval { get }
}

extension PitchTrial {
    /// The reference tone sounds at its equal-tempered pitch in every tuning
    /// system — only the interval to the target is judged (Story 87.1).
    func referenceFrequency(referencePitch: Frequency) -> Frequency {
        TuningSystem.equalTemperament.frequency(for: referenceNote, referencePitch: referencePitch)
    }

    /// The trial's in-tune point: the directed interval's size in the given
    /// tuning system, reckoned from the reference note.
    func inTuneTargetFrequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(
            for: DetunedDirectedInterval(interval),
            from: referenceNote,
            referencePitch: referencePitch
        )
    }
}

struct PitchMatchingTrial {
    let referenceNote: MIDINote
    let targetNote: MIDINote
    let initialCentOffset: Cents
    let interval: DirectedInterval

    init(referenceNote: MIDINote, targetNote: MIDINote, initialCentOffset: Cents, interval: DirectedInterval) {
        precondition(
            referenceNote.transposed(by: interval) == targetNote,
            "targetNote \(targetNote.rawValue) is not referenceNote \(referenceNote.rawValue) transposed by \(interval)"
        )
        self.referenceNote = referenceNote
        self.targetNote = targetNote
        self.initialCentOffset = initialCentOffset
        self.interval = interval
    }

    /// The reference tone sounds at its equal-tempered pitch in every tuning
    /// system — only the interval to the target is judged (Story 87.1).
    func referenceFrequency(referencePitch: Frequency) -> Frequency {
        TuningSystem.equalTemperament.frequency(for: referenceNote, referencePitch: referencePitch)
    }

    /// The slider's zero-error point: the directed interval's size in the
    /// given tuning system, reckoned from the reference note.
    func inTuneTargetFrequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(
            for: DetunedDirectedInterval(interval),
            from: referenceNote,
            referencePitch: referencePitch
        )
    }
}

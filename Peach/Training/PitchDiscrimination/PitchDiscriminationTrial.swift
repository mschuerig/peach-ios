import Foundation

struct PitchDiscriminationTrial {
    let referenceNote: MIDINote
    let targetNote: DetunedMIDINote
    let interval: DirectedInterval

    init(referenceNote: MIDINote, targetNote: DetunedMIDINote, interval: DirectedInterval) {
        precondition(
            referenceNote.transposed(by: interval) == targetNote.note,
            "targetNote \(targetNote.note.rawValue) is not referenceNote \(referenceNote.rawValue) transposed by \(interval)"
        )
        self.referenceNote = referenceNote
        self.targetNote = targetNote
        self.interval = interval
    }

    var isTargetHigher: Bool {
        targetNote.offset > 0
    }

    /// The reference tone sounds at its equal-tempered pitch in every tuning
    /// system — only the interval to the target is judged (Story 87.1).
    func referenceFrequency(referencePitch: Frequency) -> Frequency {
        TuningSystem.equalTemperament.frequency(for: referenceNote, referencePitch: referencePitch)
    }

    /// In-tune point = reference frequency × the directed interval's size in
    /// the given tuning system; the target's cent offset detunes on top.
    func targetFrequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(
            for: interval,
            detunedBy: targetNote.offset,
            from: referenceFrequency(referencePitch: referencePitch)
        )
    }

    func isCorrect(userAnswerHigher: Bool) -> Bool {
        return userAnswerHigher == isTargetHigher
    }
}

struct CompletedPitchDiscriminationTrial {
    let trial: PitchDiscriminationTrial
    let userAnsweredHigher: Bool
    let tuningSystem: TuningSystem

    var isCorrect: Bool {
        trial.isCorrect(userAnswerHigher: userAnsweredHigher)
    }

    let timestamp: Date

    init(trial: PitchDiscriminationTrial, userAnsweredHigher: Bool, tuningSystem: TuningSystem, timestamp: Date = Date()) {
        self.trial = trial
        self.userAnsweredHigher = userAnsweredHigher
        self.tuningSystem = tuningSystem
        self.timestamp = timestamp
    }
}

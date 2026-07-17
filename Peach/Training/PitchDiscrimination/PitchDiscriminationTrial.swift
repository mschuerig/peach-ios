import Foundation

struct PitchDiscriminationTrial: PitchTrial {
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

    /// In-tune point = the directed interval's size in the given tuning
    /// system, reckoned from the reference note; the target's cent offset
    /// detunes on top.
    func targetFrequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(
            for: DetunedDirectedInterval(interval: interval, offset: targetNote.offset),
            from: referenceNote,
            referencePitch: referencePitch
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

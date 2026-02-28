import Foundation

struct Comparison {
    let referenceNote: MIDINote
    let targetNote: DetunedMIDINote

    var isTargetHigher: Bool {
        targetNote.offset.rawValue > 0
    }

    func referenceFrequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(for: referenceNote, referencePitch: referencePitch)
    }

    func targetFrequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(for: targetNote, referencePitch: referencePitch)
    }

    func isCorrect(userAnswerHigher: Bool) -> Bool {
        return userAnswerHigher == isTargetHigher
    }
}

struct CompletedComparison {
    let comparison: Comparison
    let userAnsweredHigher: Bool

    var isCorrect: Bool {
        comparison.isCorrect(userAnswerHigher: userAnsweredHigher)
    }

    let timestamp: Date

    init(comparison: Comparison, userAnsweredHigher: Bool, timestamp: Date = Date()) {
        self.comparison = comparison
        self.userAnsweredHigher = userAnsweredHigher
        self.timestamp = timestamp
    }
}

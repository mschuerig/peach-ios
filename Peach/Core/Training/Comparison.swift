import Foundation

struct Comparison {
    let note1: MIDINote
    let note2: MIDINote
    let centDifference: Cents

    var isSecondNoteHigher: Bool {
        centDifference.rawValue > 0
    }

    func note1Frequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(for: note1, referencePitch: referencePitch)
    }

    func note2Frequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency {
        tuningSystem.frequency(for: DetunedMIDINote(note: note2, offset: centDifference), referencePitch: referencePitch)
    }

    func isCorrect(userAnswerHigher: Bool) -> Bool {
        return userAnswerHigher == isSecondNoteHigher
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

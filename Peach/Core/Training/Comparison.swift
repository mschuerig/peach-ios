import Foundation

struct Comparison {
    let note1: MIDINote
    let note2: MIDINote
    let centDifference: Cents

    var isSecondNoteHigher: Bool {
        centDifference.rawValue > 0
    }

    func note1Frequency(referencePitch: Double = 440.0) -> Frequency {
        Pitch(note: note1, cents: Cents(0)).frequency(referencePitch: Frequency(referencePitch))
    }

    func note2Frequency(referencePitch: Double = 440.0) -> Frequency {
        Pitch(note: note2, cents: centDifference).frequency(referencePitch: Frequency(referencePitch))
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

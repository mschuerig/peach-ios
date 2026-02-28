import Foundation
import Testing
@testable import Peach

@Suite("Comparison Tests")
struct ComparisonTests {

    @Test("note1Frequency calculates valid frequency for middle C")
    func note1FrequencyCalculatesCorrectly() async {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: Cents(100.0))

        let freq = comparison.note1Frequency()

        #expect(freq.rawValue >= 260 && freq.rawValue <= 263)
    }

    @Test("note2Frequency applies positive cent offset (higher)")
    func note2FrequencyAppliesCentOffsetHigher() async {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: Cents(100.0))

        let freq1 = comparison.note1Frequency()
        let freq2 = comparison.note2Frequency()

        #expect(freq2 > freq1)

        let ratio = freq2.rawValue / freq1.rawValue
        #expect(ratio >= 1.05 && ratio <= 1.07)
    }

    @Test("note2Frequency applies negative cent offset (lower)")
    func note2FrequencyAppliesCentOffsetLower() async {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: Cents(-100.0))

        let freq1 = comparison.note1Frequency()
        let freq2 = comparison.note2Frequency()

        #expect(freq2 < freq1)
    }

    @Test("isSecondNoteHigher reflects positive cent difference")
    func isSecondNoteHigherPositiveCents() {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: Cents(50.0))
        #expect(comparison.isSecondNoteHigher == true)
    }

    @Test("isSecondNoteHigher reflects negative cent difference")
    func isSecondNoteHigherNegativeCents() {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: Cents(-50.0))
        #expect(comparison.isSecondNoteHigher == false)
    }

    @Test("isCorrect validates user answer against cent direction")
    func isCorrectValidatesAnswer() {
        let higher = Comparison(note1: 60, note2: 60, centDifference: Cents(100.0))
        let lower = Comparison(note1: 60, note2: 60, centDifference: Cents(-100.0))

        #expect(higher.isCorrect(userAnswerHigher: true) == true)
        #expect(higher.isCorrect(userAnswerHigher: false) == false)
        #expect(lower.isCorrect(userAnswerHigher: false) == true)
        #expect(lower.isCorrect(userAnswerHigher: true) == false)
    }
}

@Suite("CompletedComparison Tests")
struct CompletedComparisonTests {

    @Test("isCorrect delegates to comparison logic")
    func isCorrectDelegatesToComparison() {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: Cents(100.0))

        let correct = CompletedComparison(comparison: comparison, userAnsweredHigher: true)
        let incorrect = CompletedComparison(comparison: comparison, userAnsweredHigher: false)

        #expect(correct.isCorrect == true)
        #expect(incorrect.isCorrect == false)
    }

    @Test("timestamp defaults to now")
    func timestampDefaultsToNow() {
        let before = Date()
        let completed = CompletedComparison(
            comparison: Comparison(note1: 60, note2: 60, centDifference: Cents(50.0)),
            userAnsweredHigher: true
        )
        let after = Date()

        #expect(completed.timestamp >= before)
        #expect(completed.timestamp <= after)
    }
}

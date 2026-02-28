import Foundation
import Testing
@testable import Peach

@Suite("Comparison Tests")
struct ComparisonTests {

    @Test("referenceFrequency calculates valid frequency for middle C")
    func referenceFrequencyCalculatesCorrectly() async {
        let comparison = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))

        let freq = comparison.referenceFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)

        #expect(freq.rawValue >= 260 && freq.rawValue <= 263)
    }

    @Test("targetFrequency applies positive cent offset (higher)")
    func targetFrequencyAppliesCentOffsetHigher() async {
        let comparison = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))

        let freq1 = comparison.referenceFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)
        let freq2 = comparison.targetFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)

        #expect(freq2 > freq1)

        let ratio = freq2.rawValue / freq1.rawValue
        #expect(ratio >= 1.05 && ratio <= 1.07)
    }

    @Test("targetFrequency applies negative cent offset (lower)")
    func targetFrequencyAppliesCentOffsetLower() async {
        let comparison = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(-100.0)))

        let freq1 = comparison.referenceFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)
        let freq2 = comparison.targetFrequency(tuningSystem: .equalTemperament, referencePitch: .concert440)

        #expect(freq2 < freq1)
    }

    @Test("isTargetHigher reflects positive cent difference")
    func isTargetHigherPositiveCents() {
        let comparison = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(50.0)))
        #expect(comparison.isTargetHigher == true)
    }

    @Test("isTargetHigher reflects negative cent difference")
    func isTargetHigherNegativeCents() {
        let comparison = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(-50.0)))
        #expect(comparison.isTargetHigher == false)
    }

    @Test("isCorrect validates user answer against cent direction")
    func isCorrectValidatesAnswer() {
        let higher = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))
        let lower = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(-100.0)))

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
        let comparison = Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))

        let correct = CompletedComparison(comparison: comparison, userAnsweredHigher: true)
        let incorrect = CompletedComparison(comparison: comparison, userAnsweredHigher: false)

        #expect(correct.isCorrect == true)
        #expect(incorrect.isCorrect == false)
    }

    @Test("timestamp defaults to now")
    func timestampDefaultsToNow() {
        let before = Date()
        let completed = CompletedComparison(
            comparison: Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(50.0))),
            userAnsweredHigher: true
        )
        let after = Date()

        #expect(completed.timestamp >= before)
        #expect(completed.timestamp <= after)
    }
}

import Testing
import Foundation
@testable import Peach

/// Tests for KazezNoteStrategy — Kazez et al. (2001) default training strategy
@Suite("KazezNoteStrategy Tests")
struct KazezNoteStrategyTests {

    // MARK: - Protocol Compliance

    @Test("Conforms to NextComparisonStrategy and returns valid Comparison")
    func protocolCompliance() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440)
        let comparison = strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.referenceNote >= settings.noteRangeMin && comparison.referenceNote <= settings.noteRangeMax)
        #expect(comparison.targetNote.note == comparison.referenceNote)
        #expect(comparison.targetNote.offset.magnitude > 0)
    }

    // MARK: - First Comparison

    @Test("First comparison uses maxCentDifference")
    func firstComparisonUsesMax() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, maxCentDifference: 100.0)

        let comparison = strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    @Test("First comparison respects custom maxCentDifference")
    func firstComparisonCustomMax() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, maxCentDifference: 50.0)

        let comparison = strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.targetNote.offset.magnitude == 50.0)
    }

    // MARK: - Kazez Correct Formula: N = P × [1 - (0.05 × √P)]

    @Test("Correct at P=100: N = 100 × [1 - 0.05×10] = 50")
    func correctAt100() {
        let result = nextAfterCorrect(p: 100.0)
        #expect(abs(result - 50.0) < 0.001)
    }

    @Test("Correct at P=50: N = 50 × [1 - 0.05×√50] ≈ 32.32")
    func correctAt50() {
        let expected = 50.0 * (1.0 - 0.05 * 50.0.squareRoot())
        let result = nextAfterCorrect(p: 50.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Correct at P=10: N = 10 × [1 - 0.05×√10] ≈ 8.42")
    func correctAt10() {
        let expected = 10.0 * (1.0 - 0.05 * 10.0.squareRoot())
        let result = nextAfterCorrect(p: 10.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Correct at P=5: N = 5 × [1 - 0.05×√5] ≈ 4.44")
    func correctAt5() {
        let expected = 5.0 * (1.0 - 0.05 * 5.0.squareRoot())
        let result = nextAfterCorrect(p: 5.0)
        #expect(abs(result - expected) < 0.001)
    }

    // MARK: - Kazez Incorrect Formula: N = P × [1 + (0.09 × √P)]

    @Test("Incorrect at P=5: N = 5 × [1 + 0.09×√5] ≈ 6.01")
    func incorrectAt5() {
        let expected = 5.0 * (1.0 + 0.09 * 5.0.squareRoot())
        let result = nextAfterIncorrect(p: 5.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Incorrect at P=10: N = 10 × [1 + 0.09×√10] ≈ 12.85")
    func incorrectAt10() {
        let expected = 10.0 * (1.0 + 0.09 * 10.0.squareRoot())
        let result = nextAfterIncorrect(p: 10.0)
        #expect(abs(result - expected) < 0.001)
    }

    @Test("Incorrect at P=50: N = 50 × [1 + 0.09×√50] ≈ 81.82")
    func incorrectAt50() {
        let expected = 50.0 * (1.0 + 0.09 * 50.0.squareRoot())
        let result = nextAfterIncorrect(p: 50.0)
        #expect(abs(result - expected) < 0.001)
    }

    // MARK: - Clamping

    @Test("Floor clamping: result never below minCentDifference")
    func floorClamping() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, minCentDifference: 5.0)
        // P=1: N = 1 × [1 - 0.05×1] = 0.95 → clamped to 5.0
        let last = makeCompleted(centDifference: 1.0, correct: true)

        let comparison = strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: last
        )

        #expect(comparison.targetNote.offset.magnitude == 5.0)
    }

    @Test("Ceiling clamping: result never above maxCentDifference")
    func ceilingClamping() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, maxCentDifference: 100.0)
        // P=50 incorrect: N = 50 × [1 + 0.09×7.07] ≈ 81.8 → under ceiling
        // P=100 incorrect: N = 100 × [1 + 0.09×10] = 190 → clamped to 100
        let last = makeCompleted(centDifference: 100.0, correct: false)

        let comparison = strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: last
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    // MARK: - Note Range

    @Test("Notes always within settings noteRangeMin...noteRangeMax")
    func noteRange() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 48, noteRangeMax: 72, referencePitch: .concert440)

        for _ in 0..<100 {
            let comparison = strategy.nextComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastComparison: nil
            )
            #expect(comparison.referenceNote >= 48 && comparison.referenceNote <= 72)
        }
    }

    @Test("Notes respect custom note range from settings")
    func customNoteRange() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 72, referencePitch: .concert440)

        for _ in 0..<100 {
            let comparison = strategy.nextComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastComparison: nil
            )
            #expect(comparison.referenceNote >= 60 && comparison.referenceNote <= 72)
        }
    }

    // MARK: - Cold Start from Profile

    @Test("Cold start with empty profile uses maxCentDifference")
    func coldStartEmptyProfile() {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        let settings = TrainingSettings(referencePitch: .concert440, maxCentDifference: 100.0)

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    @Test("Cold start with trained profile uses overallMean")
    func coldStartWithProfile() throws {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        // Train some notes so overallMean returns a value
        profile.update(note: 60, centOffset: 10.0, isCorrect: true)
        profile.update(note: 60, centOffset: 8.0, isCorrect: true)
        profile.update(note: 72, centOffset: 12.0, isCorrect: false)

        let settings = TrainingSettings(referencePitch: .concert440, maxCentDifference: 100.0)

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        // overallMean should be used, not maxCentDifference
        let expectedMean = try #require(profile.overallMean)
        #expect(comparison.targetNote.offset.magnitude == expectedMean)
        #expect(comparison.targetNote.offset.magnitude != 100.0)
    }

    @Test("Cold start with profile clamps to minCentDifference")
    func coldStartProfileClampedToMin() {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        // Train a note with very small offset
        profile.update(note: 60, centOffset: 0.05, isCorrect: true)

        let settings = TrainingSettings(referencePitch: .concert440, minCentDifference: 1.0, maxCentDifference: 100.0)

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        // overallMean (0.05) should be clamped to minCentDifference (1.0)
        #expect(comparison.targetNote.offset.magnitude >= settings.minCentDifference.rawValue)
    }

    @Test("Cold start with profile clamps to maxCentDifference")
    func coldStartProfileClampedToMax() {
        let strategy = KazezNoteStrategy()
        let profile = PerceptualProfile()
        // Train with large offsets
        profile.update(note: 60, centOffset: 200.0, isCorrect: false)

        let settings = TrainingSettings(referencePitch: .concert440, maxCentDifference: 100.0)

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        // overallMean (200.0) should be clamped to maxCentDifference (100.0)
        #expect(comparison.targetNote.offset.magnitude <= settings.maxCentDifference.rawValue)
    }

    // MARK: - Convergence

    @Test("10 consecutive correct answers from 100 cents reaches ~5 cents")
    func convergenceTest() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, minCentDifference: 1.0, maxCentDifference: 100.0)

        // First comparison: 100 cents
        var comparison = strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: nil
        )
        #expect(comparison.targetNote.offset.magnitude == 100.0)

        // Simulate 10 consecutive correct answers
        for _ in 0..<10 {
            let completed = CompletedComparison(
                comparison: comparison,
                userAnsweredHigher: comparison.isTargetHigher // correct
            )
            comparison = strategy.nextComparison(
                profile: PerceptualProfile(),
                settings: settings,
                lastComparison: completed
            )
        }

        // After 10 correct answers, should be in the ~4-6 cent range
        #expect(comparison.targetNote.offset.magnitude < 7.0)
        #expect(comparison.targetNote.offset.magnitude > 2.0)
    }

    @Test("Recovery after incorrect answer at low difficulty")
    func recoveryTest() {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, minCentDifference: 1.0, maxCentDifference: 100.0)

        // Start at 5 cents, get it wrong
        let last = makeCompleted(centDifference: 5.0, correct: false)
        let comparison = strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: last
        )

        // N = 5 × [1 + 0.09×√5] ≈ 5 × 1.201 ≈ 6.0
        #expect(comparison.targetNote.offset.magnitude > 5.0)
        #expect(comparison.targetNote.offset.magnitude < 7.0)
    }

    // MARK: - Helpers

    private func nextAfterCorrect(p: Double) -> Double {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, minCentDifference: 0.1)
        let last = makeCompleted(centDifference: p, correct: true)
        return strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: last
        ).targetNote.offset.magnitude
    }

    private func nextAfterIncorrect(p: Double) -> Double {
        let strategy = KazezNoteStrategy()
        let settings = TrainingSettings(referencePitch: .concert440, maxCentDifference: 200.0)
        let last = makeCompleted(centDifference: p, correct: false)
        return strategy.nextComparison(
            profile: PerceptualProfile(),
            settings: settings,
            lastComparison: last
        ).targetNote.offset.magnitude
    }

    private func makeCompleted(centDifference: Double, correct: Bool) -> CompletedComparison {
        let comp = Comparison(
            referenceNote: 60,
            targetNote: DetunedMIDINote(note: 60, offset: Cents(centDifference))
        )
        return CompletedComparison(
            comparison: comp,
            userAnsweredHigher: correct // isTargetHigher is true (positive cents), so correct = higher
        )
    }
}

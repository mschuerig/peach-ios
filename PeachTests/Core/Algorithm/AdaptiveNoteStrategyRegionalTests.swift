import Testing
import Foundation
@testable import Peach

/// Tests for AdaptiveNoteStrategy regional difficulty adjustment and weighted difficulty
@Suite("AdaptiveNoteStrategy Regional Tests")
@MainActor
struct AdaptiveNoteStrategyRegionalTests {

    // MARK: - Regional Difficulty Adjustment Tests (AC#2, AC#3)

    @Test("Regional difficulty narrows on correct answer using Kazez formula")
    func regionalDifficultyNarrowsOnCorrect() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)

        let comp1 = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
        #expect(comp1.centDifference == 100.0)

        let completed1 = CompletedComparison(comparison: comp1, userAnsweredHigher: comp1.isSecondNoteHigher)
        let comp2 = strategy.nextComparison(profile: profile, settings: settings, lastComparison: completed1)

        #expect(abs(comp2.centDifference - 20.0) < 0.01)
    }

    @Test("Regional difficulty widens on incorrect answer using Kazez formula")
    func regionalDifficultyWidensOnIncorrect() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 50, isCorrect: true)
        profile.setDifficulty(note: 60, difficulty: 50.0)

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)

        let comp1 = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
        #expect(comp1.centDifference == 50.0)

        let completed1 = CompletedComparison(comparison: comp1, userAnsweredHigher: !comp1.isSecondNoteHigher)
        let comp2 = strategy.nextComparison(profile: profile, settings: settings, lastComparison: completed1)

        let expected = 50.0 * (1.0 + 0.09 * 50.0.squareRoot())
        #expect(abs(comp2.centDifference - expected) < 0.01)
    }

    @Test("Weak spots use unsigned mean ranking")
    func weakSpotsUseUnsignedMean() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 48, centOffset: 10.0, isCorrect: true)
        profile.update(note: 60, centOffset: 80.0, isCorrect: true)
        profile.update(note: 72, centOffset: 90.0, isCorrect: true)

        let weakSpots = profile.weakSpots(count: 128)

        guard let pos48 = weakSpots.firstIndex(of: 48),
              let pos60 = weakSpots.firstIndex(of: 60),
              let pos72 = weakSpots.firstIndex(of: 72) else {
            Issue.record("Expected trained notes to be in weak spots list")
            return
        }

        #expect(pos72 < pos60, "Note 72 (mean=90) should rank worse than note 60 (mean=80)")
        #expect(pos60 < pos48, "Note 60 (mean=80) should rank worse than note 48 (mean=10)")
    }

    @Test("Difficulty narrows even when jumping between notes")
    func difficultyNarrowsAcrossJumps() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        let fixedSettings36 = TrainingSettings(noteRangeMin: 36, noteRangeMax: 36)
        let comp1 = strategy.nextComparison(profile: profile, settings: fixedSettings36, lastComparison: nil)
        #expect(comp1.note1 == 36)
        #expect(comp1.centDifference == 100.0)

        let completed1 = CompletedComparison(comparison: comp1, userAnsweredHigher: comp1.isSecondNoteHigher)

        let fixedSettings84 = TrainingSettings(noteRangeMin: 84, noteRangeMax: 84)
        let comp2 = strategy.nextComparison(profile: profile, settings: fixedSettings84, lastComparison: completed1)

        #expect(comp2.note1 == 84)
        #expect(abs(comp2.centDifference - 20.0) < 0.01,
            "Difficulty should narrow via Kazez formula after correct answer, even across a region jump. Got: \(comp2.centDifference)")
    }

    @Test("Kazez convergence: 10 correct answers from 100 cents reaches ~5 cents")
    func kazezConvergenceFromDefault() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 60,
            noteRangeMax: 60,
            minCentDifference: 1.0,
            maxCentDifference: 100.0
        )

        var lastComp: CompletedComparison? = nil

        for _ in 0..<10 {
            let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: lastComp)
            lastComp = CompletedComparison(comparison: comp, userAnsweredHigher: comp.isSecondNoteHigher)
        }

        let finalComp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: lastComp)

        #expect(finalComp.centDifference < 10.0, "After 10 correct answers, difficulty should be below 10 cents. Got: \(finalComp.centDifference)")
        #expect(finalComp.centDifference >= 1.0, "Difficulty should not go below minimum. Got: \(finalComp.centDifference)")
    }

    @Test("Per-note tracking: different notes have independent difficulties in isolated ranges")
    func perNoteIndependentDifficulties() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        let settings60 = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)
        var lastComp: CompletedComparison? = nil
        for _ in 0..<5 {
            let comp = strategy.nextComparison(profile: profile, settings: settings60, lastComparison: lastComp)
            lastComp = CompletedComparison(comparison: comp, userAnsweredHigher: comp.isSecondNoteHigher)
        }

        let comp60 = strategy.nextComparison(profile: profile, settings: settings60, lastComparison: lastComp)

        let settings72 = TrainingSettings(noteRangeMin: 72, noteRangeMax: 72)
        let comp72 = strategy.nextComparison(profile: profile, settings: settings72, lastComparison: nil)

        #expect(comp60.centDifference < 100.0, "Note 60 should have narrowed difficulty")
        #expect(comp72.centDifference == 100.0, "Note 72 in isolated range should still be at default 100 cents")
    }

    // MARK: - Weighted Effective Difficulty Tests

    @Test("Weighted difficulty: no data anywhere returns default 100")
    func weightedDifficultyNoDataReturnsDefault() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)

        let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)

        #expect(comp.centDifference == 100.0, "No trained data -> default 100 cents")
    }

    @Test("Weighted difficulty: current note only returns own difficulty")
    func weightedDifficultyCurrentNoteOnlyReturnsOwnDifficulty() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        profile.update(note: 60, centOffset: 30.0, isCorrect: true)
        profile.setDifficulty(note: 60, difficulty: 30.0)

        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)
        let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)

        #expect(comp.centDifference == 30.0, "Single trained note should return its own difficulty")
    }

    @Test("Weighted difficulty: untrained note uses neighbor data")
    func weightedDifficultyNeighborsOnly() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        profile.update(note: 59, centOffset: 40.0, isCorrect: true)
        profile.setDifficulty(note: 59, difficulty: 40.0)

        let settings = TrainingSettings(noteRangeMin: 59, noteRangeMax: 61)

        var note60Difficulty: Double? = nil
        for _ in 0..<200 {
            let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
            if comp.note1 == 60 {
                note60Difficulty = comp.centDifference
                break
            }
        }

        if let diff = note60Difficulty {
            #expect(diff == 40.0,
                "Untrained note 60 should get neighbor 59's difficulty (40.0). Got: \(diff)")
        }
    }

    @Test("Weighted difficulty: trained note with neighbors, own difficulty dominates")
    func weightedDifficultyCurrentNoteDominates() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        profile.update(note: 60, centOffset: 30.0, isCorrect: true)
        profile.setDifficulty(note: 60, difficulty: 30.0)

        profile.update(note: 59, centOffset: 80.0, isCorrect: true)
        profile.setDifficulty(note: 59, difficulty: 80.0)
        profile.update(note: 61, centOffset: 80.0, isCorrect: true)
        profile.setDifficulty(note: 61, difficulty: 80.0)

        let settings = TrainingSettings(noteRangeMin: 59, noteRangeMax: 61)

        var note60Difficulty: Double? = nil
        for _ in 0..<200 {
            let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
            if comp.note1 == 60 {
                note60Difficulty = comp.centDifference
                break
            }
        }

        if let diff = note60Difficulty {
            #expect(abs(diff - 55.0) < 0.01,
                "Trained note's own difficulty should dominate. Expected 55.0, got \(diff)")
            #expect(diff < 80.0, "Weighted average should be pulled toward own difficulty (30), not neighbors (80)")
        }
    }

    @Test("Weighted difficulty: 5-nearest neighbor limit")
    func weightedDifficultyKernelNarrowing() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        for i in 52...59 {
            profile.update(note: i, centOffset: 50.0, isCorrect: true)
            profile.setDifficulty(note: i, difficulty: 50.0)
        }
        profile.setDifficulty(note: 52, difficulty: 10.0)

        for i in 0...51 {
            profile.update(note: i, centOffset: 1.0, isCorrect: true)
        }
        for i in 61...127 {
            profile.update(note: i, centOffset: 1.0, isCorrect: true)
        }

        let settings = TrainingSettings(noteRangeMin: 52, noteRangeMax: 60)

        var note60Difficulty: Double? = nil
        for _ in 0..<1000 {
            let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
            if comp.note1 == 60 {
                note60Difficulty = comp.centDifference
                break
            }
        }

        #expect(note60Difficulty != nil, "Note 60 should have been selected within 1000 iterations")
        if let diff = note60Difficulty {
            #expect(abs(diff - 50.0) < 0.01, "5-nearest neighbors all at 50.0 -> weighted avg should be 50.0. Got: \(diff)")
        }
    }

    @Test("Weighted difficulty: boundary note with asymmetric neighbors")
    func weightedDifficultyBoundaryNote() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        profile.update(note: 37, centOffset: 30.0, isCorrect: true)
        profile.setDifficulty(note: 37, difficulty: 30.0)
        profile.update(note: 38, centOffset: 50.0, isCorrect: true)
        profile.setDifficulty(note: 38, difficulty: 50.0)

        let settings = TrainingSettings(noteRangeMin: 36, noteRangeMax: 40)

        var note36Difficulty: Double? = nil
        for _ in 0..<200 {
            let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
            if comp.note1 == 36 {
                note36Difficulty = comp.centDifference
                break
            }
        }

        if let diff = note36Difficulty {
            let w37 = 1.0 / (1.0 + 1.0)
            let w38 = 1.0 / (1.0 + 2.0)
            let expected = (w37 * 30.0 + w38 * 50.0) / (w37 + w38)
            #expect(abs(diff - expected) < 0.01,
                "Boundary note should use asymmetric neighbors. Expected \(expected), got \(diff)")
        }
    }

    @Test("Regional difficulty respects min/max bounds")
    func regionalDifficultyRespectsBounds() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 2.0, isCorrect: true)
        profile.setDifficulty(note: 60, difficulty: 2.0)

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 60,
            noteRangeMax: 60,
            minCentDifference: 1.0,
            maxCentDifference: 100.0
        )

        var lastComparison: CompletedComparison? = nil

        for _ in 0..<15 {
            let comp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: lastComparison)
            lastComparison = CompletedComparison(comparison: comp, userAnsweredHigher: comp.isSecondNoteHigher)
        }

        let finalComp = strategy.nextComparison(profile: profile, settings: settings, lastComparison: lastComparison)
        #expect(finalComp.centDifference == 1.0, "After many correct answers, difficulty should hit minimum bound of 1.0")
    }
}

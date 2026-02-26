import Testing
import Foundation
@testable import Peach

/// Tests for AdaptiveNoteStrategy core selection, difficulty, and weak spot targeting
@Suite("AdaptiveNoteStrategy Tests")
struct AdaptiveNoteStrategyTests {

    // MARK: - Task 1 Tests: NextComparisonStrategy Protocol

    @Test("NextComparisonStrategy protocol returns Comparison")
    func protocolReturnsComparison() async throws {
        let profile = PerceptualProfile()
        let settings = TrainingSettings()
        let strategy = AdaptiveNoteStrategy()

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.note1 >= 0 && comparison.note1 <= 127)
        #expect(comparison.note2 >= 0 && comparison.note2 <= 127)
        #expect(comparison.centDifference.magnitude > 0)
    }

    // MARK: - Difficulty Determination Tests

    @Test("Untrained note with no nearby data uses 100 cent default")
    func untrainedNoteUsesDefault() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.note1 == 60)
        #expect(comparison.centDifference.magnitude == 100.0)
    }

    @Test("Difficulty respects floor from settings")
    func difficultyRespectsFloor() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 1.0, isCorrect: true)
        profile.setDifficulty(note: 60, difficulty: 0.5)

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 60,
            noteRangeMax: 60,
            minCentDifference: 1.0
        )

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.centDifference.magnitude == 1.0)
    }

    @Test("Difficulty respects ceiling from settings")
    func difficultyRespectsCeiling() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 1.0, isCorrect: true)
        profile.setDifficulty(note: 60, difficulty: 150.0)

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 60,
            noteRangeMax: 60,
            maxCentDifference: 100.0
        )

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.centDifference.magnitude == 100.0)
    }

    // MARK: - Weak Spot Targeting Tests

    @Test("Mechanical ratio 1.0 targets weak spots")
    func mechanicalRatioTargetsWeakSpots() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 48, centOffset: 10, isCorrect: true)
        profile.update(note: 60, centOffset: 80, isCorrect: true)
        profile.update(note: 62, centOffset: 85, isCorrect: true)
        profile.update(note: 64, centOffset: 90, isCorrect: true)

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 36,
            noteRangeMax: 84,
            naturalVsMechanical: 1.0
        )

        var selectedNotes = Set<Int>()
        for _ in 0..<1000 {
            let comparison = strategy.nextComparison(
                profile: profile,
                settings: settings,
                lastComparison: nil
            )
            selectedNotes.insert(comparison.note1.rawValue)
        }

        let weakSpotSelections = selectedNotes.intersection([60, 62, 64])
        #expect(weakSpotSelections.count >= 1)
    }

    @Test("Natural ratio 0.0 targets nearby notes when last comparison provided")
    func naturalRatioTargetsNearbyNotes() async throws {
        let profile = PerceptualProfile()

        for note in 0..<128 {
            profile.update(note: MIDINote(note), centOffset: 50, isCorrect: true)
        }

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 36,
            noteRangeMax: 84,
            naturalVsMechanical: 0.0
        )

        let lastComparison = CompletedComparison(
            comparison: Comparison(note1: 48, note2: 48, centDifference: Cents(50.0)),
            userAnsweredHigher: true
        )

        var selectedNotes = Set<Int>()
        for _ in 0..<1000 {
            let comparison = strategy.nextComparison(
                profile: profile,
                settings: settings,
                lastComparison: lastComparison
            )
            selectedNotes.insert(comparison.note1.rawValue)
        }

        let nearbyRange = 36...60
        let nearbySelections = selectedNotes.filter { nearbyRange.contains($0) }
        #expect(nearbySelections.count >= 1)
    }

    @Test("First comparison (nil lastComparison) picks from weak spots")
    func firstComparisonPicksWeakSpots() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 48, centOffset: 10, isCorrect: true)
        profile.update(note: 60, centOffset: 90, isCorrect: true)

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 36,
            noteRangeMax: 84,
            naturalVsMechanical: 0.0
        )

        var selectedNotes = Set<Int>()
        for _ in 0..<1000 {
            let comparison = strategy.nextComparison(
                profile: profile,
                settings: settings,
                lastComparison: nil
            )
            selectedNotes.insert(comparison.note1.rawValue)
        }

        let weakSpotRange = 59...65
        let hasWeakSpotInRange = selectedNotes.contains { weakSpotRange.contains($0) }
        #expect(hasWeakSpotInRange)
    }

    // MARK: - Note Range Filtering Tests

    @Test("Note range filtering works correctly")
    func noteRangeFiltering() async throws {
        let profile = PerceptualProfile()

        for note in [30, 60, 90] {
            profile.update(note: MIDINote(note), centOffset: 80, isCorrect: true)
        }

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(
            noteRangeMin: 48,
            noteRangeMax: 72,
            naturalVsMechanical: 1.0
        )

        for _ in 0..<20 {
            let comparison = strategy.nextComparison(
                profile: profile,
                settings: settings,
                lastComparison: nil
            )
            #expect(comparison.note1 >= 48)
            #expect(comparison.note1 <= 72)
        }
    }

    @Test("Single note range works without crashing")
    func singleNoteRange() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.note1 == 60)
        #expect(comparison.note2 == 60)
    }

    // MARK: - Comparison Structure Tests

    @Test("nextComparison returns valid Comparison struct")
    func nextComparisonReturnsValidComparison() async throws {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings()

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: nil
        )

        #expect(comparison.note1 >= 0 && comparison.note1 <= 127)
        #expect(comparison.note2 == comparison.note1)
        #expect(comparison.centDifference.magnitude > 0)
        #expect(comparison.centDifference.magnitude <= 100.0)
    }

    @Test("Stateless strategy produces consistent results with same inputs")
    func statelessStrategyConsistency() async throws {
        let profile = PerceptualProfile()

        profile.update(note: 60, centOffset: 42.0, isCorrect: true)
        profile.setDifficulty(note: 60, difficulty: 42.0)

        let strategy = AdaptiveNoteStrategy()
        let settings = TrainingSettings(noteRangeMin: 60, noteRangeMax: 60)

        let comparison1 = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)
        let comparison2 = strategy.nextComparison(profile: profile, settings: settings, lastComparison: nil)

        #expect(comparison1.note1 == 60)
        #expect(comparison2.note1 == 60)

        #expect(comparison1.centDifference.magnitude == 42.0)
        #expect(comparison2.centDifference.magnitude == 42.0)
    }
}

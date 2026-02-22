import Testing
import Foundation
@testable import Peach

/// Tests for TrainingSession.resetTrainingData() — convergence chain reset behavior
@Suite("TrainingSession Reset Tests")
struct TrainingSessionResetTests {

    // MARK: - Cold-Start Behavior After Reset

    @Test("after reset, PerceptualProfile statsForNote returns currentDifficulty 100.0 for all notes")
    @MainActor
    func resetTrainingDataResetsAllCurrentDifficultyToDefault() {
        let profile = PerceptualProfile()
        let session = TrainingSession(
            notePlayer: MockNotePlayer(),
            strategy: MockNextNoteStrategy(),
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0
        )

        // Simulate converged state: lower difficulty on several notes
        profile.setDifficulty(note: 60, difficulty: 30.0)
        profile.setDifficulty(note: 62, difficulty: 50.0)
        profile.update(note: 60, centOffset: 30.0, isCorrect: true)
        profile.update(note: 62, centOffset: 50.0, isCorrect: true)
        #expect(profile.statsForNote(60).currentDifficulty == 30.0)
        #expect(profile.statsForNote(62).currentDifficulty == 50.0)

        // Reset via TrainingSession's centralized method
        session.resetTrainingData()

        // Verify cold start for all notes
        for note in 0..<128 {
            #expect(profile.statsForNote(note).currentDifficulty == 100.0)
        }
        #expect(profile.statsForNote(60).sampleCount == 0)
        #expect(profile.statsForNote(62).sampleCount == 0)
    }

    @Test("after reset, first comparison from AdaptiveNoteStrategy uses 100 cents")
    @MainActor
    func afterResetFirstComparisonUses100Cents() {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let session = TrainingSession(
            notePlayer: MockNotePlayer(),
            strategy: strategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0
        )

        // Simulate converged state
        profile.setDifficulty(note: 60, difficulty: 30.0)
        profile.update(note: 60, centOffset: 30.0, isCorrect: true)

        // Reset via TrainingSession
        session.resetTrainingData()

        // Cold start: nil lastComparison with reset profile → should return 100.0
        let comparison = strategy.nextComparison(
            profile: profile,
            settings: TrainingSettings(),
            lastComparison: nil
        )
        #expect(comparison.centDifference == 100.0)
    }

    @Test("after reset, weightedEffectiveDifficulty returns default with no trained neighbors")
    @MainActor
    func afterResetWeightedEffectiveDifficultyReturnsDefault() {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let session = TrainingSession(
            notePlayer: MockNotePlayer(),
            strategy: strategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0
        )

        // Set up trained neighbors across a range
        for note in 55...65 {
            profile.setDifficulty(note: note, difficulty: 30.0)
            profile.update(note: note, centOffset: 30.0, isCorrect: true)
        }

        // Reset via TrainingSession
        session.resetTrainingData()

        // With all stats cleared, bootstrap should find no trained neighbors → 100.0
        let comparison = strategy.nextComparison(
            profile: profile,
            settings: TrainingSettings(),
            lastComparison: nil
        )
        #expect(comparison.centDifference == 100.0)
    }

    // MARK: - TrendAnalyzer Reset

    @Test("resetTrainingData clears TrendAnalyzer trend data")
    @MainActor
    func resetTrainingDataClearsTrendAnalyzer() {
        // Create TrendAnalyzer with enough records to produce a trend
        var records: [ComparisonRecord] = []
        for i in 0..<30 {
            records.append(ComparisonRecord(
                note1: 60,
                note2: 61,
                note2CentOffset: Double(i) + 1.0,
                isCorrect: true
            ))
        }
        let trendAnalyzer = TrendAnalyzer(records: records)
        #expect(trendAnalyzer.trend != nil)

        let profile = PerceptualProfile()
        let session = TrainingSession(
            notePlayer: MockNotePlayer(),
            strategy: MockNextNoteStrategy(),
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0,
            trendAnalyzer: trendAnalyzer
        )

        // Reset via TrainingSession
        session.resetTrainingData()

        // Verify TrendAnalyzer is cleared
        #expect(trendAnalyzer.trend == nil)
    }

    // MARK: - Stop Before Reset

    @Test("resetTrainingData stops active training before resetting")
    @MainActor
    func resetTrainingDataStopsActiveTraining() async throws {
        let mockPlayer = MockNotePlayer()
        let profile = PerceptualProfile()
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: MockNextNoteStrategy(),
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0
        )

        // Start training and wait for non-idle state
        session.startTraining()
        try await waitForPlayCallCount(mockPlayer, 1)
        #expect(session.state != .idle)

        // Simulate converged difficulty
        profile.setDifficulty(note: 60, difficulty: 30.0)

        // Reset during active training
        session.resetTrainingData()

        // Verify training stopped and state fully cleared
        #expect(session.state == .idle)
        #expect(session.currentDifficulty == nil)
        #expect(profile.statsForNote(60).currentDifficulty == 100.0)
    }
}

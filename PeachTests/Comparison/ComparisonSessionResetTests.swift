import Testing
import Foundation
@testable import Peach

/// Tests for ComparisonSession.resetTrainingData() — convergence chain reset behavior
@Suite("ComparisonSession Reset Tests")
struct ComparisonSessionResetTests {

    // MARK: - Cold-Start Behavior After Reset

    @Test("after reset, PerceptualProfile statsForNote returns currentDifficulty 100.0 for all notes")
    func resetTrainingDataResetsAllCurrentDifficultyToDefault() throws {
        let profile = PerceptualProfile()
        let session = ComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: MockNextComparisonStrategy(),
            profile: profile,
            userSettings: MockUserSettings()
        )

        // Simulate converged state: lower difficulty on several notes
        profile.setDifficulty(note: 60, difficulty: 30.0)
        profile.setDifficulty(note: 62, difficulty: 50.0)
        profile.update(note: 60, centOffset: 30.0, isCorrect: true)
        profile.update(note: 62, centOffset: 50.0, isCorrect: true)
        #expect(profile.statsForNote(60).currentDifficulty == 30.0)
        #expect(profile.statsForNote(62).currentDifficulty == 50.0)

        // Reset via ComparisonSession's centralized method
        try session.resetTrainingData()

        // Verify cold start for all notes
        for note in 0..<128 {
            #expect(profile.statsForNote(MIDINote(note)).currentDifficulty == 100.0)
        }
        #expect(profile.statsForNote(60).sampleCount == 0)
        #expect(profile.statsForNote(62).sampleCount == 0)
    }

    @Test("after reset, first comparison from KazezNoteStrategy uses 100 cents")
    func afterResetFirstComparisonUses100Cents() throws {
        let profile = PerceptualProfile()
        let strategy = KazezNoteStrategy()
        let session = ComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: strategy,
            profile: profile,
            userSettings: MockUserSettings()
        )

        // Simulate converged state
        profile.setDifficulty(note: 60, difficulty: 30.0)
        profile.update(note: 60, centOffset: 30.0, isCorrect: true)

        // Reset via ComparisonSession
        try session.resetTrainingData()

        // Cold start: nil lastComparison with reset profile → should return 100.0
        let comparison = strategy.nextComparison(
            profile: profile,
            settings: TrainingSettings(referencePitch: .concert440),
            lastComparison: nil,
            interval: .prime,
        )
        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    @Test("after reset, weightedEffectiveDifficulty returns default with no trained neighbors")
    func afterResetWeightedEffectiveDifficultyReturnsDefault() throws {
        let profile = PerceptualProfile()
        let strategy = KazezNoteStrategy()
        let session = ComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: strategy,
            profile: profile,
            userSettings: MockUserSettings()
        )

        // Set up trained neighbors across a range
        for note in 55...65 {
            profile.setDifficulty(note: MIDINote(note), difficulty: 30.0)
            profile.update(note: MIDINote(note), centOffset: 30.0, isCorrect: true)
        }

        // Reset via ComparisonSession
        try session.resetTrainingData()

        // With all stats cleared, bootstrap should find no trained neighbors → 100.0
        let comparison = strategy.nextComparison(
            profile: profile,
            settings: TrainingSettings(referencePitch: .concert440),
            lastComparison: nil,
            interval: .prime,
        )
        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    // MARK: - ProgressTimeline Reset

    @Test("resetTrainingData clears ProgressTimeline data")
    func resetTrainingDataClearsProgressTimeline() throws {
        let records = (0..<30).map { i in
            ComparisonRecord(
                referenceNote: 60,
                targetNote: 61,
                centOffset: Double(i) + 1.0,
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament"
            )
        }
        let progressTimeline = ProgressTimeline(comparisonRecords: records)
        #expect(progressTimeline.state(for: .unisonComparison) != .noData)

        let profile = PerceptualProfile()
        let session = ComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: MockNextComparisonStrategy(),
            profile: profile,
            userSettings: MockUserSettings(),
            resettables: [progressTimeline]
        )

        try session.resetTrainingData()

        #expect(progressTimeline.state(for: .unisonComparison) == .noData)
    }

    // MARK: - Stop Before Reset

    @Test("resetTrainingData stops active training before resetting")
    func resetTrainingDataStopsActiveTraining() async throws {
        let mockPlayer = MockNotePlayer()
        let profile = PerceptualProfile()
        let session = ComparisonSession(
            notePlayer: mockPlayer,
            strategy: MockNextComparisonStrategy(),
            profile: profile,
            userSettings: MockUserSettings()
        )

        // Start training and wait for non-idle state
        session.start(intervals: [.prime])
        try await waitForPlayCallCount(mockPlayer, 1)
        #expect(session.state != .idle)

        // Simulate converged difficulty
        profile.setDifficulty(note: 60, difficulty: 30.0)

        // Reset during active training
        try session.resetTrainingData()

        // Verify training stopped and state fully cleared
        #expect(session.state == .idle)
        #expect(session.currentDifficulty == nil)
        #expect(profile.statsForNote(60).currentDifficulty == 100.0)
    }
}

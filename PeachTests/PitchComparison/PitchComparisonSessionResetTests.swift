import Testing
import Foundation
@testable import Peach

/// Tests for PitchComparisonSession.resetTrainingData() — convergence chain reset behavior
@Suite("PitchComparisonSession Reset Tests")
struct PitchComparisonSessionResetTests {

    // MARK: - Cold-Start Behavior After Reset

    @Test("after reset, PerceptualProfile comparison data is cleared")
    func resetTrainingDataClearsComparisonData() throws {
        let profile = PerceptualProfile()
        let session = PitchComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: MockNextPitchComparisonStrategy(),
            profile: profile
        )

        // Simulate converged state via observer
        profile.pitchComparisonCompleted(CompletedPitchComparison(
            pitchComparison: PitchComparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(30.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))
        profile.pitchComparisonCompleted(CompletedPitchComparison(
            pitchComparison: PitchComparison(referenceNote: 62, targetNote: DetunedMIDINote(note: 62, offset: Cents(50.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))
        #expect(profile.comparisonMean(for: .prime) != nil)

        // Reset session state + profile
        try session.resetTrainingData()
        profile.resetAll()

        // Verify cold start
        #expect(profile.comparisonMean(for: .prime) == nil)
    }

    @Test("after reset, first comparison from KazezNoteStrategy uses 100 cents")
    func afterResetFirstComparisonUses100Cents() throws {
        let profile = PerceptualProfile()
        let strategy = KazezNoteStrategy()
        let session = PitchComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: strategy,
            profile: profile
        )

        // Simulate converged state via observer
        profile.pitchComparisonCompleted(CompletedPitchComparison(
            pitchComparison: PitchComparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(30.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))

        // Reset session state + profile
        try session.resetTrainingData()
        profile.resetAll()

        // Cold start: nil lastPitchComparison with reset profile → should return 100.0
        let comparison = strategy.nextPitchComparison(
            profile: profile,
            settings: PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime]),
            lastPitchComparison: nil,
            interval: .prime,
        )
        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    @Test("after reset, weightedEffectiveDifficulty returns default with no trained neighbors")
    func afterResetWeightedEffectiveDifficultyReturnsDefault() throws {
        let profile = PerceptualProfile()
        let strategy = KazezNoteStrategy()
        let session = PitchComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: strategy,
            profile: profile
        )

        // Set up trained data via observer
        for note in 55...65 {
            profile.pitchComparisonCompleted(CompletedPitchComparison(
                pitchComparison: PitchComparison(referenceNote: MIDINote(note), targetNote: DetunedMIDINote(note: MIDINote(note), offset: Cents(30.0))),
                userAnsweredHigher: true, tuningSystem: .equalTemperament
            ))
        }

        // Reset session state + profile
        try session.resetTrainingData()
        profile.resetAll()

        // With all stats cleared, bootstrap should find no data → 100.0
        let comparison = strategy.nextPitchComparison(
            profile: profile,
            settings: PitchComparisonTrainingSettings(referencePitch: .concert440, intervals: [.prime]),
            lastPitchComparison: nil,
            interval: .prime,
        )
        #expect(comparison.targetNote.offset.magnitude == 100.0)
    }

    // MARK: - ProgressTimeline Reset via Profile

    @Test("resetting profile clears ProgressTimeline data")
    func resetProfileClearsProgressTimeline() throws {
        let profile = PerceptualProfile { builder in
            for i in 0..<30 {
                builder.addPoint(
                    MetricPoint(timestamp: Date().addingTimeInterval(Double(i) * 60), value: Cents(Double(i) + 1.0)),
                    for: .unisonPitchComparison
                )
            }
        }
        let progressTimeline = ProgressTimeline(profile: profile)
        #expect(progressTimeline.state(for: .unisonPitchComparison) != .noData)

        profile.resetAll()

        #expect(progressTimeline.state(for: .unisonPitchComparison) == .noData)
    }

    // MARK: - Stop Before Reset

    @Test("resetTrainingData stops active training before resetting")
    func resetTrainingDataStopsActiveTraining() async throws {
        let mockPlayer = MockNotePlayer()
        let profile = PerceptualProfile()
        let session = PitchComparisonSession(
            notePlayer: mockPlayer,
            strategy: MockNextPitchComparisonStrategy(),
            profile: profile
        )

        // Start training and wait for non-idle state
        session.start(settings: defaultTestSettings)
        await mockPlayer.waitForPlay()
        #expect(session.state != .idle)

        // Simulate converged state via observer
        profile.pitchComparisonCompleted(CompletedPitchComparison(
            pitchComparison: PitchComparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(30.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))

        // Reset during active training
        try session.resetTrainingData()
        profile.resetAll()

        // Verify training stopped and state fully cleared
        #expect(session.state == .idle)
        #expect(session.currentDifficulty == nil)
        #expect(profile.comparisonMean(for: .prime) == nil)
    }
}

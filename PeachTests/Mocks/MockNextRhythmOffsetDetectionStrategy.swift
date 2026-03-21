import Foundation
@testable import Peach

final class MockNextRhythmOffsetDetectionStrategy: NextRhythmOffsetDetectionStrategy {

    // MARK: - Test State Tracking

    var nextRhythmOffsetDetectionTrialCallCount = 0
    var lastProfile: TrainingProfile?
    var lastSettings: RhythmOffsetDetectionSettings?
    var lastResult: CompletedRhythmOffsetDetectionTrial?

    // MARK: - Configurable Return

    var trialToReturn = RhythmOffsetDetectionTrial(
        tempo: TempoBPM(80),
        offset: RhythmOffset(.milliseconds(50))
    )

    // MARK: - Callbacks

    var onNextTrialCalled: (() -> Void)?

    // MARK: - NextRhythmOffsetDetectionStrategy Protocol

    func nextRhythmOffsetDetectionTrial(
        profile: TrainingProfile,
        settings: RhythmOffsetDetectionSettings,
        lastResult: CompletedRhythmOffsetDetectionTrial?
    ) -> RhythmOffsetDetectionTrial {
        nextRhythmOffsetDetectionTrialCallCount += 1
        lastProfile = profile
        lastSettings = settings
        self.lastResult = lastResult

        onNextTrialCalled?()

        return trialToReturn
    }

    // MARK: - Test Helpers

    func reset() {
        nextRhythmOffsetDetectionTrialCallCount = 0
        lastProfile = nil
        lastSettings = nil
        lastResult = nil
        onNextTrialCalled = nil
    }
}

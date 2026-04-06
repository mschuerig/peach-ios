import Foundation
@testable import Peach

final class MockNextTimingOffsetDetectionStrategy: NextTimingOffsetDetectionStrategy {

    // MARK: - Test State Tracking

    var nextTimingOffsetDetectionTrialCallCount = 0
    var lastProfile: TrainingProfile?
    var lastSettings: TimingOffsetDetectionSettings?
    var lastResult: CompletedTimingOffsetDetectionTrial?

    // MARK: - Configurable Return

    var trialToReturn = TimingOffsetDetectionTrial(
        tempo: TempoBPM(80),
        offset: TimingOffset(.milliseconds(50))
    )

    // MARK: - Callbacks

    var onNextTrialCalled: (() -> Void)?

    // MARK: - NextTimingOffsetDetectionStrategy Protocol

    func nextTimingOffsetDetectionTrial(
        profile: TrainingProfile,
        settings: TimingOffsetDetectionSettings,
        lastResult: CompletedTimingOffsetDetectionTrial?
    ) -> TimingOffsetDetectionTrial {
        nextTimingOffsetDetectionTrialCallCount += 1
        lastProfile = profile
        lastSettings = settings
        self.lastResult = lastResult

        onNextTrialCalled?()

        return trialToReturn
    }

    // MARK: - Test Helpers

    func reset() {
        nextTimingOffsetDetectionTrialCallCount = 0
        lastProfile = nil
        lastSettings = nil
        lastResult = nil
        onNextTrialCalled = nil
    }
}

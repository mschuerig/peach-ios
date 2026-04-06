import Foundation

protocol NextTimingOffsetDetectionStrategy {
    func nextTimingOffsetDetectionTrial(
        profile: TrainingProfile,
        settings: TimingOffsetDetectionSettings,
        lastResult: CompletedTimingOffsetDetectionTrial?
    ) -> TimingOffsetDetectionTrial
}

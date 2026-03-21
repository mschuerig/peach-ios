import Foundation

protocol NextRhythmOffsetDetectionStrategy {
    func nextRhythmOffsetDetectionTrial(
        profile: TrainingProfile,
        settings: RhythmOffsetDetectionSettings,
        lastResult: CompletedRhythmOffsetDetectionTrial?
    ) -> RhythmOffsetDetectionTrial
}

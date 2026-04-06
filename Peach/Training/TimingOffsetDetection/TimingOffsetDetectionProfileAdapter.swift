import Foundation

struct TimingOffsetDetectionProfileAdapter: TimingOffsetDetectionObserver {
    private let profile: any ProfileUpdating

    init(profile: any ProfileUpdating) {
        self.profile = profile
    }

    func timingOffsetDetectionCompleted(_ result: CompletedTimingOffsetDetectionTrial) {
        guard result.isCorrect else { return }
        guard let range = TempoRange.range(for: result.tempo) else { return }
        profile.update(.rhythm(.timingOffsetDetection, range, result.offset.direction),
                       timestamp: result.timestamp,
                       value: abs(result.offset.statisticalValue))
    }
}

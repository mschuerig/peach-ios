import Foundation

struct RhythmOffsetDetectionProfileAdapter: RhythmOffsetDetectionObserver {
    private let profile: any ProfileUpdating

    init(profile: any ProfileUpdating) {
        self.profile = profile
    }

    func rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial) {
        guard result.isCorrect else { return }
        guard let range = TempoRange.range(for: result.tempo) else { return }
        profile.update(.rhythm(.rhythmOffsetDetection, range, result.offset.direction),
                       timestamp: result.timestamp,
                       value: abs(result.offset.statisticalValue))
    }
}

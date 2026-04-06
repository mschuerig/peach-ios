import Foundation

struct ContinuousRhythmMatchingProfileAdapter: ContinuousRhythmMatchingObserver {
    private let profile: any ProfileUpdating

    init(profile: any ProfileUpdating) {
        self.profile = profile
    }

    func continuousRhythmMatchingCompleted(_ result: CompletedContinuousRhythmMatchingTrial) {
        guard !result.gapResults.isEmpty else { return }
        guard let range = TempoRange.range(for: result.tempo) else { return }
        let offsets = result.gapResults.map(\.offset)
        let signedMeanMs = offsets.reduce(0.0) { $0 + $1.statisticalValue } / Double(offsets.count)
        let direction = RhythmOffset(.milliseconds(signedMeanMs)).direction
        profile.update(.rhythm(.continuousRhythmMatching, range, direction),
                       timestamp: result.timestamp,
                       value: abs(signedMeanMs))
    }
}

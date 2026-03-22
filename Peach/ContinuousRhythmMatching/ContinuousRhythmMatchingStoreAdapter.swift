import Foundation
import os

struct ContinuousRhythmMatchingStoreAdapter: ContinuousRhythmMatchingObserver {
    private static let logger = Logger(subsystem: "com.peach.app", category: "ContinuousRhythmMatchingStoreAdapter")
    private let store: any TrainingRecordPersisting

    init(store: any TrainingRecordPersisting) {
        self.store = store
    }

    func continuousRhythmMatchingCompleted(_ result: CompletedContinuousRhythmMatchingTrial) {
        let positionMeans = Self.computePositionMeanOffsets(from: result.gapResults)
        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: result.tempo.value,
            meanOffsetMs: result.meanOffsetMs ?? 0,
            meanOffsetMsPosition0: positionMeans.0,
            meanOffsetMsPosition1: positionMeans.1,
            meanOffsetMsPosition2: positionMeans.2,
            meanOffsetMsPosition3: positionMeans.3,
            timestamp: result.timestamp
        )
        do {
            try store.save(record)
        } catch {
            Self.logger.warning("Continuous rhythm matching save error: \(error.localizedDescription)")
        }
    }

    private static func computePositionMeanOffsets(from gapResults: [GapResult]) -> (Double?, Double?, Double?, Double?) {
        var grouped: [Int: [Double]] = [:]
        for gap in gapResults {
            grouped[gap.position.rawValue, default: []].append(gap.offset.statisticalValue)
        }
        func mean(for position: Int) -> Double? {
            guard let offsets = grouped[position], !offsets.isEmpty else { return nil }
            return offsets.reduce(0, +) / Double(offsets.count)
        }
        return (mean(for: 0), mean(for: 1), mean(for: 2), mean(for: 3))
    }
}

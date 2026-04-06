import Foundation
import os

struct TimingOffsetDetectionStoreAdapter: TimingOffsetDetectionObserver {
    private static let logger = Logger(subsystem: "com.peach.app", category: "TimingOffsetDetectionStoreAdapter")
    private let store: any TrainingRecordPersisting

    init(store: any TrainingRecordPersisting) {
        self.store = store
    }

    func timingOffsetDetectionCompleted(_ result: CompletedTimingOffsetDetectionTrial) {
        let record = TimingOffsetDetectionRecord(
            tempoBPM: result.tempo.value,
            offsetMs: result.offset.duration / .milliseconds(1),
            isCorrect: result.isCorrect,
            timestamp: result.timestamp
        )
        do {
            try store.save(record)
        } catch let error as DataStoreError {
            Self.logger.warning("Timing offset detection save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Timing offset detection unexpected error: \(error.localizedDescription)")
        }
    }
}

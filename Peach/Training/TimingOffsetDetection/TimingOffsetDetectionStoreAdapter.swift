import Foundation
import os

struct TimingOffsetDetectionStoreAdapter: TimingOffsetDetectionObserver {
    private static let logger = Logger(subsystem: "com.peach.app", category: "TimingOffsetDetectionStoreAdapter")
    private let store: any TrainingRecordPersisting

    init(store: any TrainingRecordPersisting) {
        self.store = store
    }

    func timingOffsetDetectionCompleted(_ result: CompletedTimingOffsetDetectionTrial) {
        let payload = TimingOffsetDetectionPayload(
            tempoBPM: result.tempo.value,
            offsetMs: result.offset.duration / .milliseconds(1),
            isCorrect: result.isCorrect
        )

        do {
            let envelope: TrainingRecord
            do {
                envelope = try JSONEnvelope.encode(payload, timestamp: result.timestamp)
            } catch {
                throw DataStoreError.saveFailed("Failed to encode timing offset detection payload: \(error.localizedDescription)")
            }
            try store.save(envelope)
        } catch let error as DataStoreError {
            Self.logger.warning("Timing offset detection save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Timing offset detection unexpected error: \(error.localizedDescription)")
        }
    }
}

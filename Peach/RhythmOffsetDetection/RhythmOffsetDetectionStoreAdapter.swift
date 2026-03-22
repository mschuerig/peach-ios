import Foundation
import os

struct RhythmOffsetDetectionStoreAdapter: RhythmOffsetDetectionObserver {
    private static let logger = Logger(subsystem: "com.peach.app", category: "RhythmOffsetDetectionStoreAdapter")
    private let store: any TrainingRecordPersisting

    init(store: any TrainingRecordPersisting) {
        self.store = store
    }

    func rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial) {
        let record = RhythmOffsetDetectionRecord(
            tempoBPM: result.tempo.value,
            offsetMs: result.offset.duration / .milliseconds(1),
            isCorrect: result.isCorrect,
            timestamp: result.timestamp
        )
        do {
            try store.save(record)
        } catch {
            Self.logger.warning("Rhythm offset detection save error: \(error.localizedDescription)")
        }
    }
}

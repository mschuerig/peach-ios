import Foundation
import os

struct PitchMatchingStoreAdapter: PitchMatchingObserver {
    private static let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingStoreAdapter")
    private let store: any TrainingRecordPersisting

    init(store: any TrainingRecordPersisting) {
        self.store = store
    }

    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
        let interval = (try? Interval.between(result.referenceNote, result.targetNote))?.rawValue ?? 0
        let record = PitchMatchingRecord(
            referenceNote: result.referenceNote.rawValue,
            targetNote: result.targetNote.rawValue,
            initialCentOffset: result.initialCentOffset.rawValue,
            userCentError: result.userCentError.rawValue,
            interval: interval,
            tuningSystem: result.tuningSystem.identifier,
            timestamp: result.timestamp
        )

        do {
            try store.save(record)
        } catch {
            Self.logger.warning("Pitch matching save error: \(error.localizedDescription)")
        }
    }
}

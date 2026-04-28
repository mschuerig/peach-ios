import Foundation
import os

struct PitchMatchingStoreAdapter: PitchMatchingObserver {
    private static let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingStoreAdapter")
    private let store: any TrainingRecordPersisting

    init(store: any TrainingRecordPersisting) {
        self.store = store
    }

    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
        let interval = abs(result.referenceNote - result.targetNote)
        let payload = PitchMatchingPayload(
            referenceNote: result.referenceNote.rawValue,
            targetNote: result.targetNote.rawValue,
            initialCentOffset: result.initialCentOffset.rawValue,
            userCentError: result.userCentError.rawValue,
            interval: interval,
            tuningSystem: result.tuningSystem.identifier
        )

        do {
            let envelope: TrainingRecord
            do {
                envelope = try JSONEnvelope.encode(payload, timestamp: result.timestamp)
            } catch {
                throw DataStoreError.saveFailed("Failed to encode pitch matching payload: \(error.localizedDescription)")
            }
            try store.save(envelope)
        } catch let error as DataStoreError {
            Self.logger.warning("Pitch matching save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Pitch matching unexpected error: \(error.localizedDescription)")
        }
    }
}

import Foundation
import os

struct PitchDiscriminationStoreAdapter: PitchDiscriminationObserver {
    private static let logger = Logger(subsystem: "com.peach.app", category: "PitchDiscriminationStoreAdapter")
    private let store: any TrainingRecordPersisting

    init(store: any TrainingRecordPersisting) {
        self.store = store
    }

    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
        let trial = completed.trial
        let interval = trial.interval.interval.semitones
        let payload = PitchDiscriminationPayload(
            referenceNote: trial.referenceNote.rawValue,
            targetNote: trial.targetNote.note.rawValue,
            centOffset: trial.targetNote.offset.rawValue,
            isCorrect: completed.isCorrect,
            interval: interval,
            tuningSystem: completed.tuningSystem.identifier
        )

        do {
            let envelope: TrainingRecord
            do {
                envelope = try JSONEnvelope.encode(payload, timestamp: completed.timestamp)
            } catch {
                throw DataStoreError.saveFailed("Failed to encode pitch discrimination payload: \(error.localizedDescription)")
            }
            try store.save(envelope)
        } catch let error as DataStoreError {
            Self.logger.warning("Pitch discrimination save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Pitch discrimination unexpected error: \(error.localizedDescription)")
        }
    }
}

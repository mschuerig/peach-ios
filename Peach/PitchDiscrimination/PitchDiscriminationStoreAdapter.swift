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
        let interval = (try? Interval.between(trial.referenceNote, trial.targetNote.note))?.rawValue ?? 0
        let record = PitchDiscriminationRecord(
            referenceNote: trial.referenceNote.rawValue,
            targetNote: trial.targetNote.note.rawValue,
            centOffset: trial.targetNote.offset.rawValue,
            isCorrect: completed.isCorrect,
            interval: interval,
            tuningSystem: completed.tuningSystem.identifier,
            timestamp: completed.timestamp
        )

        do {
            try store.save(record)
        } catch {
            Self.logger.warning("Pitch discrimination save error: \(error.localizedDescription)")
        }
    }
}

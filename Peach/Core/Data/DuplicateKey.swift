import Foundation

/// Duplicate detection key for pitch-based training records (discrimination and matching).
struct PitchDuplicateKey: Hashable, Sendable {
    let timestampMillis: Int64
    let referenceNote: Int
    let targetNote: Int
    let trainingType: String

    init(timestamp: Date, referenceNote: Int, targetNote: Int, trainingType: String) {
        self.timestampMillis = Int64(timestamp.timeIntervalSinceReferenceDate * 1000)
        self.referenceNote = referenceNote
        self.targetNote = targetNote
        self.trainingType = trainingType
    }

    init(record: PitchDiscriminationRecord) {
        self.init(
            timestamp: record.timestamp,
            referenceNote: record.referenceNote,
            targetNote: record.targetNote,
            trainingType: "pitchDiscrimination"
        )
    }

    init(record: PitchMatchingRecord) {
        self.init(
            timestamp: record.timestamp,
            referenceNote: record.referenceNote,
            targetNote: record.targetNote,
            trainingType: "pitchMatching"
        )
    }
}

/// Duplicate detection key for rhythm-based training records.
struct RhythmDuplicateKey: Hashable, Sendable {
    let timestampMillis: Int64
    let tempoBPM: Int
    let trainingType: String

    init(timestamp: Date, tempoBPM: Int, trainingType: String) {
        self.timestampMillis = Int64(timestamp.timeIntervalSinceReferenceDate * 1000)
        self.tempoBPM = tempoBPM
        self.trainingType = trainingType
    }
}

/// Builds a set of pitch duplicate keys from all existing pitch records in the store.
func buildPitchDuplicateKeys(from store: TrainingDataStore) throws -> Set<PitchDuplicateKey> {
    var keys = Set<PitchDuplicateKey>()
    for record in try store.fetchAllPitchDiscriminations() {
        keys.insert(PitchDuplicateKey(record: record))
    }
    for record in try store.fetchAllPitchMatchings() {
        keys.insert(PitchDuplicateKey(record: record))
    }
    return keys
}

/// Builds a set of rhythm duplicate keys from existing rhythm records of a specific type.
func buildRhythmDuplicateKeys(from store: TrainingDataStore, trainingType: String) throws -> Set<RhythmDuplicateKey> {
    var keys = Set<RhythmDuplicateKey>()
    if trainingType == "rhythmOffsetDetection" {
        for record in try store.fetchAllTimingOffsetDetections() {
            keys.insert(RhythmDuplicateKey(timestamp: record.timestamp, tempoBPM: record.tempoBPM, trainingType: trainingType))
        }
        for record in try store.fetchAllContinuousRhythmMatchings() {
            keys.insert(RhythmDuplicateKey(timestamp: record.timestamp, tempoBPM: record.tempoBPM, trainingType: "continuousRhythmMatching"))
        }
    } else {
        for record in try store.fetchAllContinuousRhythmMatchings() {
            keys.insert(RhythmDuplicateKey(timestamp: record.timestamp, tempoBPM: record.tempoBPM, trainingType: trainingType))
        }
        for record in try store.fetchAllTimingOffsetDetections() {
            keys.insert(RhythmDuplicateKey(timestamp: record.timestamp, tempoBPM: record.tempoBPM, trainingType: "rhythmOffsetDetection"))
        }
    }
    return keys
}

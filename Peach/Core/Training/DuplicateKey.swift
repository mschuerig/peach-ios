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

    init(timestamp: Date, payload: PitchDiscriminationPayload, trainingType: String) {
        self.init(
            timestamp: timestamp,
            referenceNote: payload.referenceNote,
            targetNote: payload.targetNote,
            trainingType: trainingType
        )
    }

    init(timestamp: Date, payload: PitchMatchingPayload, trainingType: String) {
        self.init(
            timestamp: timestamp,
            referenceNote: payload.referenceNote,
            targetNote: payload.targetNote,
            trainingType: trainingType
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

/// Builds the duplicate-key set used by a pitch-discrimination merge importer.
///
/// Only fetches the rows belonging to that discipline; the caller passes its own
/// CSV `trainingType` so duplicate detection compares against the same wire-format
/// identifier the importer just produced.
func buildPitchDuplicateKeys(
    discriminationsIn store: TrainingDataStore,
    trainingType: String
) throws -> Set<PitchDuplicateKey> {
    var keys = Set<PitchDuplicateKey>()
    for entry in try store.fetchPayloads(PitchDiscriminationPayload.self) {
        keys.insert(PitchDuplicateKey(timestamp: entry.timestamp, payload: entry.payload, trainingType: trainingType))
    }
    return keys
}

/// Builds the duplicate-key set used by a pitch-matching merge importer.
func buildPitchDuplicateKeys(
    matchingsIn store: TrainingDataStore,
    trainingType: String
) throws -> Set<PitchDuplicateKey> {
    var keys = Set<PitchDuplicateKey>()
    for entry in try store.fetchPayloads(PitchMatchingPayload.self) {
        keys.insert(PitchDuplicateKey(timestamp: entry.timestamp, payload: entry.payload, trainingType: trainingType))
    }
    return keys
}

/// Builds the duplicate-key set used by a timing-offset-detection merge importer.
///
/// Only fetches the rows belonging to that discipline. The CSV `trainingType` is the
/// wire-format identifier shared with peach-web's exporter (`rhythmOffsetDetection`
/// is the legacy CSV name and must not be renamed here regardless of internal renames).
func buildRhythmDuplicateKeys(
    timingOffsetDetectionsIn store: TrainingDataStore,
    trainingType: String
) throws -> Set<RhythmDuplicateKey> {
    var keys = Set<RhythmDuplicateKey>()
    for entry in try store.fetchPayloads(TimingOffsetDetectionPayload.self) {
        keys.insert(RhythmDuplicateKey(
            timestamp: entry.timestamp,
            tempoBPM: entry.payload.tempoBPM,
            trainingType: trainingType
        ))
    }
    return keys
}

/// Builds the duplicate-key set used by a continuous-rhythm-matching merge importer.
func buildRhythmDuplicateKeys(
    continuousRhythmMatchingsIn store: TrainingDataStore,
    trainingType: String
) throws -> Set<RhythmDuplicateKey> {
    var keys = Set<RhythmDuplicateKey>()
    for entry in try store.fetchPayloads(ContinuousRhythmMatchingPayload.self) {
        keys.insert(RhythmDuplicateKey(
            timestamp: entry.timestamp,
            tempoBPM: entry.payload.tempoBPM,
            trainingType: trainingType
        ))
    }
    return keys
}

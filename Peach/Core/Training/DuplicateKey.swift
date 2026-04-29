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

/// Duplicate detection key for tempo-based training records.
///
/// The two rhythm-category disciplines (timing offset detection, continuous
/// rhythm matching) both deduplicate on `(timestamp, tempoBPM, trainingType)`.
/// The name describes the key's content rather than its discipline category.
struct TempoDuplicateKey: Hashable, Sendable {
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
    try store.forEachPayload(PitchDiscriminationPayload.self) { timestamp, payload in
        keys.insert(PitchDuplicateKey(timestamp: timestamp, payload: payload, trainingType: trainingType))
    }
    return keys
}

/// Builds the duplicate-key set used by a pitch-matching merge importer.
func buildPitchDuplicateKeys(
    matchingsIn store: TrainingDataStore,
    trainingType: String
) throws -> Set<PitchDuplicateKey> {
    var keys = Set<PitchDuplicateKey>()
    try store.forEachPayload(PitchMatchingPayload.self) { timestamp, payload in
        keys.insert(PitchDuplicateKey(timestamp: timestamp, payload: payload, trainingType: trainingType))
    }
    return keys
}

/// Builds the duplicate-key set used by a timing-offset-detection merge importer.
///
/// Only fetches the rows belonging to that discipline. The CSV `trainingType` is the
/// wire-format identifier shared with peach-web's exporter (`rhythmOffsetDetection`
/// is the legacy CSV name and must not be renamed here regardless of internal renames).
func buildTempoDuplicateKeys(
    timingOffsetDetectionsIn store: TrainingDataStore,
    trainingType: String
) throws -> Set<TempoDuplicateKey> {
    var keys = Set<TempoDuplicateKey>()
    try store.forEachPayload(TimingOffsetDetectionPayload.self) { timestamp, payload in
        keys.insert(TempoDuplicateKey(
            timestamp: timestamp,
            tempoBPM: payload.tempoBPM,
            trainingType: trainingType
        ))
    }
    return keys
}

/// Builds the duplicate-key set used by a continuous-rhythm-matching merge importer.
func buildTempoDuplicateKeys(
    continuousRhythmMatchingsIn store: TrainingDataStore,
    trainingType: String
) throws -> Set<TempoDuplicateKey> {
    var keys = Set<TempoDuplicateKey>()
    try store.forEachPayload(ContinuousRhythmMatchingPayload.self) { timestamp, payload in
        keys.insert(TempoDuplicateKey(
            timestamp: timestamp,
            tempoBPM: payload.tempoBPM,
            trainingType: trainingType
        ))
    }
    return keys
}

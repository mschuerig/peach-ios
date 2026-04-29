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

/// Existing-side duplicate-detection state used by merge import.
///
/// Holds two parallel pieces of evidence:
///
/// - `strictKeys` — fully-resolved keys built from successfully-decoded
///   envelopes. Drives normal duplicate detection.
/// - `skippedTimestamps` — timestamps of envelopes whose payload could not be
///   decoded (corrupt, version-incompatible, …). The strict key for these
///   rows is unknowable, so we fall back to a timestamp collision check: an
///   imported row whose timestamp matches a skipped existing timestamp is
///   treated as a possible duplicate and not re-inserted. This errs on the
///   side of *not* generating user-visible duplicates over corrupt rows; the
///   alternative (silently dropping the skipped envelope from dedup) lets
///   re-imports of the same record produce duplicate rows.
struct DuplicateKeyIndex<Key: Hashable> {
    private(set) var strictKeys: Set<Key>
    private(set) var skippedTimestamps: Set<Date>

    init(strictKeys: Set<Key> = [], skippedTimestamps: Set<Date> = []) {
        self.strictKeys = strictKeys
        self.skippedTimestamps = skippedTimestamps
    }

    func contains(_ key: Key, atTimestamp timestamp: Date) -> Bool {
        strictKeys.contains(key) || skippedTimestamps.contains(timestamp)
    }

    mutating func recordImported(_ key: Key) {
        strictKeys.insert(key)
    }

    mutating func recordSkippedExisting(timestamp: Date) {
        skippedTimestamps.insert(timestamp)
    }
}

/// Builds the duplicate-key index used by a pitch-discrimination merge importer.
///
/// Streams existing envelopes via ``TrainingDataStore/forEachPayload(_:onSkip:body:)``
/// so the decoded payload set is never materialised in bulk. Existing envelopes
/// whose payload cannot be decoded contribute their timestamp to the index's
/// `skippedTimestamps` set so re-imports of the corrupt row are still caught
/// as potential duplicates.
func buildPitchDuplicateKeys(
    discriminationsIn store: TrainingDataStore,
    trainingType: String
) throws -> DuplicateKeyIndex<PitchDuplicateKey> {
    var index = DuplicateKeyIndex<PitchDuplicateKey>()
    try store.forEachPayload(
        PitchDiscriminationPayload.self,
        onSkip: { timestamp in index.recordSkippedExisting(timestamp: timestamp) }
    ) { timestamp, payload in
        index.recordImported(PitchDuplicateKey(timestamp: timestamp, payload: payload, trainingType: trainingType))
    }
    return index
}

/// Builds the duplicate-key index used by a pitch-matching merge importer.
func buildPitchDuplicateKeys(
    matchingsIn store: TrainingDataStore,
    trainingType: String
) throws -> DuplicateKeyIndex<PitchDuplicateKey> {
    var index = DuplicateKeyIndex<PitchDuplicateKey>()
    try store.forEachPayload(
        PitchMatchingPayload.self,
        onSkip: { timestamp in index.recordSkippedExisting(timestamp: timestamp) }
    ) { timestamp, payload in
        index.recordImported(PitchDuplicateKey(timestamp: timestamp, payload: payload, trainingType: trainingType))
    }
    return index
}

/// Builds the duplicate-key index used by a timing-offset-detection merge importer.
///
/// The CSV `trainingType` is the wire-format identifier shared with peach-web's
/// exporter (`rhythmOffsetDetection` is the legacy CSV name and must not be
/// renamed here regardless of internal renames).
func buildTempoDuplicateKeys(
    timingOffsetDetectionsIn store: TrainingDataStore,
    trainingType: String
) throws -> DuplicateKeyIndex<TempoDuplicateKey> {
    var index = DuplicateKeyIndex<TempoDuplicateKey>()
    try store.forEachPayload(
        TimingOffsetDetectionPayload.self,
        onSkip: { timestamp in index.recordSkippedExisting(timestamp: timestamp) }
    ) { timestamp, payload in
        index.recordImported(TempoDuplicateKey(
            timestamp: timestamp,
            tempoBPM: payload.tempoBPM,
            trainingType: trainingType
        ))
    }
    return index
}

/// Builds the duplicate-key index used by a continuous-rhythm-matching merge importer.
func buildTempoDuplicateKeys(
    continuousRhythmMatchingsIn store: TrainingDataStore,
    trainingType: String
) throws -> DuplicateKeyIndex<TempoDuplicateKey> {
    var index = DuplicateKeyIndex<TempoDuplicateKey>()
    try store.forEachPayload(
        ContinuousRhythmMatchingPayload.self,
        onSkip: { timestamp in index.recordSkippedExisting(timestamp: timestamp) }
    ) { timestamp, payload in
        index.recordImported(TempoDuplicateKey(
            timestamp: timestamp,
            tempoBPM: payload.tempoBPM,
            trainingType: trainingType
        ))
    }
    return index
}

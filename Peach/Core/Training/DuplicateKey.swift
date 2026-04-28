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

    init(timestamp: Date, payload: PitchDiscriminationPayload) {
        self.init(
            timestamp: timestamp,
            referenceNote: payload.referenceNote,
            targetNote: payload.targetNote,
            trainingType: PitchDiscriminationPayload.disciplineIdentifier
        )
    }

    init(timestamp: Date, payload: PitchMatchingPayload) {
        self.init(
            timestamp: timestamp,
            referenceNote: payload.referenceNote,
            targetNote: payload.targetNote,
            trainingType: PitchMatchingPayload.disciplineIdentifier
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
    for entry in try store.fetchPayloads(PitchDiscriminationPayload.self) {
        keys.insert(PitchDuplicateKey(timestamp: entry.timestamp, payload: entry.payload))
    }
    for entry in try store.fetchPayloads(PitchMatchingPayload.self) {
        keys.insert(PitchDuplicateKey(timestamp: entry.timestamp, payload: entry.payload))
    }
    return keys
}

/// Builds the cross-discipline rhythm duplicate-key set used by both rhythm
/// disciplines' merge importers. The set contains keys for every existing
/// rhythm record across both disciplines, each tagged with its CSV training
/// type so duplicate detection compares against the same wire-format
/// identifier the importer just produced.
///
/// The two CSV training-type strings are wire-format identifiers shared with
/// peach-web's exporter; `rhythmOffsetDetection` is the legacy CSV name and
/// must not be retitled here regardless of internal renames.
func buildRhythmDuplicateKeys(from store: TrainingDataStore) throws -> Set<RhythmDuplicateKey> {
    var keys = Set<RhythmDuplicateKey>()
    for entry in try store.fetchPayloads(TimingOffsetDetectionPayload.self) {
        keys.insert(RhythmDuplicateKey(
            timestamp: entry.timestamp,
            tempoBPM: entry.payload.tempoBPM,
            trainingType: "rhythmOffsetDetection"
        ))
    }
    for entry in try store.fetchPayloads(ContinuousRhythmMatchingPayload.self) {
        keys.insert(RhythmDuplicateKey(
            timestamp: entry.timestamp,
            tempoBPM: entry.payload.tempoBPM,
            trainingType: "continuousRhythmMatching"
        ))
    }
    return keys
}

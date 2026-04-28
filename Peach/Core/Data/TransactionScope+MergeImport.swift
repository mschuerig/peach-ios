import Foundation

extension TrainingDataStore.TransactionScope {
    /// Encodes each payload into a ``TrainingRecord`` envelope and inserts it,
    /// skipping entries whose key already exists in `existingKeys`. Newly
    /// inserted keys are added back into the set so duplicates within the same
    /// batch are caught after the first successful insert.
    ///
    /// Disciplines own duplicate detection (key shape, key construction) and
    /// existing-key fetching; this helper owns the encode-and-insert loop and
    /// the imported/skipped accounting.
    func mergeImportPayloads<P: TrainingDisciplinePayload, K: Hashable>(
        _ entries: [(timestamp: Date, payload: P)],
        existingKeys: inout Set<K>,
        keyFor: (Date, P) -> K
    ) throws -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0
        for entry in entries {
            let key = keyFor(entry.timestamp, entry.payload)
            if existingKeys.contains(key) {
                skipped += 1
            } else {
                let envelope = try JSONEnvelope.encode(entry.payload, timestamp: entry.timestamp)
                insert(envelope)
                existingKeys.insert(key)
                imported += 1
            }
        }
        return (imported: imported, skipped: skipped)
    }
}

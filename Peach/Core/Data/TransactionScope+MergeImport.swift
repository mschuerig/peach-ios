import Foundation

extension TrainingDataStore.TransactionScope {
    /// Encodes each payload into a ``TrainingRecord`` envelope and inserts it,
    /// skipping entries whose key already exists in `existingKeys`. Newly
    /// inserted keys are added back into the set so duplicates within the same
    /// batch are caught after the first successful insert.
    ///
    /// Disciplines define the key shape and seed the existing set; this helper
    /// performs the duplicate check, the encode-and-insert step, and the
    /// imported/skipped accounting. `keyFor` is expected to be injective over
    /// the entries that should be considered distinct — two entries that map
    /// to the same key are silently treated as duplicates of each other.
    ///
    /// On throw (only `JSONEnvelope.encode` throws; `keyFor` and `insert` do
    /// not), the helper exits with the local `imported`/`skipped` counters
    /// discarded. The enclosing ``TrainingDataStore/withinTransaction(_:)``
    /// rolls back the persisted envelopes, but the caller's `existingKeys` is
    /// `inout` and retains the keys of entries that were successfully inserted
    /// before the throw — callers that catch and continue must rebuild the set
    /// rather than reuse it.
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

import Foundation

extension TrainingDataStore.TransactionScope {
    /// Encodes each payload into a ``TrainingRecord`` envelope and inserts it,
    /// skipping entries whose key already exists in `existing.strictKeys`
    /// **or** whose timestamp matches one of `existing.skippedTimestamps`.
    /// Newly inserted keys are added back into the index so duplicates within
    /// the same batch are caught after the first successful insert.
    ///
    /// The skipped-timestamp check exists so that corrupt existing envelopes —
    /// whose strict key cannot be reconstructed — still block re-imports of
    /// the same row from producing user-visible duplicates. See
    /// ``DuplicateKeyIndex`` for the rationale.
    ///
    /// Disciplines define the key shape and seed the existing index; this
    /// helper performs the duplicate check, the encode-and-insert step, and
    /// the imported/skipped accounting. `keyFor` is expected to be injective
    /// over the entries that should be considered distinct — two entries that
    /// map to the same key are silently treated as duplicates of each other.
    ///
    /// On throw (only `JSONEnvelope.encode` throws; `keyFor` and `insert` do
    /// not), the helper exits with the local `imported`/`skipped` counters
    /// discarded. The enclosing ``TrainingDataStore/withinTransaction(_:)``
    /// rolls back the persisted envelopes, but the caller's `existing` is
    /// `inout` and retains the keys of entries that were successfully inserted
    /// before the throw — callers that catch and continue must rebuild the
    /// index rather than reuse it.
    func mergeImportPayloads<P: TrainingDisciplinePayload, K: Hashable>(
        _ entries: [(timestamp: Date, payload: P)],
        existing index: inout DuplicateKeyIndex<K>,
        keyFor: (Date, P) -> K
    ) throws -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0
        for entry in entries {
            let key = keyFor(entry.timestamp, entry.payload)
            if index.contains(key, atTimestamp: entry.timestamp) {
                skipped += 1
            } else {
                let envelope = try JSONEnvelope.encode(entry.payload, timestamp: entry.timestamp)
                insert(envelope)
                index.recordImported(key)
                imported += 1
            }
        }
        return (imported: imported, skipped: skipped)
    }
}

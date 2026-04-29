import SwiftData
import Foundation
import os

/// Discipline-agnostic persistence layer for training records.
///
/// SwiftData sees a single `@Model` type — ``TrainingRecord`` — and stores
/// every discipline's data inside its `payloadData` blob. This store provides
/// envelope-typed CRUD plus payload-typed iteration helpers
/// (``forEachPayload(_:onSkip:body:)`` for streaming, ``fetchPayloads(_:)``
/// for the array-shaped convenience) that filter envelopes by
/// ``TrainingDisciplinePayload/disciplineIdentifier`` and decode them into
/// payload structs.
final class TrainingDataStore {
    private static let logger = Logger(subsystem: "com.peach.app", category: "TrainingDataStore")
    private let modelContext: ModelContext

    /// Batch size handed to ``ModelContext/enumerate(_:batchSize:allowEscapingMutations:block:)``
    /// during streaming iteration. SwiftData fetches one batch of envelopes,
    /// hands them to the iteration body one at a time, then releases the batch
    /// before fetching the next — so peak memory scales with this constant
    /// rather than with the discipline's full row count.
    private static let streamingBatchSize = 1_000

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Transaction Support

    /// Scoped context available only inside `withinTransaction` closures.
    /// Provides `insert` without committing — the enclosing transaction handles commit/rollback.
    struct TransactionScope {
        private let modelContext: ModelContext

        fileprivate init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }

        func insert(_ envelope: TrainingRecord) {
            modelContext.insert(envelope)
        }
    }

    /// Executes a closure inside a single `modelContext.transaction`, providing atomicity.
    /// If the closure throws, the transaction rolls back and the error propagates.
    func withinTransaction(_ work: (TransactionScope) throws -> Void) throws {
        let scope = TransactionScope(modelContext: modelContext)
        do {
            try modelContext.transaction {
                try work(scope)
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Envelope CRUD

    func save(_ envelope: TrainingRecord) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(envelope)
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to save TrainingRecord: \(error.localizedDescription)")
        }
    }

    /// Iterates this discipline's payloads in timestamp-ascending order, decoding
    /// one envelope at a time and handing the result to `body`. Envelopes are
    /// streamed from SwiftData via ``ModelContext/enumerate(_:batchSize:allowEscapingMutations:block:)``,
    /// so neither the envelope array nor the decoded payload sequence is held
    /// in memory in bulk — peak memory scales with ``streamingBatchSize``, not
    /// with the discipline's row count. Sort order is provided by the
    /// ``FetchDescriptor``'s `sortBy` (DB-side, deterministic for equal
    /// timestamps).
    ///
    /// **Error contract.** Any failure from this method — SwiftData fetch
    /// errors, `body`-thrown errors, `onSkip`-thrown errors — is wrapped in
    /// ``DataStoreError/fetchFailed(_:)`` with the underlying error's
    /// `localizedDescription`. Iteration aborts on the first thrown error;
    /// later envelopes are not visited. The original error type is not
    /// preserved across the boundary; callers that need to distinguish causes
    /// should inspect the wrapped message, not the type.
    ///
    /// - Parameters:
    ///   - type: The payload type whose envelopes to iterate.
    ///   - onSkip: Optional handler invoked when an envelope's payload fails
    ///     to decode. Receives the envelope's timestamp. Decode failure is
    ///     logged either way; this hook lets callers (notably duplicate-key
    ///     builders) react conservatively to corrupt existing data.
    ///   - body: Closure invoked once per successfully-decoded envelope, in
    ///     timestamp-ascending order.
    func forEachPayload<P: TrainingDisciplinePayload>(
        _ type: P.Type,
        onSkip: ((Date) throws -> Void)? = nil,
        body: (Date, P) throws -> Void
    ) throws {
        let identifier = P.disciplineIdentifier
        let descriptor = FetchDescriptor<TrainingRecord>(
            predicate: #Predicate { $0.disciplineIdentifier == identifier },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            try modelContext.enumerate(descriptor, batchSize: Self.streamingBatchSize) { envelope in
                let payload: P
                do {
                    payload = try JSONEnvelope.decode(P.self, from: envelope)
                } catch {
                    Self.logger.error(
                        "Skipping undecodable \(identifier, privacy: .public) envelope at \(envelope.timestamp, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                    try onSkip?(envelope.timestamp)
                    return
                }
                try body(envelope.timestamp, payload)
            }
        } catch {
            throw DataStoreError.fetchFailed("Failed to enumerate envelopes for \(identifier): \(error.localizedDescription)")
        }
    }

    /// Fetches all payloads for a discipline, sorted by timestamp.
    ///
    /// Thin convenience over ``forEachPayload(_:onSkip:body:)`` for callers
    /// that want the full array. Streaming callers should prefer the
    /// iteration API to avoid materialising every decoded payload at once.
    func fetchPayloads<P: TrainingDisciplinePayload>(_ type: P.Type) throws -> [TimestampedPayload<P>] {
        var payloads: [TimestampedPayload<P>] = []
        try forEachPayload(type) { timestamp, payload in
            payloads.append(TimestampedPayload(timestamp: timestamp, payload: payload))
        }
        return payloads
    }

    /// Deletes every envelope in the store.
    func deleteAll() throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: TrainingRecord.self)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all records: \(error.localizedDescription)")
        }
    }

    /// Atomically replaces all envelopes: deletes existing data and inserts new envelopes in a single transaction.
    func replaceAllRecords(_ envelopes: [TrainingRecord]) throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: TrainingRecord.self)
                for envelope in envelopes {
                    modelContext.insert(envelope)
                }
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to replace all records: \(error.localizedDescription)")
        }
    }
}

// MARK: - TrainingRecordPersisting

extension TrainingDataStore: TrainingRecordPersisting {}

// MARK: - Resettable Conformance

extension TrainingDataStore: Resettable {
    func reset() throws {
        try deleteAll()
    }
}

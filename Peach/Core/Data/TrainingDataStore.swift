import SwiftData
import Foundation
import os

/// Discipline-agnostic persistence layer for training records.
///
/// SwiftData sees a single `@Model` type — ``TrainingRecord`` — and stores
/// every discipline's data inside its `payloadData` blob. This store provides
/// envelope-typed CRUD plus payload-typed iteration helpers
/// (``forEachPayload(_:body:)`` for streaming, ``fetchPayloads(_:)`` for the
/// array-shaped convenience) that filter envelopes by
/// ``TrainingDisciplinePayload/disciplineIdentifier`` and decode them into
/// payload structs.
final class TrainingDataStore {
    private static let logger = Logger(subsystem: "com.peach.app", category: "TrainingDataStore")
    private let modelContext: ModelContext

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

    /// Fetches all envelopes whose `disciplineIdentifier` matches the given identifier.
    /// Order is unspecified; callers that need chronological order must sort by ``TrainingRecord/timestamp``.
    func fetchEnvelopes(forDisciplineIdentifier identifier: String) throws -> [TrainingRecord] {
        let descriptor = FetchDescriptor<TrainingRecord>(
            predicate: #Predicate { $0.disciplineIdentifier == identifier }
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch envelopes for \(identifier): \(error.localizedDescription)")
        }
    }

    /// Iterates this discipline's payloads in timestamp-ascending order, decoding
    /// one envelope at a time and handing the result to `body`. The previously
    /// decoded payload is released before the next decode, so callers that
    /// scan-and-aggregate (profile rebuild, duplicate-key building, CSV export)
    /// never hold the full decoded array in memory.
    ///
    /// SwiftData's ``ModelContext/fetch(_:)`` is array-shaped today and returns
    /// `[TrainingRecord]`; the envelope array itself is therefore materialised.
    /// What this API streams is the *decoded payload* — the typically larger,
    /// per-discipline value type produced by ``JSONEnvelope/decode(_:from:)``.
    ///
    /// A single corrupt envelope is logged and skipped rather than failing the
    /// whole iteration — this keeps one bad row from blanking out an entire
    /// discipline's history. If `body` throws, iteration aborts and the error
    /// propagates unchanged.
    func forEachPayload<P: TrainingDisciplinePayload>(
        _ type: P.Type,
        body: (Date, P) throws -> Void
    ) throws {
        let envelopes = try fetchEnvelopes(forDisciplineIdentifier: P.disciplineIdentifier)
        for envelope in envelopes.sorted(by: { $0.timestamp < $1.timestamp }) {
            let payload: P
            do {
                payload = try JSONEnvelope.decode(P.self, from: envelope)
            } catch {
                Self.logger.error(
                    "Skipping undecodable \(P.disciplineIdentifier, privacy: .public) envelope at \(envelope.timestamp, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                continue
            }
            try body(envelope.timestamp, payload)
        }
    }

    /// Fetches all payloads for a discipline, sorted by timestamp.
    ///
    /// Thin convenience over ``forEachPayload(_:body:)`` for callers that want
    /// the full array. Streaming callers should prefer the iteration API to
    /// avoid materialising every decoded payload at once.
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

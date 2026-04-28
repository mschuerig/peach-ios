import SwiftData
import Foundation
import os

/// Discipline-agnostic persistence layer for training records.
///
/// SwiftData sees a single `@Model` type — ``TrainingRecord`` — and stores
/// every discipline's data inside its `payloadData` blob. This store provides
/// envelope-typed CRUD plus a small ``fetchPayloads(_:)`` helper that filters
/// envelopes by ``TrainingDisciplinePayload/disciplineIdentifier`` and decodes
/// them into payload structs.
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
    /// Sort order matches insertion order; callers needing chronological order sort by ``TrainingRecord/timestamp``.
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

    /// Fetches all payloads for a discipline, sorted by timestamp.
    func fetchPayloads<P: TrainingDisciplinePayload>(_ type: P.Type) throws -> [(timestamp: Date, payload: P)] {
        let envelopes = try fetchEnvelopes(forDisciplineIdentifier: P.disciplineIdentifier)
        return try envelopes
            .sorted { $0.timestamp < $1.timestamp }
            .map { ($0.timestamp, try JSONEnvelope.decode(P.self, from: $0)) }
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

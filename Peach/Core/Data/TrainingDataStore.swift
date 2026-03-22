import SwiftData
import Foundation
import os

/// Discipline-agnostic persistence layer for training records.
/// Responsibilities: CREATE, READ, DELETE operations only — no business logic.
final class TrainingDataStore {
    private static let logger = Logger(subsystem: "com.peach.app", category: "TrainingDataStore")
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Generic CRUD

    func save(_ record: some PersistentModel) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(record)
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to save \(type(of: record)): \(error.localizedDescription)")
        }
    }

    func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch \(T.self): \(error.localizedDescription)")
        }
    }

    func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: type)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all \(T.self): \(error.localizedDescription)")
        }
    }

    func delete(_ record: some PersistentModel) throws {
        do {
            try modelContext.transaction {
                modelContext.delete(record)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete record: \(error.localizedDescription)")
        }
    }

    /// Deletes all records of all registered discipline record types.
    func deleteAll() throws {
        do {
            try modelContext.transaction {
                for recordType in TrainingDisciplineRegistry.shared.recordTypes {
                    try modelContext.delete(model: recordType)
                }
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all records: \(error.localizedDescription)")
        }
    }

    /// Atomically replaces all records: deletes existing data and inserts new records in a single transaction.
    func replaceAllRecords(_ records: [any PersistentModel]) throws {
        do {
            try modelContext.transaction {
                for recordType in TrainingDisciplineRegistry.shared.recordTypes {
                    try modelContext.delete(model: recordType)
                }
                for record in records {
                    modelContext.insert(record)
                }
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to replace all records: \(error.localizedDescription)")
        }
    }

    // MARK: - Per-Type Convenience (sorted by timestamp)

    func fetchAllPitchDiscriminations() throws -> [PitchDiscriminationRecord] {
        let descriptor = FetchDescriptor<PitchDiscriminationRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch records: \(error.localizedDescription)")
        }
    }

    func fetchAllPitchMatchings() throws -> [PitchMatchingRecord] {
        let descriptor = FetchDescriptor<PitchMatchingRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch pitch matching records: \(error.localizedDescription)")
        }
    }

    func fetchAllRhythmOffsetDetections() throws -> [RhythmOffsetDetectionRecord] {
        let descriptor = FetchDescriptor<RhythmOffsetDetectionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch rhythm offset detection records: \(error.localizedDescription)")
        }
    }

    func fetchAllContinuousRhythmMatchings() throws -> [ContinuousRhythmMatchingRecord] {
        let descriptor = FetchDescriptor<ContinuousRhythmMatchingRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch continuous rhythm matching records: \(error.localizedDescription)")
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

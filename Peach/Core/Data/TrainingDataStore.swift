import SwiftData
import Foundation
import os

/// Pure persistence layer for PitchDiscriminationRecord and PitchMatchingRecord storage and retrieval
/// Responsibilities: CREATE, READ, DELETE operations only - no business logic
final class TrainingDataStore {
    private static let logger = Logger(subsystem: "com.peach.app", category: "TrainingDataStore")
    private let modelContext: ModelContext

    /// Creates a TrainingDataStore with the given ModelContext
    /// - Parameter modelContext: SwiftData context for database operations
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ record: some PersistentModel) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(record)
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to save \(type(of: record)): \(error.localizedDescription)")
        }
    }

    /// Fetches all pitch discrimination records from persistent storage
    /// - Returns: All PitchDiscriminationRecord instances sorted by timestamp (oldest first)
    /// - Throws: DataStoreError.fetchFailed if fetch operation fails
    /// - Note: Loads all records into memory at once. For MVP with expected low data volumes (hundreds to low thousands
    ///   of records), this is acceptable. Future optimization: implement batched iteration if data volume becomes large
    ///   (tens of thousands of records or memory pressure observed).
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

    /// Deletes a pitch discrimination record from persistent storage
    /// - Parameter record: The PitchDiscriminationRecord to delete
    /// - Throws: DataStoreError.deleteFailed if delete operation fails
    func delete(_ record: PitchDiscriminationRecord) throws {
        do {
            try modelContext.transaction {
                modelContext.delete(record)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete record: \(error.localizedDescription)")
        }
    }

    /// Deletes all records from persistent storage
    /// Used by Settings "Reset All Training Data" action
    /// - Throws: DataStoreError.deleteFailed if batch delete fails; rolls back on partial failure
    func deleteAll() throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: PitchDiscriminationRecord.self)
                try modelContext.delete(model: PitchMatchingRecord.self)
                try modelContext.delete(model: RhythmOffsetDetectionRecord.self)
                try modelContext.delete(model: ContinuousRhythmMatchingRecord.self)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all records: \(error.localizedDescription)")
        }
    }

    /// Atomically replaces all records: deletes existing data and inserts new records in a single transaction.
    /// If any insert fails, the entire operation rolls back and existing data is preserved.
    /// - Parameters:
    ///   - pitchDiscriminations: Pitch discrimination records to insert
    ///   - pitchMatchings: Pitch matching records to insert
    /// - Throws: DataStoreError.saveFailed if the transaction fails
    func replaceAllRecords(
        pitchDiscriminations: [PitchDiscriminationRecord],
        pitchMatchings: [PitchMatchingRecord],
        rhythmOffsetDetections: [RhythmOffsetDetectionRecord],
        continuousRhythmMatchings: [ContinuousRhythmMatchingRecord] = []
    ) throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: PitchDiscriminationRecord.self)
                try modelContext.delete(model: PitchMatchingRecord.self)
                try modelContext.delete(model: RhythmOffsetDetectionRecord.self)
                try modelContext.delete(model: ContinuousRhythmMatchingRecord.self)
                for record in pitchDiscriminations {
                    modelContext.insert(record)
                }
                for record in pitchMatchings {
                    modelContext.insert(record)
                }
                for record in rhythmOffsetDetections {
                    modelContext.insert(record)
                }
                for record in continuousRhythmMatchings {
                    modelContext.insert(record)
                }
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to replace all records: \(error.localizedDescription)")
        }
    }

    // MARK: - Rhythm Offset Detection CRUD

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

    func deleteAllRhythmOffsetDetections() throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: RhythmOffsetDetectionRecord.self)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all rhythm offset detection records: \(error.localizedDescription)")
        }
    }

    // MARK: - Continuous Rhythm Matching CRUD

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

    func deleteAllContinuousRhythmMatchings() throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: ContinuousRhythmMatchingRecord.self)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all continuous rhythm matching records: \(error.localizedDescription)")
        }
    }

    // MARK: - Pitch Matching CRUD

    /// Fetches all pitch matching records from persistent storage
    /// - Returns: All PitchMatchingRecord instances sorted by timestamp (oldest first)
    /// - Throws: DataStoreError.fetchFailed if fetch operation fails
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
}

// MARK: - TrainingRecordPersisting

extension TrainingDataStore: TrainingRecordPersisting {}

// MARK: - Resettable Conformance

extension TrainingDataStore: Resettable {
    func reset() throws {
        try deleteAll()
    }
}


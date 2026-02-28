import SwiftData
import Foundation

/// Pure persistence layer for ComparisonRecord and PitchMatchingRecord storage and retrieval
/// Responsibilities: CREATE, READ, DELETE operations only - no business logic
final class TrainingDataStore {
    private let modelContext: ModelContext

    /// Creates a TrainingDataStore with the given ModelContext
    /// - Parameter modelContext: SwiftData context for database operations
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Saves a comparison record to persistent storage
    /// - Parameter record: The ComparisonRecord to save
    /// - Throws: DataStoreError.saveFailed if save operation fails
    func save(_ record: ComparisonRecord) throws {
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            throw DataStoreError.saveFailed("Failed to save ComparisonRecord: \(error.localizedDescription)")
        }
    }

    /// Fetches all comparison records from persistent storage
    /// - Returns: All ComparisonRecord instances sorted by timestamp (oldest first)
    /// - Throws: DataStoreError.fetchFailed if fetch operation fails
    /// - Note: Loads all records into memory at once. For MVP with expected low data volumes (hundreds to low thousands
    ///   of records), this is acceptable. Future optimization: implement batched iteration if data volume becomes large
    ///   (tens of thousands of records or memory pressure observed).
    func fetchAllComparisons() throws -> [ComparisonRecord] {
        let descriptor = FetchDescriptor<ComparisonRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch records: \(error.localizedDescription)")
        }
    }

    /// Deletes a comparison record from persistent storage
    /// - Parameter record: The ComparisonRecord to delete
    /// - Throws: DataStoreError.deleteFailed if delete operation fails
    func delete(_ record: ComparisonRecord) throws {
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete record: \(error.localizedDescription)")
        }
    }

    /// Deletes all records (comparisons and pitch matchings) from persistent storage
    /// Used by Settings "Reset All Training Data" action
    /// - Throws: DataStoreError.deleteFailed if batch delete fails; rolls back on partial failure
    func deleteAll() throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: ComparisonRecord.self)
                try modelContext.delete(model: PitchMatchingRecord.self)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all records: \(error.localizedDescription)")
        }
    }

    // MARK: - Pitch Matching CRUD

    /// Saves a pitch matching record to persistent storage
    /// - Parameter record: The PitchMatchingRecord to save
    /// - Throws: DataStoreError.saveFailed if save operation fails
    func save(_ record: PitchMatchingRecord) throws {
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            throw DataStoreError.saveFailed("Failed to save PitchMatchingRecord: \(error.localizedDescription)")
        }
    }

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

// MARK: - Resettable Conformance

extension TrainingDataStore: Resettable {
    func reset() throws {
        try deleteAll()
    }
}

// MARK: - PitchMatchingObserver Conformance

extension TrainingDataStore: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        let record = PitchMatchingRecord(
            referenceNote: result.referenceNote.rawValue,
            initialCentOffset: result.initialCentOffset,
            userCentError: result.userCentError,
            timestamp: result.timestamp
        )

        do {
            try save(record)
        } catch let error as DataStoreError {
            print("⚠️ TrainingDataStore pitch matching save error: \(error.localizedDescription)")
        } catch {
            print("⚠️ TrainingDataStore pitch matching unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - ComparisonObserver Conformance

extension TrainingDataStore: ComparisonObserver {
    /// Observes comparison completion and persists the result
    /// - Parameter completed: The completed comparison with user's answer and result
    func comparisonCompleted(_ completed: CompletedComparison) {
        let comparison = completed.comparison
        let record = ComparisonRecord(
            referenceNote: comparison.referenceNote.rawValue,
            targetNote: comparison.targetNote.note.rawValue,
            centOffset: comparison.targetNote.offset.rawValue,
            isCorrect: completed.isCorrect,
            timestamp: completed.timestamp
        )

        do {
            try save(record)
        } catch let error as DataStoreError {
            // Data error - log but don't propagate (observers shouldn't fail training)
            print("⚠️ TrainingDataStore save error: \(error.localizedDescription)")
        } catch {
            // Unexpected error - log but don't propagate
            print("⚠️ TrainingDataStore unexpected error: \(error.localizedDescription)")
        }
    }
}

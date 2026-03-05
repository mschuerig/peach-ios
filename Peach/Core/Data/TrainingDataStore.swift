import SwiftData
import Foundation

/// Pure persistence layer for PitchComparisonRecord and PitchMatchingRecord storage and retrieval
/// Responsibilities: CREATE, READ, DELETE operations only - no business logic
final class TrainingDataStore {
    private let modelContext: ModelContext

    /// Creates a TrainingDataStore with the given ModelContext
    /// - Parameter modelContext: SwiftData context for database operations
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Saves a comparison record to persistent storage
    /// - Parameter record: The PitchComparisonRecord to save
    /// - Throws: DataStoreError.saveFailed if save operation fails
    func save(_ record: PitchComparisonRecord) throws {
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            throw DataStoreError.saveFailed("Failed to save PitchComparisonRecord: \(error.localizedDescription)")
        }
    }

    /// Fetches all comparison records from persistent storage
    /// - Returns: All PitchComparisonRecord instances sorted by timestamp (oldest first)
    /// - Throws: DataStoreError.fetchFailed if fetch operation fails
    /// - Note: Loads all records into memory at once. For MVP with expected low data volumes (hundreds to low thousands
    ///   of records), this is acceptable. Future optimization: implement batched iteration if data volume becomes large
    ///   (tens of thousands of records or memory pressure observed).
    func fetchAllPitchComparisons() throws -> [PitchComparisonRecord] {
        let descriptor = FetchDescriptor<PitchComparisonRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch records: \(error.localizedDescription)")
        }
    }

    /// Deletes a comparison record from persistent storage
    /// - Parameter record: The PitchComparisonRecord to delete
    /// - Throws: DataStoreError.deleteFailed if delete operation fails
    func delete(_ record: PitchComparisonRecord) throws {
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
                try modelContext.delete(model: PitchComparisonRecord.self)
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
        let interval = (try? Interval.between(result.referenceNote, result.targetNote))?.rawValue ?? 0
        let record = PitchMatchingRecord(
            referenceNote: result.referenceNote.rawValue,
            targetNote: result.targetNote.rawValue,
            initialCentOffset: result.initialCentOffset.rawValue,
            userCentError: result.userCentError.rawValue,
            interval: interval,
            tuningSystem: result.tuningSystem.identifier,
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

// MARK: - PitchComparisonObserver Conformance

extension TrainingDataStore: PitchComparisonObserver {
    /// Observes pitch comparison completion and persists the result
    /// - Parameter completed: The completed pitch comparison with user's answer and result
    func pitchComparisonCompleted(_ completed: CompletedPitchComparison) {
        let pitchComparison = completed.pitchComparison
        let interval = (try? Interval.between(pitchComparison.referenceNote, pitchComparison.targetNote.note))?.rawValue ?? 0
        let record = PitchComparisonRecord(
            referenceNote: pitchComparison.referenceNote.rawValue,
            targetNote: pitchComparison.targetNote.note.rawValue,
            centOffset: pitchComparison.targetNote.offset.rawValue,
            isCorrect: completed.isCorrect,
            interval: interval,
            tuningSystem: completed.tuningSystem.identifier,
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

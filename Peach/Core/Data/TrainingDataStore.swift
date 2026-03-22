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

    /// Saves a pitch discrimination record to persistent storage
    /// - Parameter record: The PitchDiscriminationRecord to save
    /// - Throws: DataStoreError.saveFailed if save operation fails
    func save(_ record: PitchDiscriminationRecord) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(record)
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to save PitchDiscriminationRecord: \(error.localizedDescription)")
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
                try modelContext.delete(model: RhythmMatchingRecord.self)
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
        rhythmMatchings: [RhythmMatchingRecord],
        continuousRhythmMatchings: [ContinuousRhythmMatchingRecord] = []
    ) throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: PitchDiscriminationRecord.self)
                try modelContext.delete(model: PitchMatchingRecord.self)
                try modelContext.delete(model: RhythmOffsetDetectionRecord.self)
                try modelContext.delete(model: RhythmMatchingRecord.self)
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
                for record in rhythmMatchings {
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

    func save(_ record: RhythmOffsetDetectionRecord) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(record)
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to save RhythmOffsetDetectionRecord: \(error.localizedDescription)")
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

    func deleteAllRhythmOffsetDetections() throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: RhythmOffsetDetectionRecord.self)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all rhythm offset detection records: \(error.localizedDescription)")
        }
    }

    // MARK: - Rhythm Matching CRUD

    func save(_ record: RhythmMatchingRecord) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(record)
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to save RhythmMatchingRecord: \(error.localizedDescription)")
        }
    }

    func fetchAllRhythmMatchings() throws -> [RhythmMatchingRecord] {
        let descriptor = FetchDescriptor<RhythmMatchingRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw DataStoreError.fetchFailed("Failed to fetch rhythm matching records: \(error.localizedDescription)")
        }
    }

    func deleteAllRhythmMatchings() throws {
        do {
            try modelContext.transaction {
                try modelContext.delete(model: RhythmMatchingRecord.self)
            }
        } catch {
            throw DataStoreError.deleteFailed("Failed to delete all rhythm matching records: \(error.localizedDescription)")
        }
    }

    // MARK: - Continuous Rhythm Matching CRUD

    func save(_ record: ContinuousRhythmMatchingRecord) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(record)
            }
        } catch {
            throw DataStoreError.saveFailed("Failed to save ContinuousRhythmMatchingRecord: \(error.localizedDescription)")
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

    /// Saves a pitch matching record to persistent storage
    /// - Parameter record: The PitchMatchingRecord to save
    /// - Throws: DataStoreError.saveFailed if save operation fails
    func save(_ record: PitchMatchingRecord) throws {
        do {
            try modelContext.transaction {
                modelContext.insert(record)
            }
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

// MARK: - RhythmOffsetDetectionObserver Conformance

extension TrainingDataStore: RhythmOffsetDetectionObserver {
    func rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial) {
        let record = RhythmOffsetDetectionRecord(
            tempoBPM: result.tempo.value,
            offsetMs: result.offset.duration / .milliseconds(1),
            isCorrect: result.isCorrect,
            timestamp: result.timestamp
        )
        do {
            try save(record)
        } catch let error as DataStoreError {
            Self.logger.warning("Rhythm offset detection save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Rhythm offset detection unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - RhythmMatchingObserver Conformance

extension TrainingDataStore: RhythmMatchingObserver {
    func rhythmMatchingCompleted(_ result: CompletedRhythmMatchingTrial) {
        let record = RhythmMatchingRecord(
            tempoBPM: result.tempo.value,
            userOffsetMs: result.userOffset.duration / .milliseconds(1),
            timestamp: result.timestamp
        )
        do {
            try save(record)
        } catch let error as DataStoreError {
            Self.logger.warning("Rhythm matching save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Rhythm matching unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - PitchMatchingObserver Conformance

extension TrainingDataStore: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
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
            Self.logger.warning("Pitch matching save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Pitch matching unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - PitchDiscriminationObserver Conformance

extension TrainingDataStore: PitchDiscriminationObserver {
    /// Observes pitch discrimination completion and persists the result
    /// - Parameter completed: The completed pitch discrimination with user's answer and result
    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
        let trial = completed.trial
        let interval = (try? Interval.between(trial.referenceNote, trial.targetNote.note))?.rawValue ?? 0
        let record = PitchDiscriminationRecord(
            referenceNote: trial.referenceNote.rawValue,
            targetNote: trial.targetNote.note.rawValue,
            centOffset: trial.targetNote.offset.rawValue,
            isCorrect: completed.isCorrect,
            interval: interval,
            tuningSystem: completed.tuningSystem.identifier,
            timestamp: completed.timestamp
        )

        do {
            try save(record)
        } catch let error as DataStoreError {
            // Data error - log but don't propagate (observers shouldn't fail training)
            Self.logger.warning("Pitch discrimination save error: \(error.localizedDescription)")
        } catch {
            // Unexpected error - log but don't propagate
            Self.logger.warning("Pitch discrimination unexpected error: \(error.localizedDescription)")
        }
    }
}

// MARK: - ContinuousRhythmMatchingObserver Conformance

extension TrainingDataStore: ContinuousRhythmMatchingObserver {
    func continuousRhythmMatchingCompleted(_ result: CompletedContinuousRhythmMatchingTrial) {
        let breakdowns = buildPositionBreakdowns(from: result.gapResults)
        let breakdownJSON = (try? JSONEncoder().encode(breakdowns)) ?? Data()
        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: result.tempo.value,
            meanOffsetMs: result.meanOffsetMs ?? 0,
            gapPositionBreakdownJSON: breakdownJSON,
            timestamp: result.timestamp
        )
        do {
            try save(record)
        } catch let error as DataStoreError {
            Self.logger.warning("Continuous rhythm matching save error: \(error.localizedDescription)")
        } catch {
            Self.logger.warning("Continuous rhythm matching unexpected error: \(error.localizedDescription)")
        }
    }

    private func buildPositionBreakdowns(from gapResults: [GapResult]) -> [PositionBreakdown] {
        var grouped: [Int: [Double]] = [:]
        for gap in gapResults {
            grouped[gap.position.rawValue, default: []].append(gap.offset.statisticalValue)
        }
        return grouped.sorted { $0.key < $1.key }.map { pos, offsets in
            let meanOffset = offsets.reduce(0, +) / Double(offsets.count)
            return PositionBreakdown(
                position: pos,
                count: offsets.count,
                meanOffsetMs: meanOffset
            )
        }
    }
}

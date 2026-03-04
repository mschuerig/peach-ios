import Foundation

enum TrainingDataImporter {

    enum ImportMode {
        case replace
        case merge
    }

    struct ImportSummary {
        let comparisonsImported: Int
        let pitchMatchingsImported: Int
        let comparisonsSkipped: Int
        let pitchMatchingsSkipped: Int
        let parseErrorCount: Int

        var totalImported: Int { comparisonsImported + pitchMatchingsImported }
        var totalSkipped: Int { comparisonsSkipped + pitchMatchingsSkipped }
    }

    static func importData(
        _ parseResult: CSVImportParser.ImportResult,
        mode: ImportMode,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        switch mode {
        case .replace:
            return try replaceAll(parseResult, into: store)
        case .merge:
            return try mergeRecords(parseResult, into: store)
        }
    }

    // MARK: - Replace Mode

    private static func replaceAll(
        _ parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        // Non-atomic: if a save fails after deleteAll, existing data is lost with partial import.
        // Acceptable for MVP — a future enhancement could wrap in a single transaction.
        try store.deleteAll()

        for record in parseResult.comparisons {
            try store.save(record)
        }
        for record in parseResult.pitchMatchings {
            try store.save(record)
        }

        return ImportSummary(
            comparisonsImported: parseResult.comparisons.count,
            pitchMatchingsImported: parseResult.pitchMatchings.count,
            comparisonsSkipped: 0,
            pitchMatchingsSkipped: 0,
            parseErrorCount: parseResult.errors.count
        )
    }

    // MARK: - Merge Mode

    private static func mergeRecords(
        _ parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        let existingComparisons = try store.fetchAllComparisons()
        let existingPitchMatchings = try store.fetchAllPitchMatchings()

        var existingKeys = Set<DuplicateKey>()
        for record in existingComparisons {
            existingKeys.insert(DuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.comparison
            ))
        }
        for record in existingPitchMatchings {
            existingKeys.insert(DuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchMatching
            ))
        }

        var comparisonsImported = 0
        var comparisonsSkipped = 0
        for record in parseResult.comparisons {
            let key = DuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.comparison
            )
            if existingKeys.contains(key) {
                comparisonsSkipped += 1
            } else {
                try store.save(record)
                existingKeys.insert(key)
                comparisonsImported += 1
            }
        }

        var pitchMatchingsImported = 0
        var pitchMatchingsSkipped = 0
        for record in parseResult.pitchMatchings {
            let key = DuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchMatching
            )
            if existingKeys.contains(key) {
                pitchMatchingsSkipped += 1
            } else {
                try store.save(record)
                existingKeys.insert(key)
                pitchMatchingsImported += 1
            }
        }

        return ImportSummary(
            comparisonsImported: comparisonsImported,
            pitchMatchingsImported: pitchMatchingsImported,
            comparisonsSkipped: comparisonsSkipped,
            pitchMatchingsSkipped: pitchMatchingsSkipped,
            parseErrorCount: parseResult.errors.count
        )
    }

    // MARK: - Duplicate Key

    private enum TrainingType {
        static let comparison = "comparison"
        static let pitchMatching = "pitchMatching"
    }

    private struct DuplicateKey: Hashable {
        let timestamp: Date
        let referenceNote: Int
        let targetNote: Int
        let trainingType: String
    }
}

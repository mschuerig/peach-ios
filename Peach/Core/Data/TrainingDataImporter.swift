import Foundation

enum TrainingDataImporter {

    enum ImportMode {
        case replace
        case merge
    }

    struct ImportSummary {
        let pitchDiscriminationsImported: Int
        let pitchMatchingsImported: Int
        let pitchDiscriminationsSkipped: Int
        let pitchMatchingsSkipped: Int
        let parseErrorCount: Int

        var totalImported: Int { pitchDiscriminationsImported + pitchMatchingsImported }
        var totalSkipped: Int { pitchDiscriminationsSkipped + pitchMatchingsSkipped }
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
        try store.replaceAllRecords(
            pitchDiscriminations: parseResult.pitchDiscriminations,
            pitchMatchings: parseResult.pitchMatchings
        )

        return ImportSummary(
            pitchDiscriminationsImported: parseResult.pitchDiscriminations.count,
            pitchMatchingsImported: parseResult.pitchMatchings.count,
            pitchDiscriminationsSkipped: 0,
            pitchMatchingsSkipped: 0,
            parseErrorCount: parseResult.errors.count
        )
    }

    // MARK: - Merge Mode

    private static func mergeRecords(
        _ parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        let existingComparisons = try store.fetchAllPitchDiscriminations()
        let existingPitchMatchings = try store.fetchAllPitchMatchings()

        var existingKeys = Set<DuplicateKey>()
        for record in existingComparisons {
            existingKeys.insert(DuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchDiscrimination
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

        var pitchDiscriminationsImported = 0
        var pitchDiscriminationsSkipped = 0
        for record in parseResult.pitchDiscriminations {
            let key = DuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchDiscrimination
            )
            if existingKeys.contains(key) {
                pitchDiscriminationsSkipped += 1
            } else {
                try store.save(record)
                existingKeys.insert(key)
                pitchDiscriminationsImported += 1
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
            pitchDiscriminationsImported: pitchDiscriminationsImported,
            pitchMatchingsImported: pitchMatchingsImported,
            pitchDiscriminationsSkipped: pitchDiscriminationsSkipped,
            pitchMatchingsSkipped: pitchMatchingsSkipped,
            parseErrorCount: parseResult.errors.count
        )
    }

    // MARK: - Duplicate Key

    private enum TrainingType {
        static let pitchDiscrimination = "pitchDiscrimination"
        static let pitchMatching = "pitchMatching"
    }

    private struct DuplicateKey: Hashable {
        let timestampSeconds: Int64
        let referenceNote: Int
        let targetNote: Int
        let trainingType: String

        init(timestamp: Date, referenceNote: Int, targetNote: Int, trainingType: String) {
            self.timestampSeconds = Int64(timestamp.timeIntervalSinceReferenceDate)
            self.referenceNote = referenceNote
            self.targetNote = targetNote
            self.trainingType = trainingType
        }
    }
}

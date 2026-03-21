import Foundation

enum TrainingDataImporter {

    enum ImportMode {
        case replace
        case merge
    }

    struct ImportSummary {
        let pitchDiscriminationsImported: Int
        let pitchMatchingsImported: Int
        let rhythmOffsetDetectionsImported: Int
        let rhythmMatchingsImported: Int
        let pitchDiscriminationsSkipped: Int
        let pitchMatchingsSkipped: Int
        let rhythmOffsetDetectionsSkipped: Int
        let rhythmMatchingsSkipped: Int
        let parseErrorCount: Int

        var totalImported: Int {
            pitchDiscriminationsImported + pitchMatchingsImported +
            rhythmOffsetDetectionsImported + rhythmMatchingsImported
        }

        var totalSkipped: Int {
            pitchDiscriminationsSkipped + pitchMatchingsSkipped +
            rhythmOffsetDetectionsSkipped + rhythmMatchingsSkipped
        }
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
            pitchMatchings: parseResult.pitchMatchings,
            rhythmOffsetDetections: parseResult.rhythmOffsetDetections,
            rhythmMatchings: parseResult.rhythmMatchings
        )

        return ImportSummary(
            pitchDiscriminationsImported: parseResult.pitchDiscriminations.count,
            pitchMatchingsImported: parseResult.pitchMatchings.count,
            rhythmOffsetDetectionsImported: parseResult.rhythmOffsetDetections.count,
            rhythmMatchingsImported: parseResult.rhythmMatchings.count,
            pitchDiscriminationsSkipped: 0,
            pitchMatchingsSkipped: 0,
            rhythmOffsetDetectionsSkipped: 0,
            rhythmMatchingsSkipped: 0,
            parseErrorCount: parseResult.errors.count
        )
    }

    // MARK: - Merge Mode

    private static func mergeRecords(
        _ parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> ImportSummary {
        // Build pitch duplicate keys
        let existingDiscriminations = try store.fetchAllPitchDiscriminations()
        let existingPitchMatchings = try store.fetchAllPitchMatchings()

        var existingPitchKeys = Set<PitchDuplicateKey>()
        for record in existingDiscriminations {
            existingPitchKeys.insert(PitchDuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchDiscrimination
            ))
        }
        for record in existingPitchMatchings {
            existingPitchKeys.insert(PitchDuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchMatching
            ))
        }

        // Merge pitch discriminations
        var pitchDiscriminationsImported = 0
        var pitchDiscriminationsSkipped = 0
        for record in parseResult.pitchDiscriminations {
            let key = PitchDuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchDiscrimination
            )
            if existingPitchKeys.contains(key) {
                pitchDiscriminationsSkipped += 1
            } else {
                try store.save(record)
                existingPitchKeys.insert(key)
                pitchDiscriminationsImported += 1
            }
        }

        // Merge pitch matchings
        var pitchMatchingsImported = 0
        var pitchMatchingsSkipped = 0
        for record in parseResult.pitchMatchings {
            let key = PitchDuplicateKey(
                timestamp: record.timestamp,
                referenceNote: record.referenceNote,
                targetNote: record.targetNote,
                trainingType: TrainingType.pitchMatching
            )
            if existingPitchKeys.contains(key) {
                pitchMatchingsSkipped += 1
            } else {
                try store.save(record)
                existingPitchKeys.insert(key)
                pitchMatchingsImported += 1
            }
        }

        // Build rhythm duplicate keys
        let existingRhythmOffsets = try store.fetchAllRhythmOffsetDetections()
        let existingRhythmMatchings = try store.fetchAllRhythmMatchings()

        var existingRhythmKeys = Set<RhythmDuplicateKey>()
        for record in existingRhythmOffsets {
            existingRhythmKeys.insert(RhythmDuplicateKey(
                timestamp: record.timestamp,
                tempoBPM: record.tempoBPM,
                trainingType: TrainingType.rhythmOffsetDetection
            ))
        }
        for record in existingRhythmMatchings {
            existingRhythmKeys.insert(RhythmDuplicateKey(
                timestamp: record.timestamp,
                tempoBPM: record.tempoBPM,
                trainingType: TrainingType.rhythmMatching
            ))
        }

        // Merge rhythm offset detections
        var rhythmOffsetDetectionsImported = 0
        var rhythmOffsetDetectionsSkipped = 0
        for record in parseResult.rhythmOffsetDetections {
            let key = RhythmDuplicateKey(
                timestamp: record.timestamp,
                tempoBPM: record.tempoBPM,
                trainingType: TrainingType.rhythmOffsetDetection
            )
            if existingRhythmKeys.contains(key) {
                rhythmOffsetDetectionsSkipped += 1
            } else {
                try store.save(record)
                existingRhythmKeys.insert(key)
                rhythmOffsetDetectionsImported += 1
            }
        }

        // Merge rhythm matchings
        var rhythmMatchingsImported = 0
        var rhythmMatchingsSkipped = 0
        for record in parseResult.rhythmMatchings {
            let key = RhythmDuplicateKey(
                timestamp: record.timestamp,
                tempoBPM: record.tempoBPM,
                trainingType: TrainingType.rhythmMatching
            )
            if existingRhythmKeys.contains(key) {
                rhythmMatchingsSkipped += 1
            } else {
                try store.save(record)
                existingRhythmKeys.insert(key)
                rhythmMatchingsImported += 1
            }
        }

        return ImportSummary(
            pitchDiscriminationsImported: pitchDiscriminationsImported,
            pitchMatchingsImported: pitchMatchingsImported,
            rhythmOffsetDetectionsImported: rhythmOffsetDetectionsImported,
            rhythmMatchingsImported: rhythmMatchingsImported,
            pitchDiscriminationsSkipped: pitchDiscriminationsSkipped,
            pitchMatchingsSkipped: pitchMatchingsSkipped,
            rhythmOffsetDetectionsSkipped: rhythmOffsetDetectionsSkipped,
            rhythmMatchingsSkipped: rhythmMatchingsSkipped,
            parseErrorCount: parseResult.errors.count
        )
    }

    // MARK: - Training Type Constants

    private enum TrainingType {
        static let pitchDiscrimination = "pitchDiscrimination"
        static let pitchMatching = "pitchMatching"
        static let rhythmOffsetDetection = "rhythmOffsetDetection"
        static let rhythmMatching = "rhythmMatching"
    }

    // MARK: - Pitch Duplicate Key

    private struct PitchDuplicateKey: Hashable {
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

    // MARK: - Rhythm Duplicate Key

    private struct RhythmDuplicateKey: Hashable {
        let timestampSeconds: Int64
        let tempoBPM: Int
        let trainingType: String

        init(timestamp: Date, tempoBPM: Int, trainingType: String) {
            self.timestampSeconds = Int64(timestamp.timeIntervalSinceReferenceDate)
            self.tempoBPM = tempoBPM
            self.trainingType = trainingType
        }
    }
}

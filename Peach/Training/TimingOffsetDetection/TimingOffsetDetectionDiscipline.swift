import Foundation
import SwiftData

struct TimingOffsetDetectionDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.timingOffsetDetection

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Compare Timing"),
        unitLabel: String(localized: "ms"),
        optimalBaseline: 15.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] {
        TempoRange.defaultRanges.flatMap { range in
            TimingDirection.allCases.map { direction in
                .rhythm(id, range, direction)
            }
        }
    }

    let recordType: any PersistentModel.Type = TimingOffsetDetectionRecord.self

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for record in try store.fetchAllTimingOffsetDetections() {
            let offset = TimingOffset(.milliseconds(record.offsetMs))
            guard let range = TempoRange.range(for: TempoBPM(record.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.offsetMs)),
                for: .rhythm(id, range, offset.direction),
                isCorrect: record.isCorrect
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "rhythmOffsetDetection"

    let csvColumns = ["isCorrect", "tempoBPM", "offsetMs"]

    func csvKeyValuePairs(for record: any PersistentModel) -> [(String, String)] {
        guard let r = record as? TimingOffsetDetectionRecord else {
            assertionFailure("Expected TimingOffsetDetectionRecord, got \(type(of: record))")
            return []
        }
        return [
            ("isCorrect", r.isCorrect ? "true" : "false"),
            ("tempoBPM", "\(r.tempoBPM)"),
            ("offsetMs", CSVParserHelpers.formatDouble(r.offsetMs)),
        ]
    }

    func parseCSVRow(fields: [String], columnIndex: [String: Int], rowNumber: Int) -> Result<any PersistentModel, CSVImportError> {
        guard let timestampIdx = columnIndex["timestamp"],
              let isCorrectIdx = columnIndex["isCorrect"],
              let tempoBPMIdx = columnIndex["tempoBPM"],
              let offsetMsIdx = columnIndex["offsetMs"] else {
            return .failure(.invalidRowData(row: rowNumber, column: "row", value: "", reason: "missing required columns"))
        }

        let timestampStr = fields[timestampIdx]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .failure(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let isCorrectStr = fields[isCorrectIdx]
        guard isCorrectStr == "true" || isCorrectStr == "false" else {
            return .failure(.invalidRowData(row: rowNumber, column: "isCorrect", value: isCorrectStr, reason: "must be 'true' or 'false'"))
        }

        let tempoBPMStr = fields[tempoBPMIdx]
        guard let tempoBPM = Int(tempoBPMStr), tempoBPM > 0 else {
            return .failure(.invalidRowData(row: rowNumber, column: "tempoBPM", value: tempoBPMStr, reason: "must be a positive integer"))
        }

        let offsetMsStr = fields[offsetMsIdx]
        guard let offsetMs = Double(offsetMsStr), offsetMs.isFinite else {
            return .failure(.invalidRowData(row: rowNumber, column: "offsetMs", value: offsetMsStr, reason: "not a valid number"))
        }

        let record = TimingOffsetDetectionRecord(
            tempoBPM: tempoBPM,
            offsetMs: offsetMs,
            isCorrect: isCorrectStr == "true",
            timestamp: timestamp
        )
        return .success(record)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, record: any PersistentModel)] {
        try store.fetchAllTimingOffsetDetections()
            .map { ($0.timestamp, $0 as any PersistentModel) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        parseResult.records[csvTrainingType] ?? []
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildRhythmDuplicateKeys(from: store, trainingType: csvTrainingType)
        var imported = 0, skipped = 0
        for record in parsedRecords(from: parseResult) {
            guard let r = record as? TimingOffsetDetectionRecord else { continue }
            let key = RhythmDuplicateKey(timestamp: r.timestamp, tempoBPM: r.tempoBPM, trainingType: csvTrainingType)
            if existingKeys.contains(key) {
                skipped += 1
            } else {
                scope.insert(r)
                existingKeys.insert(key)
                imported += 1
            }
        }
        return (imported, skipped)
    }
}

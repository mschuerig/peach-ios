import Foundation
import SwiftData

struct ContinuousRhythmMatchingDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.continuousRhythmMatching

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Fill the Gap"),
        unitLabel: String(localized: "ms"),
        optimalBaseline: 20.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] {
        TempoRange.defaultRanges.flatMap { range in
            RhythmDirection.allCases.map { direction in
                .rhythm(id, range, direction)
            }
        }
    }

    let recordType: any PersistentModel.Type = ContinuousRhythmMatchingRecord.self

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for record in try store.fetchAllContinuousRhythmMatchings() {
            let offset = RhythmOffset(.milliseconds(record.meanOffsetMs))
            guard let range = TempoRange.range(for: TempoBPM(record.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.meanOffsetMs)),
                for: .rhythm(id, range, offset.direction)
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "continuousRhythmMatching"

    let csvColumns = [
        "tempoBPM", "meanOffsetMs",
        "meanOffsetMsPosition0", "meanOffsetMsPosition1",
        "meanOffsetMsPosition2", "meanOffsetMsPosition3",
    ]

    func csvKeyValuePairs(for record: any PersistentModel) -> [(String, String)] {
        guard let r = record as? ContinuousRhythmMatchingRecord else {
            assertionFailure("Expected ContinuousRhythmMatchingRecord, got \(type(of: record))")
            return []
        }
        return [
            ("tempoBPM", "\(r.tempoBPM)"),
            ("meanOffsetMs", CSVParserHelpers.formatDouble(r.meanOffsetMs)),
            ("meanOffsetMsPosition0", CSVParserHelpers.formatOptionalDouble(r.meanOffsetMsPosition0)),
            ("meanOffsetMsPosition1", CSVParserHelpers.formatOptionalDouble(r.meanOffsetMsPosition1)),
            ("meanOffsetMsPosition2", CSVParserHelpers.formatOptionalDouble(r.meanOffsetMsPosition2)),
            ("meanOffsetMsPosition3", CSVParserHelpers.formatOptionalDouble(r.meanOffsetMsPosition3)),
        ]
    }

    func parseCSVRow(fields: [String], columnIndex: [String: Int], rowNumber: Int) -> Result<any PersistentModel, CSVImportError> {
        guard let timestampIdx = columnIndex["timestamp"],
              let tempoBPMIdx = columnIndex["tempoBPM"],
              let meanOffsetMsIdx = columnIndex["meanOffsetMs"] else {
            return .failure(.invalidRowData(row: rowNumber, column: "row", value: "", reason: "missing required columns"))
        }

        let timestampStr = fields[timestampIdx]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .failure(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let tempoBPMStr = fields[tempoBPMIdx]
        guard let tempoBPM = Int(tempoBPMStr), tempoBPM > 0 else {
            return .failure(.invalidRowData(row: rowNumber, column: "tempoBPM", value: tempoBPMStr, reason: "must be a positive integer"))
        }

        let meanOffsetMsStr = fields[meanOffsetMsIdx]
        guard let meanOffsetMs = Double(meanOffsetMsStr), meanOffsetMs.isFinite else {
            return .failure(.invalidRowData(row: rowNumber, column: "meanOffsetMs", value: meanOffsetMsStr, reason: "not a valid number"))
        }

        let positionColumns = ["meanOffsetMsPosition0", "meanOffsetMsPosition1", "meanOffsetMsPosition2", "meanOffsetMsPosition3"]
        var positionValues: [Double?] = []
        for columnName in positionColumns {
            guard let idx = columnIndex[columnName] else {
                positionValues.append(nil)
                continue
            }
            let str = fields[idx]
            if str.isEmpty {
                positionValues.append(nil)
            } else if let value = Double(str), value.isFinite {
                positionValues.append(value)
            } else {
                return .failure(.invalidRowData(row: rowNumber, column: columnName, value: str, reason: "not a valid number"))
            }
        }

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: tempoBPM,
            meanOffsetMs: meanOffsetMs,
            meanOffsetMsPosition0: positionValues[0],
            meanOffsetMsPosition1: positionValues[1],
            meanOffsetMsPosition2: positionValues[2],
            meanOffsetMsPosition3: positionValues[3],
            timestamp: timestamp
        )
        return .success(record)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, record: any PersistentModel)] {
        try store.fetchAllContinuousRhythmMatchings()
            .map { ($0.timestamp, $0 as any PersistentModel) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        parseResult.records["continuousRhythmMatching"] ?? []
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildRhythmDuplicateKeys(from: store, trainingType: "continuousRhythmMatching")
        var imported = 0, skipped = 0
        for record in parsedRecords(from: parseResult) {
            guard let r = record as? ContinuousRhythmMatchingRecord else { continue }
            let key = RhythmDuplicateKey(timestamp: r.timestamp, tempoBPM: r.tempoBPM, trainingType: "continuousRhythmMatching")
            if existingKeys.contains(key) {
                skipped += 1
            } else {
                try store.save(r)
                existingKeys.insert(key)
                imported += 1
            }
        }
        return (imported, skipped)
    }
}

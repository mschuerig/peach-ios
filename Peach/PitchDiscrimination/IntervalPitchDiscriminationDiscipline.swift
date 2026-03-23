import Foundation
import SwiftData

struct IntervalPitchDiscriminationDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.intervalPitchDiscrimination

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Hear & Compare – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 12.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    let recordType: any PersistentModel.Type = PitchDiscriminationRecord.self

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for record in try store.fetchAllPitchDiscriminations() where record.interval != 0 {
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.centOffset)),
                for: .pitch(id),
                isCorrect: record.isCorrect
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "pitchDiscrimination"

    let csvColumns = [
        "referenceNote", "referenceNoteName", "targetNote", "targetNoteName",
        "interval", "tuningSystem", "centOffset", "isCorrect",
    ]

    func csvKeyValuePairs(for record: any PersistentModel) -> [(String, String)] {
        guard let r = record as? PitchDiscriminationRecord else {
            assertionFailure("Expected PitchDiscriminationRecord, got \(type(of: record))")
            return []
        }
        return [
            ("referenceNote", "\(r.referenceNote)"),
            ("referenceNoteName", CSVParserHelpers.formatNoteName(r.referenceNote)),
            ("targetNote", "\(r.targetNote)"),
            ("targetNoteName", CSVParserHelpers.formatNoteName(r.targetNote)),
            ("interval", CSVParserHelpers.formatInterval(r.interval)),
            ("tuningSystem", r.tuningSystem),
            ("centOffset", CSVParserHelpers.formatDouble(r.centOffset)),
            ("isCorrect", r.isCorrect ? "true" : "false"),
        ]
    }

    func parseCSVRow(fields: [String], columnIndex: [String: Int], rowNumber: Int) -> Result<any PersistentModel, CSVImportError> {
        PitchDiscriminationCSVParser.parse(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, record: any PersistentModel)] {
        try store.fetchAllPitchDiscriminations()
            .filter { $0.interval != 0 }
            .map { ($0.timestamp, $0 as any PersistentModel) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        (parseResult.records["pitchDiscrimination"] ?? [])
            .compactMap { $0 as? PitchDiscriminationRecord }
            .filter { $0.interval != 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildPitchDuplicateKeys(from: store)
        var imported = 0, skipped = 0
        for record in parsedRecords(from: parseResult) {
            guard let r = record as? PitchDiscriminationRecord else { continue }
            let key = PitchDuplicateKey(record: r)
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

import Foundation
import SwiftData

struct UnisonPitchMatchingDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.unisonPitchMatching

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Match Pitch"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 5.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    let recordType: any PersistentModel.Type = PitchMatchingRecord.self

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for record in try store.fetchAllPitchMatchings() where record.interval == 0 {
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.userCentError)),
                for: .pitch(id)
            )
        }
    }

    // MARK: - CSV

    let csvTrainingType = "pitchMatching"

    let csvColumns = [
        "referenceNote", "referenceNoteName", "targetNote", "targetNoteName",
        "interval", "tuningSystem", "initialCentOffset", "userCentError",
    ]

    func csvKeyValuePairs(for record: any PersistentModel) -> [(String, String)] {
        guard let r = record as? PitchMatchingRecord else {
            assertionFailure("Expected PitchMatchingRecord, got \(type(of: record))")
            return []
        }
        return [
            ("referenceNote", "\(r.referenceNote)"),
            ("referenceNoteName", CSVParserHelpers.formatNoteName(r.referenceNote)),
            ("targetNote", "\(r.targetNote)"),
            ("targetNoteName", CSVParserHelpers.formatNoteName(r.targetNote)),
            ("interval", CSVParserHelpers.formatInterval(r.interval)),
            ("tuningSystem", r.tuningSystem),
            ("initialCentOffset", CSVParserHelpers.formatDouble(r.initialCentOffset)),
            ("userCentError", CSVParserHelpers.formatDouble(r.userCentError)),
        ]
    }

    func parseCSVRow(fields: [String], columnIndex: [String: Int], rowNumber: Int) -> Result<any PersistentModel, CSVImportError> {
        PitchMatchingCSVParser.parse(fields: fields, columnIndex: columnIndex, rowNumber: rowNumber)
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, record: any PersistentModel)] {
        try store.fetchAllPitchMatchings()
            .filter { $0.interval == 0 }
            .map { ($0.timestamp, $0 as any PersistentModel) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        (parseResult.records["pitchMatching"] ?? [])
            .compactMap { $0 as? PitchMatchingRecord }
            .filter { $0.interval == 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildPitchDuplicateKeys(from: store)
        var imported = 0, skipped = 0
        for record in parsedRecords(from: parseResult) {
            guard let r = record as? PitchMatchingRecord else { continue }
            let key = PitchDuplicateKey(record: r)
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

import Foundation
import SwiftData

struct IntervalPitchMatchingDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.intervalPitchMatching

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Tune & Match – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 8.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    let recordType: any PersistentModel.Type = PitchMatchingRecord.self

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for record in try store.fetchAllPitchMatchings() where record.interval != 0 {
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.userCentError)),
                for: .pitch(id)
            )
        }
    }

    func fetchAndFormatRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, row: String)] {
        try store.fetchAllPitchMatchings()
            .filter { $0.interval != 0 }
            .map { ($0.timestamp, CSVRecordFormatter.format($0)) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        parseResult.pitchMatchings.filter { $0.interval != 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildPitchDuplicateKeys(from: store)
        var imported = 0, skipped = 0
        for record in parseResult.pitchMatchings where record.interval != 0 {
            let key = PitchDuplicateKey(record: record)
            if existingKeys.contains(key) {
                skipped += 1
            } else {
                try store.save(record)
                existingKeys.insert(key)
                imported += 1
            }
        }
        return (imported, skipped)
    }
}

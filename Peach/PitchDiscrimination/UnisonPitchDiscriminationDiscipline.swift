import Foundation
import SwiftData

struct UnisonPitchDiscriminationDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.unisonPitchDiscrimination

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Hear & Compare – Single Notes"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 8.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }

    let recordType: any PersistentModel.Type = PitchDiscriminationRecord.self

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for record in try store.fetchAllPitchDiscriminations() where record.interval == 0 {
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.centOffset)),
                for: .pitch(id),
                isCorrect: record.isCorrect
            )
        }
    }

    func fetchAndFormatRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, row: String)] {
        try store.fetchAllPitchDiscriminations()
            .filter { $0.interval == 0 }
            .map { ($0.timestamp, CSVRecordFormatter.format($0)) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        parseResult.pitchDiscriminations.filter { $0.interval == 0 }
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildPitchDuplicateKeys(from: store)
        var imported = 0, skipped = 0
        for record in parseResult.pitchDiscriminations where record.interval == 0 {
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

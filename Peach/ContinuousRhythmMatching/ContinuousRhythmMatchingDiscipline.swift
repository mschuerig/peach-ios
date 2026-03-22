import Foundation
import SwiftData

struct ContinuousRhythmMatchingDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.continuousRhythmMatching

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Fill the Gap – Rhythm"),
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

    func fetchAndFormatRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, row: String)] {
        try store.fetchAllContinuousRhythmMatchings()
            .map { ($0.timestamp, CSVRecordFormatter.format($0)) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        parseResult.continuousRhythmMatchings
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildRhythmDuplicateKeys(from: store, trainingType: "continuousRhythmMatching")
        var imported = 0, skipped = 0
        for record in parseResult.continuousRhythmMatchings {
            let key = RhythmDuplicateKey(timestamp: record.timestamp, tempoBPM: record.tempoBPM, trainingType: "continuousRhythmMatching")
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

import Foundation
import SwiftData

struct RhythmOffsetDetectionDiscipline: TrainingDiscipline, Sendable {
    let id = TrainingDisciplineID.rhythmOffsetDetection

    let config = TrainingDisciplineConfig(
        displayName: String(localized: "Hear & Compare – Rhythm"),
        unitLabel: String(localized: "ms"),
        optimalBaseline: 15.0,
        statistics: .default
    )

    var statisticsKeys: [StatisticsKey] {
        TempoRange.defaultRanges.flatMap { range in
            RhythmDirection.allCases.map { direction in
                .rhythm(id, range, direction)
            }
        }
    }

    let recordType: any PersistentModel.Type = RhythmOffsetDetectionRecord.self

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
        for record in try store.fetchAllRhythmOffsetDetections() {
            let offset = RhythmOffset(.milliseconds(record.offsetMs))
            guard let range = TempoRange.range(for: TempoBPM(record.tempoBPM)) else { continue }
            builder.addPoint(
                MetricPoint(timestamp: record.timestamp, value: abs(record.offsetMs)),
                for: .rhythm(id, range, offset.direction),
                isCorrect: record.isCorrect
            )
        }
    }

    func fetchAndFormatRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, row: String)] {
        try store.fetchAllRhythmOffsetDetections()
            .map { ($0.timestamp, CSVRecordFormatter.format($0)) }
    }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] {
        parseResult.rhythmOffsetDetections
    }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        into store: TrainingDataStore
    ) throws -> (imported: Int, skipped: Int) {
        var existingKeys = try buildRhythmDuplicateKeys(from: store, trainingType: "rhythmOffsetDetection")
        var imported = 0, skipped = 0
        for record in parseResult.rhythmOffsetDetections {
            let key = RhythmDuplicateKey(timestamp: record.timestamp, tempoBPM: record.tempoBPM, trainingType: "rhythmOffsetDetection")
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

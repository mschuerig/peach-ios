import Foundation

enum TrainingDataExporter {

    static func export(from store: TrainingDataStore) throws -> String {
        let comparisons = try store.fetchAllComparisons()
        let pitchMatchings = try store.fetchAllPitchMatchings()

        var merged: [(timestamp: Date, row: String)] = []

        for record in comparisons {
            merged.append((record.timestamp, CSVRecordFormatter.format(record)))
        }

        for record in pitchMatchings {
            merged.append((record.timestamp, CSVRecordFormatter.format(record)))
        }

        guard !merged.isEmpty else {
            return CSVExportSchema.headerRow
        }

        merged.sort { $0.timestamp < $1.timestamp }

        let rows = merged.map(\.row)
        return CSVExportSchema.headerRow + "\n" + rows.joined(separator: "\n")
    }
}

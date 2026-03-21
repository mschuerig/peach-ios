import Foundation

enum TrainingDataExporter {

    static func export(from store: TrainingDataStore) throws -> String {
        let comparisons = try store.fetchAllPitchDiscriminations()
        let pitchMatchings = try store.fetchAllPitchMatchings()
        let rhythmOffsets = try store.fetchAllRhythmOffsetDetections()
        let rhythmMatchings = try store.fetchAllRhythmMatchings()

        var merged: [(timestamp: Date, row: String)] = []

        for record in comparisons {
            merged.append((record.timestamp, CSVRecordFormatter.format(record)))
        }

        for record in pitchMatchings {
            merged.append((record.timestamp, CSVRecordFormatter.format(record)))
        }

        for record in rhythmOffsets {
            merged.append((record.timestamp, CSVRecordFormatter.format(record)))
        }

        for record in rhythmMatchings {
            merged.append((record.timestamp, CSVRecordFormatter.format(record)))
        }

        guard !merged.isEmpty else {
            return CSVExportSchemaV2.metadataLine + "\n" + CSVExportSchemaV2.headerRow
        }

        merged.sort { $0.timestamp < $1.timestamp }

        let rows = merged.map(\.row)
        return CSVExportSchemaV2.metadataLine + "\n" + CSVExportSchemaV2.headerRow + "\n" + rows.joined(separator: "\n")
    }
}

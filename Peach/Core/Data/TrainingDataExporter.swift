import Foundation

enum TrainingDataExporter {

    static func export(from store: TrainingDataStore) throws -> String {
        var merged: [(timestamp: Date, row: String)] = []

        for discipline in TrainingDisciplineRegistry.shared.all {
            merged.append(contentsOf: try discipline.fetchAndFormatRecords(from: store))
        }

        guard !merged.isEmpty else {
            return CSVExportSchemaV2.metadataLine + "\n" + CSVExportSchemaV2.headerRow
        }

        merged.sort { $0.timestamp < $1.timestamp }

        let rows = merged.map(\.row)
        return CSVExportSchemaV2.metadataLine + "\n" + CSVExportSchemaV2.headerRow + "\n" + rows.joined(separator: "\n")
    }
}

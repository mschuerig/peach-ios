import Foundation

enum TrainingDataExporter {

    static func export(from store: TrainingDataStore) throws -> String {
        let columns = CSVExportSchema.allColumns
        let columnIndex = CSVExportSchema.columnIndex
        guard let trainingTypeIndex = columnIndex["trainingType"],
              let timestampIndex = columnIndex["timestamp"] else {
            preconditionFailure(
                "CSVExportSchema.allColumns is missing required common columns 'trainingType' and 'timestamp'"
            )
        }

        var merged: [(timestamp: Date, row: String)] = []

        for discipline in TrainingDisciplineRegistry.shared.all {
            for (timestamp, pairs) in try discipline.csvRows(from: store) {
                var fields = Array(repeating: "", count: columns.count)
                fields[trainingTypeIndex] = discipline.csvTrainingType
                fields[timestampIndex] = CSVParserHelpers.formatTimestamp(timestamp)
                for (key, value) in pairs {
                    guard let idx = columnIndex[key] else {
                        assertionFailure("Unknown CSV column key '\(key)' from \(discipline.csvTrainingType)")
                        continue
                    }
                    fields[idx] = value
                }
                let row = fields.map { CSVParserHelpers.escapeField($0) }.joined(separator: ",")
                merged.append((timestamp, row))
            }
        }

        guard !merged.isEmpty else {
            return CSVExportSchema.metadataLine + "\n" + CSVExportSchema.headerRow
        }

        merged.sort { $0.timestamp < $1.timestamp }

        let rows = merged.map(\.row)
        return CSVExportSchema.metadataLine + "\n" + CSVExportSchema.headerRow + "\n" + rows.joined(separator: "\n")
    }
}

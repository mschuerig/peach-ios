import Foundation
import SwiftData

enum TrainingDataExporter {

    static func export(from store: TrainingDataStore) throws -> String {
        let columns = CSVExportSchema.allColumns
        let columnIndex = CSVExportSchema.columnIndex

        var merged: [(timestamp: Date, row: String)] = []

        for discipline in TrainingDisciplineRegistry.shared.all {
            for (timestamp, record) in try discipline.fetchExportRecords(from: store) {
                let pairs = discipline.csvKeyValuePairs(for: record)
                var fields = Array(repeating: "", count: columns.count)
                fields[columnIndex["trainingType"]!] = discipline.csvTrainingType
                fields[columnIndex["timestamp"]!] = CSVParserHelpers.formatTimestamp(timestamp)
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

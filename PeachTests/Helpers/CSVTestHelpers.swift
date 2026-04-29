import Testing
import Foundation
@testable import Peach

/// Builds a `(fields, columnIndex)` pair for the active CSV export schema,
/// suitable for driving a discipline's `parseCSVRow(...)` in tests. Fills in
/// `trainingType`, formatted `timestamp`, and any provided column pairs;
/// other columns are left as empty strings.
func buildCSVFields(
    trainingType: String,
    timestamp: Date,
    pairs: [(String, String)]
) throws -> (fields: [String], columnIndex: [String: Int]) {
    let allColumns = CSVExportSchema.allColumns
    let columnIndex = CSVExportSchema.columnIndex

    var fields = Array(repeating: "", count: allColumns.count)
    let typeIdx = try #require(columnIndex["trainingType"])
    let tsIdx = try #require(columnIndex["timestamp"])
    fields[typeIdx] = trainingType
    fields[tsIdx] = CSVParserHelpers.formatTimestamp(timestamp)
    for (key, value) in pairs {
        if let idx = columnIndex[key] { fields[idx] = value }
    }
    return (fields, columnIndex)
}

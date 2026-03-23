enum CSVExportSchemaV2 {

    // MARK: - Format Version

    static let formatVersion = 3
    static let metadataPrefix = "# peach-export-format:"
    static let metadataLine = metadataPrefix + "\(formatVersion)"

    // MARK: - Common Columns

    static let commonColumns = ["trainingType", "timestamp"]

    // MARK: - Column Assembly (from Registry)

    static var allColumns: [String] {
        commonColumns + TrainingDisciplineRegistry.shared.csvDisciplineColumns
    }

    static var headerRow: String {
        allColumns.joined(separator: ",")
    }

    static var columnIndex: [String: Int] {
        Dictionary(uniqueKeysWithValues: allColumns.enumerated().map { ($1, $0) })
    }
}

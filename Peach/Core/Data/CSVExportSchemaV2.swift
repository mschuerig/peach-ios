nonisolated enum CSVExportSchemaV2 {

    // MARK: - Format Version

    static let formatVersion = 2
    static let metadataPrefix = CSVExportSchema.metadataPrefix
    static let metadataLine = metadataPrefix + "\(formatVersion)"

    // MARK: - Column Names (indices 12–14 are rhythm-specific)

    static let columnTempoBPM = "tempoBPM"
    static let columnOffsetMs = "offsetMs"
    static let columnUserOffsetMs = "userOffsetMs"

    // MARK: - Training Type

    enum TrainingType: Sendable {
        case pitchDiscrimination
        case pitchMatching
        case rhythmOffsetDetection
        case rhythmMatching

        var csvValue: String {
            switch self {
            case .pitchDiscrimination: "pitchDiscrimination"
            case .pitchMatching: "pitchMatching"
            case .rhythmOffsetDetection: "rhythmOffsetDetection"
            case .rhythmMatching: "rhythmMatching"
            }
        }
    }

    // MARK: - Header Row

    static let allColumns: [String] = CSVExportSchema.allColumns + [
        columnTempoBPM,
        columnOffsetMs,
        columnUserOffsetMs,
    ]

    static let headerRow: String = allColumns.joined(separator: ",")

    // MARK: - Column Groupings

    static let rhythmColumns: [String] = [
        columnTempoBPM,
        columnOffsetMs,
        columnUserOffsetMs,
    ]
}

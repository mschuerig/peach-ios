nonisolated enum CSVExportSchemaV2 {

    // MARK: - Format Version

    static let formatVersion = 2
    static let metadataPrefix = CSVExportSchema.metadataPrefix
    static let metadataLine = metadataPrefix + "\(formatVersion)"

    // MARK: - Column Names (indices 12–14 are rhythm-specific, 15 is continuous rhythm matching)

    static let columnTempoBPM = "tempoBPM"
    static let columnOffsetMs = "offsetMs"
    static let columnUserOffsetMs = "userOffsetMs"
    static let columnMeanOffsetMs = "meanOffsetMs"

    // MARK: - Training Type

    enum TrainingType: Sendable {
        case pitchDiscrimination
        case pitchMatching
        case rhythmOffsetDetection
        case rhythmMatching
        case continuousRhythmMatching

        var csvValue: String {
            switch self {
            case .pitchDiscrimination: "pitchDiscrimination"
            case .pitchMatching: "pitchMatching"
            case .rhythmOffsetDetection: "rhythmOffsetDetection"
            case .rhythmMatching: "rhythmMatching"
            case .continuousRhythmMatching: "continuousRhythmMatching"
            }
        }
    }

    // MARK: - Header Row

    static let allColumns: [String] = CSVExportSchema.allColumns + [
        columnTempoBPM,
        columnOffsetMs,
        columnUserOffsetMs,
        columnMeanOffsetMs,
    ]

    static let headerRow: String = allColumns.joined(separator: ",")

}

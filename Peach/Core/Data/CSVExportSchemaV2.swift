nonisolated enum CSVExportSchemaV2 {

    // MARK: - Format Version

    static let formatVersion = 2
    static let metadataPrefix = CSVExportSchema.metadataPrefix
    static let metadataLine = metadataPrefix + "\(formatVersion)"

    // MARK: - Column Names (indices 12–14 are rhythm-specific, 15–19 are continuous rhythm matching)

    static let columnTempoBPM = "tempoBPM"
    static let columnOffsetMs = "offsetMs"
    static let columnUserOffsetMs = "userOffsetMs"
    static let columnMeanOffsetMs = "meanOffsetMs"
    static let columnMeanOffsetMsPosition0 = "meanOffsetMsPosition0"
    static let columnMeanOffsetMsPosition1 = "meanOffsetMsPosition1"
    static let columnMeanOffsetMsPosition2 = "meanOffsetMsPosition2"
    static let columnMeanOffsetMsPosition3 = "meanOffsetMsPosition3"

    // MARK: - Training Type

    enum TrainingType: Sendable {
        case pitchDiscrimination
        case pitchMatching
        case rhythmOffsetDetection
        case continuousRhythmMatching

        var csvValue: String {
            switch self {
            case .pitchDiscrimination: "pitchDiscrimination"
            case .pitchMatching: "pitchMatching"
            case .rhythmOffsetDetection: "rhythmOffsetDetection"
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
        columnMeanOffsetMsPosition0,
        columnMeanOffsetMsPosition1,
        columnMeanOffsetMsPosition2,
        columnMeanOffsetMsPosition3,
    ]

    static let headerRow: String = allColumns.joined(separator: ",")

}

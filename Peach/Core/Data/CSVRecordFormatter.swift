import Foundation

nonisolated enum CSVRecordFormatter {

    // MARK: - PitchDiscriminationTrial Record Formatting

    static func format(_ record: PitchDiscriminationRecord) -> String {
        let fields: [String] = [
            CSVExportSchemaV2.TrainingType.pitchDiscrimination.csvValue,
            formatTimestamp(record.timestamp),
            "\(record.referenceNote)",
            formatNoteName(record.referenceNote),
            "\(record.targetNote)",
            formatNoteName(record.targetNote),
            formatInterval(record.interval),
            record.tuningSystem,
            formatDouble(record.centOffset),
            record.isCorrect ? "true" : "false",
            "", // initialCentOffset
            "", // userCentError
            "", // tempoBPM
            "", // offsetMs
            "", // userOffsetMs
            "", // meanOffsetMs
            "", // meanOffsetMsPosition0
            "", // meanOffsetMsPosition1
            "", // meanOffsetMsPosition2
            "", // meanOffsetMsPosition3
        ]
        return buildRow(fields)
    }

    // MARK: - PitchMatching Record Formatting

    static func format(_ record: PitchMatchingRecord) -> String {
        let fields: [String] = [
            CSVExportSchemaV2.TrainingType.pitchMatching.csvValue,
            formatTimestamp(record.timestamp),
            "\(record.referenceNote)",
            formatNoteName(record.referenceNote),
            "\(record.targetNote)",
            formatNoteName(record.targetNote),
            formatInterval(record.interval),
            record.tuningSystem,
            "", // centOffset
            "", // isCorrect
            formatDouble(record.initialCentOffset),
            formatDouble(record.userCentError),
            "", // tempoBPM
            "", // offsetMs
            "", // userOffsetMs
            "", // meanOffsetMs
            "", // meanOffsetMsPosition0
            "", // meanOffsetMsPosition1
            "", // meanOffsetMsPosition2
            "", // meanOffsetMsPosition3
        ]
        return buildRow(fields)
    }

    // MARK: - RhythmOffsetDetection Record Formatting

    static func format(_ record: RhythmOffsetDetectionRecord) -> String {
        let fields: [String] = [
            CSVExportSchemaV2.TrainingType.rhythmOffsetDetection.csvValue,
            formatTimestamp(record.timestamp),
            "", // referenceNote
            "", // referenceNoteName
            "", // targetNote
            "", // targetNoteName
            "", // interval
            "", // tuningSystem
            "", // centOffset
            record.isCorrect ? "true" : "false",
            "", // initialCentOffset
            "", // userCentError
            "\(record.tempoBPM)",
            formatDouble(record.offsetMs),
            "", // userOffsetMs
            "", // meanOffsetMs
            "", // meanOffsetMsPosition0
            "", // meanOffsetMsPosition1
            "", // meanOffsetMsPosition2
            "", // meanOffsetMsPosition3
        ]
        return buildRow(fields)
    }

    // MARK: - RhythmMatching Record Formatting

    static func format(_ record: RhythmMatchingRecord) -> String {
        let fields: [String] = [
            CSVExportSchemaV2.TrainingType.rhythmMatching.csvValue,
            formatTimestamp(record.timestamp),
            "", // referenceNote
            "", // referenceNoteName
            "", // targetNote
            "", // targetNoteName
            "", // interval
            "", // tuningSystem
            "", // centOffset
            "", // isCorrect
            "", // initialCentOffset
            "", // userCentError
            "\(record.tempoBPM)",
            "", // offsetMs
            formatDouble(record.userOffsetMs),
            "", // meanOffsetMs
            "", // meanOffsetMsPosition0
            "", // meanOffsetMsPosition1
            "", // meanOffsetMsPosition2
            "", // meanOffsetMsPosition3
        ]
        return buildRow(fields)
    }

    // MARK: - ContinuousRhythmMatching Record Formatting

    static func format(_ record: ContinuousRhythmMatchingRecord) -> String {
        let fields: [String] = [
            CSVExportSchemaV2.TrainingType.continuousRhythmMatching.csvValue,
            formatTimestamp(record.timestamp),
            "", // referenceNote
            "", // referenceNoteName
            "", // targetNote
            "", // targetNoteName
            "", // interval
            "", // tuningSystem
            "", // centOffset
            "", // isCorrect
            "", // initialCentOffset
            "", // userCentError
            "\(record.tempoBPM)",
            "", // offsetMs
            "", // userOffsetMs
            formatDouble(record.meanOffsetMs),
            formatOptionalDouble(record.meanOffsetMsPosition0),
            formatOptionalDouble(record.meanOffsetMsPosition1),
            formatOptionalDouble(record.meanOffsetMsPosition2),
            formatOptionalDouble(record.meanOffsetMsPosition3),
        ]
        return buildRow(fields)
    }

    // MARK: - Field Formatters

    private static func formatTimestamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    private static func formatNoteName(_ midiNote: Int) -> String {
        MIDINote(midiNote).name
    }

    private static func formatInterval(_ rawValue: Int) -> String {
        Interval(rawValue: rawValue)?.abbreviation ?? ""
    }

    private static func formatDouble(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let formatted = String(value)
        if formatted.contains(".") {
            return formatted
        }
        return formatted + ".0"
    }

    private static func formatOptionalDouble(_ value: Double?) -> String {
        guard let value else { return "" }
        return formatDouble(value)
    }

    // MARK: - Row Builder

    private static func buildRow(_ fields: [String]) -> String {
        assert(fields.count == CSVExportSchemaV2.allColumns.count,
               "Expected \(CSVExportSchemaV2.allColumns.count) fields, got \(fields.count)")
        return fields.map { escapeField($0) }.joined(separator: ",")
    }

    // MARK: - RFC 4180 Escaping

    private static func escapeField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

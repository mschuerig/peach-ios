import Foundation

nonisolated struct CSVImportParserV1: CSVVersionedParser {

    let supportedVersion = 1

    // MARK: - Interval Reverse Lookup (delegated to CSVParserHelpers)

    private static var abbreviationToRawValue: [String: Int] { CSVParserHelpers.abbreviationToRawValue }

    // MARK: - Parse

    func parse(lines: [String]) -> CSVImportParser.ImportResult {
        var pitchDiscriminations: [PitchDiscriminationRecord] = []
        var pitchMatchings: [PitchMatchingRecord] = []
        var errors: [CSVImportError] = []

        guard let headerLine = lines.first, !headerLine.isEmpty else {
            errors.append(.invalidHeader(expected: CSVExportSchema.headerRow, actual: "(empty)"))
            return CSVImportParser.ImportResult(pitchDiscriminations: pitchDiscriminations, pitchMatchings: pitchMatchings, rhythmOffsetDetections: [], rhythmMatchings: [], continuousRhythmMatchings: [], errors: errors)
        }

        if let headerError = validateHeader(headerLine) {
            errors.append(headerError)
            return CSVImportParser.ImportResult(pitchDiscriminations: pitchDiscriminations, pitchMatchings: pitchMatchings, rhythmOffsetDetections: [], rhythmMatchings: [], continuousRhythmMatchings: [], errors: errors)
        }

        let dataLines = lines.dropFirst()
        for (index, line) in dataLines.enumerated() {
            if line.isEmpty { continue }
            let rowNumber = index + 1
            switch parseRow(line, rowNumber: rowNumber) {
            case .pitchDiscrimination(let record):
                pitchDiscriminations.append(record)

            case .pitchMatching(let record):
                pitchMatchings.append(record)
            case .error(let error):
                errors.append(error)
            }
        }

        return CSVImportParser.ImportResult(pitchDiscriminations: pitchDiscriminations, pitchMatchings: pitchMatchings, rhythmOffsetDetections: [], rhythmMatchings: [], continuousRhythmMatchings: [], errors: errors)
    }

    // MARK: - Header Validation

    private func validateHeader(_ headerLine: String) -> CSVImportError? {
        let columns = Self.parseCSVLine(headerLine)
        let expected = CSVExportSchema.allColumns

        guard columns.count == expected.count else {
            return .invalidHeader(
                expected: "\(expected.count) columns",
                actual: "\(columns.count) columns"
            )
        }

        for (index, expectedColumn) in expected.enumerated() {
            if columns[index] != expectedColumn {
                return .invalidHeader(expected: expectedColumn, actual: columns[index])
            }
        }

        return nil
    }

    // MARK: - RFC 4180 CSV Line Parsing (delegated to CSVParserHelpers)

    private static func parseCSVLine(_ line: String) -> [String] {
        CSVParserHelpers.parseCSVLine(line)
    }

    // MARK: - Row Parsing

    private enum RowResult {
        case pitchDiscrimination(PitchDiscriminationRecord)
        case pitchMatching(PitchMatchingRecord)
        case error(CSVImportError)
    }

    /// Normalizes legacy training type values from older CSV exports.
    private static func normalizeTrainingType(_ value: String) -> String {
        switch value {
        case "pitchComparison": CSVExportSchema.TrainingType.pitchDiscrimination.csvValue
        default: value
        }
    }

    private func parseRow(_ line: String, rowNumber: Int) -> RowResult {
        let fields = Self.parseCSVLine(line)
        let expectedCount = CSVExportSchema.allColumns.count

        guard fields.count == expectedCount else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "row",
                value: "\(fields.count) fields",
                reason: "expected \(expectedCount) fields"
            ))
        }

        let trainingType = fields[0]
        let timestampStr = fields[1]
        let refNoteStr = fields[2]
        let targetNoteStr = fields[4]
        let intervalStr = fields[6]
        let tuningSystemStr = fields[7]
        let centOffsetStr = fields[8]
        let isCorrectStr = fields[9]
        let initialCentOffsetStr = fields[10]
        let userCentErrorStr = fields[11]

        guard let timestamp = Self.parseISO8601(timestampStr) else {
            return .error(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        guard let referenceNote = Int(refNoteStr), (0...127).contains(referenceNote) else {
            return .error(.invalidRowData(row: rowNumber, column: "referenceNote", value: refNoteStr, reason: "must be an integer 0-127"))
        }

        guard let targetNote = Int(targetNoteStr), (0...127).contains(targetNote) else {
            return .error(.invalidRowData(row: rowNumber, column: "targetNote", value: targetNoteStr, reason: "must be an integer 0-127"))
        }

        guard let intervalRaw = Self.abbreviationToRawValue[intervalStr] else {
            return .error(.invalidRowData(row: rowNumber, column: "interval", value: intervalStr, reason: "not a valid interval abbreviation"))
        }

        guard TuningSystem(identifier: tuningSystemStr) != nil else {
            return .error(.invalidRowData(row: rowNumber, column: "tuningSystem", value: tuningSystemStr, reason: "not a valid tuning system"))
        }

        let normalizedType = Self.normalizeTrainingType(trainingType)
        switch normalizedType {
        case CSVExportSchema.TrainingType.pitchDiscrimination.csvValue:
            guard initialCentOffsetStr.isEmpty && userCentErrorStr.isEmpty else {
                return .error(.invalidRowData(row: rowNumber, column: "initialCentOffset/userCentError", value: "\(initialCentOffsetStr),\(userCentErrorStr)", reason: "must be empty for pitchDiscrimination rows"))
            }

            guard let centOffset = Double(centOffsetStr) else {
                return .error(.invalidRowData(row: rowNumber, column: "centOffset", value: centOffsetStr, reason: "not a valid number"))
            }

            guard isCorrectStr == "true" || isCorrectStr == "false" else {
                return .error(.invalidRowData(row: rowNumber, column: "isCorrect", value: isCorrectStr, reason: "must be 'true' or 'false'"))
            }

            let isCorrect = isCorrectStr == "true"

            let record = PitchDiscriminationRecord(
                referenceNote: referenceNote,
                targetNote: targetNote,
                centOffset: centOffset,
                isCorrect: isCorrect,
                interval: intervalRaw,
                tuningSystem: tuningSystemStr,
                timestamp: timestamp
            )
            return .pitchDiscrimination(record)

        case CSVExportSchema.TrainingType.pitchMatching.csvValue:
            guard centOffsetStr.isEmpty && isCorrectStr.isEmpty else {
                return .error(.invalidRowData(row: rowNumber, column: "centOffset/isCorrect", value: "\(centOffsetStr),\(isCorrectStr)", reason: "must be empty for pitchMatching rows"))
            }

            guard let initialCentOffset = Double(initialCentOffsetStr) else {
                return .error(.invalidRowData(row: rowNumber, column: "initialCentOffset", value: initialCentOffsetStr, reason: "not a valid number"))
            }

            guard let userCentError = Double(userCentErrorStr) else {
                return .error(.invalidRowData(row: rowNumber, column: "userCentError", value: userCentErrorStr, reason: "not a valid number"))
            }

            let record = PitchMatchingRecord(
                referenceNote: referenceNote,
                targetNote: targetNote,
                initialCentOffset: initialCentOffset,
                userCentError: userCentError,
                interval: intervalRaw,
                tuningSystem: tuningSystemStr,
                timestamp: timestamp
            )
            return .pitchMatching(record)

        default:
            return .error(.invalidRowData(row: rowNumber, column: "trainingType", value: trainingType, reason: "must be 'pitchDiscrimination' or 'pitchMatching'"))
        }
    }

    // MARK: - ISO 8601 Parsing (delegated to CSVParserHelpers)

    private static func parseISO8601(_ string: String) -> Date? {
        CSVParserHelpers.parseISO8601(string)
    }
}

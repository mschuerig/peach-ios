import Foundation

nonisolated enum CSVImportParser {

    struct ImportResult {
        var comparisons: [ComparisonRecord]
        var pitchMatchings: [PitchMatchingRecord]
        var errors: [CSVImportError]
    }

    // MARK: - Interval Reverse Lookup

    private static let abbreviationToRawValue: [String: Int] = {
        var map: [String: Int] = [:]
        for interval in Interval.allCases {
            map[interval.abbreviation] = interval.rawValue
        }
        return map
    }()

    private static func intervalRawValue(from abbreviation: String) -> Int? {
        abbreviationToRawValue[abbreviation]
    }

    // MARK: - Top-Level Parse

    static func parse(_ csvContent: String) -> ImportResult {
        var comparisons: [ComparisonRecord] = []
        var pitchMatchings: [PitchMatchingRecord] = []
        var errors: [CSVImportError] = []

        let lines = splitIntoLines(csvContent)

        guard let headerLine = lines.first, !headerLine.isEmpty else {
            errors.append(.invalidHeader(expected: CSVExportSchema.headerRow, actual: "(empty)"))
            return ImportResult(comparisons: comparisons, pitchMatchings: pitchMatchings, errors: errors)
        }

        if let headerError = validateHeader(headerLine) {
            errors.append(headerError)
            return ImportResult(comparisons: comparisons, pitchMatchings: pitchMatchings, errors: errors)
        }

        let dataLines = lines.dropFirst()
        for (index, line) in dataLines.enumerated() {
            if line.isEmpty { continue }
            let rowNumber = index + 1
            switch parseRow(line, rowNumber: rowNumber) {
            case .comparison(let record):
                comparisons.append(record)
            case .pitchMatching(let record):
                pitchMatchings.append(record)
            case .error(let error):
                errors.append(error)
            }
        }

        return ImportResult(comparisons: comparisons, pitchMatchings: pitchMatchings, errors: errors)
    }

    // MARK: - Header Validation

    private static func validateHeader(_ headerLine: String) -> CSVImportError? {
        let columns = parseCSVLine(headerLine)
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

    // MARK: - RFC 4180 CSV Line Parsing

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                fields.append(current)
                                current = ""
                            } else {
                                current.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
        }

        fields.append(current)
        return fields
    }

    // MARK: - Line Splitting (Handles Quoted Newlines)

    private static func splitIntoLines(_ content: String) -> [String] {
        var lines: [String] = []
        var current = ""
        var inQuotes = false
        var previousWasCR = false

        for scalar in content.unicodeScalars {
            if previousWasCR && scalar == "\n" && !inQuotes {
                previousWasCR = false
                continue
            }
            previousWasCR = false

            if scalar == "\"" {
                inQuotes.toggle()
                current.unicodeScalars.append(scalar)
            } else if scalar == "\r" && !inQuotes {
                lines.append(current)
                current = ""
                previousWasCR = true
            } else if scalar == "\n" && !inQuotes {
                lines.append(current)
                current = ""
            } else {
                current.unicodeScalars.append(scalar)
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }

        return lines
    }

    // MARK: - Row Parsing

    private enum RowResult {
        case comparison(ComparisonRecord)
        case pitchMatching(PitchMatchingRecord)
        case error(CSVImportError)
    }

    private static func parseRow(_ line: String, rowNumber: Int) -> RowResult {
        let fields = parseCSVLine(line)
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
        // fields[3] = referenceNoteName (display-only, ignored)
        let targetNoteStr = fields[4]
        // fields[5] = targetNoteName (display-only, ignored)
        let intervalStr = fields[6]
        let tuningSystemStr = fields[7]
        let centOffsetStr = fields[8]
        let isCorrectStr = fields[9]
        let initialCentOffsetStr = fields[10]
        let userCentErrorStr = fields[11]

        // Parse timestamp
        guard let timestamp = parseISO8601(timestampStr) else {
            return .error(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        // Parse MIDI notes
        guard let referenceNote = Int(refNoteStr), (0...127).contains(referenceNote) else {
            return .error(.invalidRowData(row: rowNumber, column: "referenceNote", value: refNoteStr, reason: "must be an integer 0-127"))
        }

        guard let targetNote = Int(targetNoteStr), (0...127).contains(targetNote) else {
            return .error(.invalidRowData(row: rowNumber, column: "targetNote", value: targetNoteStr, reason: "must be an integer 0-127"))
        }

        // Parse interval
        guard let intervalRaw = intervalRawValue(from: intervalStr) else {
            return .error(.invalidRowData(row: rowNumber, column: "interval", value: intervalStr, reason: "not a valid interval abbreviation"))
        }

        // Parse tuning system
        guard TuningSystem(identifier: tuningSystemStr) != nil else {
            return .error(.invalidRowData(row: rowNumber, column: "tuningSystem", value: tuningSystemStr, reason: "not a valid tuning system"))
        }

        // Dispatch by training type
        switch trainingType {
        case CSVExportSchema.TrainingType.comparison.csvValue:
            // Validate type-specific empty fields
            guard initialCentOffsetStr.isEmpty && userCentErrorStr.isEmpty else {
                return .error(.invalidRowData(row: rowNumber, column: "initialCentOffset/userCentError", value: "\(initialCentOffsetStr),\(userCentErrorStr)", reason: "must be empty for comparison rows"))
            }

            guard let centOffset = Double(centOffsetStr) else {
                return .error(.invalidRowData(row: rowNumber, column: "centOffset", value: centOffsetStr, reason: "not a valid number"))
            }

            guard isCorrectStr == "true" || isCorrectStr == "false" else {
                return .error(.invalidRowData(row: rowNumber, column: "isCorrect", value: isCorrectStr, reason: "must be 'true' or 'false'"))
            }

            let isCorrect = isCorrectStr == "true"

            let record = ComparisonRecord(
                referenceNote: referenceNote,
                targetNote: targetNote,
                centOffset: centOffset,
                isCorrect: isCorrect,
                interval: intervalRaw,
                tuningSystem: tuningSystemStr,
                timestamp: timestamp
            )
            return .comparison(record)

        case CSVExportSchema.TrainingType.pitchMatching.csvValue:
            // Validate type-specific empty fields
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
            return .error(.invalidRowData(row: rowNumber, column: "trainingType", value: trainingType, reason: "must be 'comparison' or 'pitchMatching'"))
        }
    }

    // MARK: - ISO 8601 Parsing

    private static func parseISO8601(_ string: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(string) {
            return date
        }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string)
    }
}

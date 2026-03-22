import Foundation

nonisolated struct CSVImportParserV2: CSVVersionedParser {

    let supportedVersion = 2

    // MARK: - Parse

    func parse(lines: [String]) -> CSVImportParser.ImportResult {
        var pitchDiscriminations: [PitchDiscriminationRecord] = []
        var pitchMatchings: [PitchMatchingRecord] = []
        var rhythmOffsetDetections: [RhythmOffsetDetectionRecord] = []
        var rhythmMatchings: [RhythmMatchingRecord] = []
        var continuousRhythmMatchings: [ContinuousRhythmMatchingRecord] = []
        var errors: [CSVImportError] = []

        guard let headerLine = lines.first, !headerLine.isEmpty else {
            errors.append(.invalidHeader(expected: CSVExportSchemaV2.headerRow, actual: "(empty)"))
            return CSVImportParser.ImportResult(pitchDiscriminations: [], pitchMatchings: [], rhythmOffsetDetections: [], rhythmMatchings: [], continuousRhythmMatchings: [], errors: errors)
        }

        if let headerError = validateHeader(headerLine) {
            errors.append(headerError)
            return CSVImportParser.ImportResult(pitchDiscriminations: [], pitchMatchings: [], rhythmOffsetDetections: [], rhythmMatchings: [], continuousRhythmMatchings: [], errors: errors)
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
            case .rhythmOffsetDetection(let record):
                rhythmOffsetDetections.append(record)
            case .rhythmMatching(let record):
                rhythmMatchings.append(record)
            case .continuousRhythmMatching(let record):
                continuousRhythmMatchings.append(record)
            case .error(let error):
                errors.append(error)
            }
        }

        return CSVImportParser.ImportResult(
            pitchDiscriminations: pitchDiscriminations,
            pitchMatchings: pitchMatchings,
            rhythmOffsetDetections: rhythmOffsetDetections,
            rhythmMatchings: rhythmMatchings,
            continuousRhythmMatchings: continuousRhythmMatchings,
            errors: errors
        )
    }

    // MARK: - Header Validation

    private func validateHeader(_ headerLine: String) -> CSVImportError? {
        let columns = CSVParserHelpers.parseCSVLine(headerLine)
        let expected = CSVExportSchemaV2.allColumns

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

    // MARK: - Row Parsing

    private enum RowResult {
        case pitchDiscrimination(PitchDiscriminationRecord)
        case pitchMatching(PitchMatchingRecord)
        case rhythmOffsetDetection(RhythmOffsetDetectionRecord)
        case rhythmMatching(RhythmMatchingRecord)
        case continuousRhythmMatching(ContinuousRhythmMatchingRecord)
        case error(CSVImportError)
    }

    private func parseRow(_ line: String, rowNumber: Int) -> RowResult {
        let fields = CSVParserHelpers.parseCSVLine(line)
        let expectedCount = CSVExportSchemaV2.allColumns.count

        guard fields.count == expectedCount else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "row",
                value: "\(fields.count) fields",
                reason: "expected \(expectedCount) fields"
            ))
        }

        let trainingType = fields[0]

        switch trainingType {
        case CSVExportSchemaV2.TrainingType.pitchDiscrimination.csvValue:
            return parsePitchDiscriminationRow(fields, rowNumber: rowNumber)
        case CSVExportSchemaV2.TrainingType.pitchMatching.csvValue:
            return parsePitchMatchingRow(fields, rowNumber: rowNumber)
        case CSVExportSchemaV2.TrainingType.rhythmOffsetDetection.csvValue:
            return parseRhythmOffsetDetectionRow(fields, rowNumber: rowNumber)
        case CSVExportSchemaV2.TrainingType.rhythmMatching.csvValue:
            return parseRhythmMatchingRow(fields, rowNumber: rowNumber)
        case CSVExportSchemaV2.TrainingType.continuousRhythmMatching.csvValue:
            return parseContinuousRhythmMatchingRow(fields, rowNumber: rowNumber)
        default:
            return .error(.invalidRowData(
                row: rowNumber,
                column: "trainingType",
                value: trainingType,
                reason: "must be 'pitchDiscrimination', 'pitchMatching', 'rhythmOffsetDetection', 'rhythmMatching', or 'continuousRhythmMatching'"
            ))
        }
    }

    // MARK: - Pitch Discrimination Row

    private func parsePitchDiscriminationRow(_ fields: [String], rowNumber: Int) -> RowResult {
        // Validate rhythm columns are empty
        let tempoBPMStr = fields[12]
        let offsetMsStr = fields[13]
        let userOffsetMsStr = fields[14]
        guard tempoBPMStr.isEmpty && offsetMsStr.isEmpty && userOffsetMsStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "tempoBPM/offsetMs/userOffsetMs",
                value: "\(tempoBPMStr),\(offsetMsStr),\(userOffsetMsStr)",
                reason: "must be empty for pitchDiscrimination rows"
            ))
        }

        // Validate pitch-matching-only columns are empty
        let initialCentOffsetStr = fields[10]
        let userCentErrorStr = fields[11]
        guard initialCentOffsetStr.isEmpty && userCentErrorStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "initialCentOffset/userCentError",
                value: "\(initialCentOffsetStr),\(userCentErrorStr)",
                reason: "must be empty for pitchDiscrimination rows"
            ))
        }

        // Validate continuous rhythm matching columns are empty
        if let error = validateContinuousColumnsEmpty(fields, rowNumber: rowNumber, trainingType: "pitchDiscrimination") {
            return error
        }

        return parsePitchCommonFields(fields, rowNumber: rowNumber) { timestamp, referenceNote, targetNote, intervalRaw, tuningSystemStr in
            let centOffsetStr = fields[8]
            let isCorrectStr = fields[9]

            guard let centOffset = Double(centOffsetStr), centOffset.isFinite else {
                return .error(.invalidRowData(row: rowNumber, column: "centOffset", value: centOffsetStr, reason: "not a valid number"))
            }

            guard isCorrectStr == "true" || isCorrectStr == "false" else {
                return .error(.invalidRowData(row: rowNumber, column: "isCorrect", value: isCorrectStr, reason: "must be 'true' or 'false'"))
            }

            let record = PitchDiscriminationRecord(
                referenceNote: referenceNote,
                targetNote: targetNote,
                centOffset: centOffset,
                isCorrect: isCorrectStr == "true",
                interval: intervalRaw,
                tuningSystem: tuningSystemStr,
                timestamp: timestamp
            )
            return .pitchDiscrimination(record)
        }
    }

    // MARK: - Pitch Matching Row

    private func parsePitchMatchingRow(_ fields: [String], rowNumber: Int) -> RowResult {
        // Validate rhythm columns are empty
        let tempoBPMStr = fields[12]
        let offsetMsStr = fields[13]
        let userOffsetMsStr = fields[14]
        guard tempoBPMStr.isEmpty && offsetMsStr.isEmpty && userOffsetMsStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "tempoBPM/offsetMs/userOffsetMs",
                value: "\(tempoBPMStr),\(offsetMsStr),\(userOffsetMsStr)",
                reason: "must be empty for pitchMatching rows"
            ))
        }

        // Validate pitch-discrimination-only columns are empty
        let centOffsetStr = fields[8]
        let isCorrectStr = fields[9]
        guard centOffsetStr.isEmpty && isCorrectStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "centOffset/isCorrect",
                value: "\(centOffsetStr),\(isCorrectStr)",
                reason: "must be empty for pitchMatching rows"
            ))
        }

        // Validate continuous rhythm matching columns are empty
        if let error = validateContinuousColumnsEmpty(fields, rowNumber: rowNumber, trainingType: "pitchMatching") {
            return error
        }

        return parsePitchCommonFields(fields, rowNumber: rowNumber) { timestamp, referenceNote, targetNote, intervalRaw, tuningSystemStr in
            let initialCentOffsetStr = fields[10]
            let userCentErrorStr = fields[11]

            guard let initialCentOffset = Double(initialCentOffsetStr), initialCentOffset.isFinite else {
                return .error(.invalidRowData(row: rowNumber, column: "initialCentOffset", value: initialCentOffsetStr, reason: "not a valid number"))
            }

            guard let userCentError = Double(userCentErrorStr), userCentError.isFinite else {
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
        }
    }

    // MARK: - Rhythm Offset Detection Row

    private func parseRhythmOffsetDetectionRow(_ fields: [String], rowNumber: Int) -> RowResult {
        // Validate pitch-specific columns are empty
        if let error = validatePitchColumnsEmpty(fields, rowNumber: rowNumber, trainingType: "rhythmOffsetDetection") {
            return error
        }

        // Validate pitch-discrimination/matching-only columns are empty
        let centOffsetStr = fields[8]
        let initialCentOffsetStr = fields[10]
        let userCentErrorStr = fields[11]
        guard centOffsetStr.isEmpty && initialCentOffsetStr.isEmpty && userCentErrorStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "centOffset/initialCentOffset/userCentError",
                value: "\(centOffsetStr),\(initialCentOffsetStr),\(userCentErrorStr)",
                reason: "must be empty for rhythmOffsetDetection rows"
            ))
        }

        // Validate userOffsetMs is empty
        let userOffsetMsStr = fields[14]
        guard userOffsetMsStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "userOffsetMs",
                value: userOffsetMsStr,
                reason: "must be empty for rhythmOffsetDetection rows"
            ))
        }

        // Validate continuous rhythm matching columns are empty
        if let error = validateContinuousColumnsEmpty(fields, rowNumber: rowNumber, trainingType: "rhythmOffsetDetection") {
            return error
        }

        let timestampStr = fields[1]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .error(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let isCorrectStr = fields[9]
        guard isCorrectStr == "true" || isCorrectStr == "false" else {
            return .error(.invalidRowData(row: rowNumber, column: "isCorrect", value: isCorrectStr, reason: "must be 'true' or 'false'"))
        }

        let tempoBPMStr = fields[12]
        guard let tempoBPM = Int(tempoBPMStr), tempoBPM > 0 else {
            return .error(.invalidRowData(row: rowNumber, column: "tempoBPM", value: tempoBPMStr, reason: "must be a positive integer"))
        }

        let offsetMsStr = fields[13]
        guard let offsetMs = Double(offsetMsStr), offsetMs.isFinite else {
            return .error(.invalidRowData(row: rowNumber, column: "offsetMs", value: offsetMsStr, reason: "not a valid number"))
        }

        let record = RhythmOffsetDetectionRecord(
            tempoBPM: tempoBPM,
            offsetMs: offsetMs,
            isCorrect: isCorrectStr == "true",
            timestamp: timestamp
        )
        return .rhythmOffsetDetection(record)
    }

    // MARK: - Rhythm Matching Row

    private func parseRhythmMatchingRow(_ fields: [String], rowNumber: Int) -> RowResult {
        // Validate pitch-specific columns are empty
        if let error = validatePitchColumnsEmpty(fields, rowNumber: rowNumber, trainingType: "rhythmMatching") {
            return error
        }

        // Validate pitch-only columns are empty
        let centOffsetStr = fields[8]
        let isCorrectStr = fields[9]
        let initialCentOffsetStr = fields[10]
        let userCentErrorStr = fields[11]
        guard centOffsetStr.isEmpty && isCorrectStr.isEmpty && initialCentOffsetStr.isEmpty && userCentErrorStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "centOffset/isCorrect/initialCentOffset/userCentError",
                value: "\(centOffsetStr),\(isCorrectStr),\(initialCentOffsetStr),\(userCentErrorStr)",
                reason: "must be empty for rhythmMatching rows"
            ))
        }

        // Validate offsetMs is empty
        let offsetMsStr = fields[13]
        guard offsetMsStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "offsetMs",
                value: offsetMsStr,
                reason: "must be empty for rhythmMatching rows"
            ))
        }

        // Validate continuous rhythm matching columns are empty
        if let error = validateContinuousColumnsEmpty(fields, rowNumber: rowNumber, trainingType: "rhythmMatching") {
            return error
        }

        let timestampStr = fields[1]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .error(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let tempoBPMStr = fields[12]
        guard let tempoBPM = Int(tempoBPMStr), tempoBPM > 0 else {
            return .error(.invalidRowData(row: rowNumber, column: "tempoBPM", value: tempoBPMStr, reason: "must be a positive integer"))
        }

        let userOffsetMsStr = fields[14]
        guard let userOffsetMs = Double(userOffsetMsStr), userOffsetMs.isFinite else {
            return .error(.invalidRowData(row: rowNumber, column: "userOffsetMs", value: userOffsetMsStr, reason: "not a valid number"))
        }

        let record = RhythmMatchingRecord(
            tempoBPM: tempoBPM,
            userOffsetMs: userOffsetMs,
            timestamp: timestamp
        )
        return .rhythmMatching(record)
    }

    // MARK: - Continuous Rhythm Matching Row

    private func parseContinuousRhythmMatchingRow(_ fields: [String], rowNumber: Int) -> RowResult {
        // Validate pitch-specific columns are empty
        if let error = validatePitchColumnsEmpty(fields, rowNumber: rowNumber, trainingType: "continuousRhythmMatching") {
            return error
        }

        // Validate pitch-only and discrete rhythm columns are empty
        let centOffsetStr = fields[8]
        let isCorrectStr = fields[9]
        let initialCentOffsetStr = fields[10]
        let userCentErrorStr = fields[11]
        let offsetMsStr = fields[13]
        let userOffsetMsStr = fields[14]
        guard centOffsetStr.isEmpty && isCorrectStr.isEmpty &&
              initialCentOffsetStr.isEmpty && userCentErrorStr.isEmpty &&
              offsetMsStr.isEmpty && userOffsetMsStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "centOffset/isCorrect/initialCentOffset/userCentError/offsetMs/userOffsetMs",
                value: "\(centOffsetStr),\(isCorrectStr),\(initialCentOffsetStr),\(userCentErrorStr),\(offsetMsStr),\(userOffsetMsStr)",
                reason: "must be empty for continuousRhythmMatching rows"
            ))
        }

        let timestampStr = fields[1]
        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .error(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        let tempoBPMStr = fields[12]
        guard let tempoBPM = Int(tempoBPMStr), tempoBPM > 0 else {
            return .error(.invalidRowData(row: rowNumber, column: "tempoBPM", value: tempoBPMStr, reason: "must be a positive integer"))
        }

        let meanOffsetMsStr = fields[15]
        guard let meanOffsetMs = Double(meanOffsetMsStr), meanOffsetMs.isFinite else {
            return .error(.invalidRowData(row: rowNumber, column: "meanOffsetMs", value: meanOffsetMsStr, reason: "not a valid number"))
        }

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: tempoBPM,
            meanOffsetMs: meanOffsetMs,
            gapPositionBreakdownJSON: Data(),
            timestamp: timestamp
        )
        return .continuousRhythmMatching(record)
    }

    // MARK: - Shared Pitch Field Parsing

    private func parsePitchCommonFields(
        _ fields: [String],
        rowNumber: Int,
        then buildRecord: (Date, Int, Int, Int, String) -> RowResult
    ) -> RowResult {
        let timestampStr = fields[1]
        let refNoteStr = fields[2]
        let targetNoteStr = fields[4]
        let intervalStr = fields[6]
        let tuningSystemStr = fields[7]

        guard let timestamp = CSVParserHelpers.parseISO8601(timestampStr) else {
            return .error(.invalidRowData(row: rowNumber, column: "timestamp", value: timestampStr, reason: "not a valid ISO 8601 date"))
        }

        guard let referenceNote = Int(refNoteStr), (0...127).contains(referenceNote) else {
            return .error(.invalidRowData(row: rowNumber, column: "referenceNote", value: refNoteStr, reason: "must be an integer 0-127"))
        }

        guard let targetNote = Int(targetNoteStr), (0...127).contains(targetNote) else {
            return .error(.invalidRowData(row: rowNumber, column: "targetNote", value: targetNoteStr, reason: "must be an integer 0-127"))
        }

        guard let intervalRaw = CSVParserHelpers.abbreviationToRawValue[intervalStr] else {
            return .error(.invalidRowData(row: rowNumber, column: "interval", value: intervalStr, reason: "not a valid interval abbreviation"))
        }

        guard TuningSystem(identifier: tuningSystemStr) != nil else {
            return .error(.invalidRowData(row: rowNumber, column: "tuningSystem", value: tuningSystemStr, reason: "not a valid tuning system"))
        }

        return buildRecord(timestamp, referenceNote, targetNote, intervalRaw, tuningSystemStr)
    }

    // MARK: - Validation Helpers

    private func validatePitchColumnsEmpty(_ fields: [String], rowNumber: Int, trainingType: String) -> RowResult? {
        let refNoteStr = fields[2]
        let refNoteNameStr = fields[3]
        let targetNoteStr = fields[4]
        let targetNoteNameStr = fields[5]
        let intervalStr = fields[6]
        let tuningSystemStr = fields[7]

        guard refNoteStr.isEmpty && refNoteNameStr.isEmpty &&
              targetNoteStr.isEmpty && targetNoteNameStr.isEmpty &&
              intervalStr.isEmpty && tuningSystemStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "referenceNote/referenceNoteName/targetNote/targetNoteName/interval/tuningSystem",
                value: "\(refNoteStr),\(refNoteNameStr),\(targetNoteStr),\(targetNoteNameStr),\(intervalStr),\(tuningSystemStr)",
                reason: "must be empty for \(trainingType) rows"
            ))
        }

        return nil
    }

    private func validateContinuousColumnsEmpty(_ fields: [String], rowNumber: Int, trainingType: String) -> RowResult? {
        let meanOffsetMsStr = fields[15]

        guard meanOffsetMsStr.isEmpty else {
            return .error(.invalidRowData(
                row: rowNumber,
                column: "meanOffsetMs",
                value: meanOffsetMsStr,
                reason: "must be empty for \(trainingType) rows"
            ))
        }

        return nil
    }
}

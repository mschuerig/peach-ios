import Testing
import Foundation
@testable import Peach

@Suite("CSVImportParser")
struct CSVImportParserTests {

    // MARK: - Test Helpers

    private func makeCSV(_ rows: [String]) -> String {
        // Test rows use the V3 19-column layout. When the active schema has fewer
        // columns (a non-Research build drops the Continuous Rhythm Matching
        // columns), trim each row's trailing fields so it matches the dynamic
        // header column count.
        let schemaColumnCount = CSVExportSchema.allColumns.count
        let alignedRows = rows.map { row -> String in
            let fields = CSVParserHelpers.parseCSVLine(row)
            let trimmed = Array(fields.prefix(schemaColumnCount))
            return trimmed.map { CSVParserHelpers.escapeField($0) }.joined(separator: ",")
        }
        return ([CSVExportSchema.metadataLine, CSVExportSchema.headerRow] + alignedRows).joined(separator: "\n")
    }

    private func fixedDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 3, hour: 14, minute: 30, second: 0)
        return calendar.date(from: components)!
    }

    /// 19-column pitch discrimination row (V3 format).
    private var validPitchDiscriminationRow: String {
        "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
    }

    /// 19-column pitch matching row (V3 format).
    private var validPitchMatchingRow: String {
        "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2,,,,,,,"
    }

    /// 19-column rhythm offset detection row (V3 format).
    private var validTimingOffsetDetectionRow: String {
        "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,,,,,"
    }

    private func pitchDiscriminations(from result: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: PitchDiscriminationPayload)] {
        TrainingDisciplinePayloads.typedEntries(
            from: result, forTrainingType: "pitchDiscrimination", ofType: PitchDiscriminationPayload.self)
    }

    private func pitchMatchings(from result: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: PitchMatchingPayload)] {
        TrainingDisciplinePayloads.typedEntries(
            from: result, forTrainingType: "pitchMatching", ofType: PitchMatchingPayload.self)
    }

    private func rhythmOffsetDetections(from result: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: TimingOffsetDetectionPayload)] {
        TrainingDisciplinePayloads.typedEntries(
            from: result, forTrainingType: "rhythmOffsetDetection", ofType: TimingOffsetDetectionPayload.self)
    }

    private func continuousRhythmMatchings(from result: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: ContinuousRhythmMatchingPayload)] {
        TrainingDisciplinePayloads.typedEntries(
            from: result, forTrainingType: "continuousRhythmMatching", ofType: ContinuousRhythmMatchingPayload.self)
    }

    // MARK: - CSVImportError

    @Test("invalidHeader error contains expected and actual column info")
    func invalidHeaderErrorDescription() async {
        let error = CSVImportError.invalidHeader(expected: "trainingType", actual: "wrongColumn")
        let description = error.localizedDescription
        #expect(description.contains("trainingType"))
        #expect(description.contains("wrongColumn"))
    }

    @Test("invalidRowData error contains row number, column, value, and reason")
    func invalidRowDataErrorDescription() async {
        let error = CSVImportError.invalidRowData(row: 5, column: "referenceNote", value: "abc", reason: "not a valid integer")
        let description = error.localizedDescription
        #expect(description.contains("5"))
        #expect(description.contains("referenceNote"))
        #expect(description.contains("abc"))
        #expect(description.contains("not a valid integer"))
    }

    // MARK: - Version Error Cases

    @Test("missingVersion error provides a description")
    func missingVersionErrorDescription() async throws {
        let error = CSVImportError.missingVersion
        let desc = try #require(error.errorDescription)
        #expect(desc.isEmpty == false)
    }

    @Test("unsupportedVersion error description contains the version number")
    func unsupportedVersionErrorDescription() async throws {
        let error = CSVImportError.unsupportedVersion(version: 99)
        let description = try #require(error.errorDescription)
        #expect(description.contains("99"))
    }

    @Test("invalidFormatMetadata error description contains the malformed line")
    func invalidFormatMetadataErrorDescription() async throws {
        let error = CSVImportError.invalidFormatMetadata(line: "# peach-export-format:abc")
        let description = try #require(error.errorDescription)
        #expect(description.contains("# peach-export-format:abc"))
    }

    // MARK: - ImportResult

    @Test("result holds both comparison and pitch matching payloads")
    func resultHoldsBothRecordTypes() async {
        let comparison = PitchDiscriminationPayload(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament"
        )
        let pitchMatching = PitchMatchingPayload(
            referenceNote: 60, targetNote: 67, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 7, tuningSystem: "equalTemperament"
        )
        let result = CSVImportParser.ImportResult(
            payloads: [
                "pitchDiscrimination": [(fixedDate(), comparison)],
                "pitchMatching": [(fixedDate(), pitchMatching)],
            ],
            errors: []
        )

        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("result holds errors alongside valid payloads")
    func resultHoldsErrorsAlongsideRecords() async {
        let comparison = PitchDiscriminationPayload(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament"
        )
        let error = CSVImportError.invalidRowData(row: 3, column: "referenceNote", value: "abc", reason: "not an integer")
        let result = CSVImportParser.ImportResult(
            payloads: ["pitchDiscrimination": [(fixedDate(), comparison)]],
            errors: [error]
        )

        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    // MARK: - Header Validation

    @Test("valid header passes validation")
    func validHeaderPassesValidation() async {
        let csv = makeCSV([validPitchDiscriminationRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.allSatisfy { error in
            if case .invalidHeader = error { return false }
            return true
        })
    }

    @Test("header missing trainingType column fails validation")
    func headerMissingTrainingTypeFailsValidation() async {
        let wrongHeader = CSVExportSchema.headerRow.replacingOccurrences(of: "trainingType", with: "type")
        let csv = CSVExportSchema.metadataLine + "\n" + wrongHeader + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
    }

    @Test("header missing discipline columns produces per-row errors")
    func headerMissingDisciplineColumnsProducesPerRowErrors() async {
        // Header with only common columns: trainingType + timestamp pass header
        // validation, but the pitch row's field count won't match.
        let header = "trainingType,timestamp"
        let csv = CSVExportSchema.metadataLine + "\n" + header + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { if case .invalidHeader = $0 { return true } else { return false } } == false)
        #expect(result.errors.contains { if case .invalidRowData = $0 { return true } else { return false } })
        #expect(pitchDiscriminations(from: result).isEmpty)
    }

    @Test("extra unknown column in header is tolerated")
    func extraColumnDoesNotFailValidation() async {
        let extraHeader = CSVExportSchema.headerRow + ",extraColumn"
        let baseFields = Array(CSVParserHelpers.parseCSVLine(validPitchDiscriminationRow)
            .prefix(CSVExportSchema.allColumns.count))
        let extendedRow = (baseFields + [""]).map { CSVParserHelpers.escapeField($0) }.joined(separator: ",")
        let csv = ([CSVExportSchema.metadataLine, extraHeader, extendedRow]).joined(separator: "\n")
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { if case .invalidHeader = $0 { return true } else { return false } } == false)
        #expect(pitchDiscriminations(from: result).count == 1)
    }

    @Test("reordered columns are accepted (header is name-keyed)")
    func reorderedColumnsAccepted() async {
        // Swap columns 0 and 1 in both header and row; parser should still
        // dispatch by name.
        var swappedColumns = CSVExportSchema.allColumns
        swappedColumns.swapAt(0, 1)
        let header = swappedColumns.joined(separator: ",")

        var swappedFields = Array(CSVParserHelpers.parseCSVLine(validPitchDiscriminationRow)
            .prefix(CSVExportSchema.allColumns.count))
        swappedFields.swapAt(0, 1)
        let row = swappedFields.map { CSVParserHelpers.escapeField($0) }.joined(separator: ",")

        let csv = ([CSVExportSchema.metadataLine, header, row]).joined(separator: "\n")
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { if case .invalidHeader = $0 { return true } else { return false } } == false)
        #expect(pitchDiscriminations(from: result).count == 1)
    }

    // MARK: - Cross-build compatibility
    //
    // Files exported by any build configuration must import successfully in any
    // other build configuration: rows for unregistered disciplines surface as
    // per-row errors but do not abort the import.

    @Test("19-column research-shape header parses pitch rows under any registry")
    func researchShapeHeaderParsesPitchRowsAnywhere() async {
        // Hard-coded V3 19-column header — what a Debug (Research) build emits.
        // In plain Debug, the timing columns are unknown; per-row dispatch must
        // still let pitch rows through.
        let researchHeader = "trainingType,timestamp,referenceNote,referenceNoteName,targetNote,targetNoteName,interval,tuningSystem,centOffset,isCorrect,initialCentOffset,userCentError,tempoBPM,offsetMs,meanOffsetMs,meanOffsetMsPosition0,meanOffsetMsPosition1,meanOffsetMsPosition2,meanOffsetMsPosition3"
        let csv = ([
            CSVExportSchema.metadataLine,
            researchHeader,
            validPitchDiscriminationRow,
            validPitchMatchingRow,
        ]).joined(separator: "\n")
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { if case .invalidHeader = $0 { return true } else { return false } } == false)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).count == 1)
    }

    @Test("12-column pitch-only header parses cleanly under any registry")
    func pitchOnlyHeaderParsesCleanlyAnywhere() async {
        // Hard-coded 12-column pitch-only header — what plain Debug emits.
        // In Debug (Research), the header is a strict subset; the parser
        // tolerates the missing timing columns.
        let pitchHeader = "trainingType,timestamp,referenceNote,referenceNoteName,targetNote,targetNoteName,interval,tuningSystem,centOffset,isCorrect,initialCentOffset,userCentError"
        let pitchRow = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = ([
            CSVExportSchema.metadataLine,
            pitchHeader,
            pitchRow,
        ]).joined(separator: "\n")
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.isEmpty)
        #expect(pitchDiscriminations(from: result).count == 1)
    }

    // MARK: - RFC 4180 CSV Line Parsing (via integration)

    @Test("handles quoted field with comma in note name column")
    func handlesQuotedFieldWithComma() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,\"C,4\",64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("handles quoted field with embedded quotes in note name column")
    func handlesQuotedFieldWithEmbeddedQuotes() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,\"C\"\"4\",64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("handles Windows-style CRLF line endings")
    func handlesCRLFLineEndings() async {
        // Build via makeCSV (which trims rows to the active schema), then swap
        // newlines for CRLF to test the parser's line-ending handling.
        let csv = makeCSV([validPitchDiscriminationRow, validPitchMatchingRow])
            .replacingOccurrences(of: "\n", with: "\r\n")
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Field-Level Parsing (via integration)

    @Test("all 13 interval abbreviations parse successfully")
    func allIntervalAbbreviationsParse() async {
        let abbreviations = ["P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "M7", "P8"]
        let expectedRawValues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

        let rows = abbreviations.map { abbr in
            "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,\(abbr),equalTemperament,15.5,true,,,,,,,,,"
        }
        let csv = makeCSV(rows)
        let result = CSVImportParser.parse(csv)
        let discs = pitchDiscriminations(from: result)
        #expect(discs.count == 13)
        #expect(result.errors.isEmpty)
        for (index, rawValue) in expectedRawValues.enumerated() {
            #expect(discs[index].payload.interval == rawValue)
        }
    }

    @Test("invalid interval abbreviation produces error")
    func invalidIntervalAbbreviationProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,P6,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("timestamp with fractional seconds parses successfully")
    func timestampWithFractionalSeconds() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00.000Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Row-to-Record Conversion

    @Test("parses valid pitch discrimination row")
    func parsesValidPitchDiscrimination() async {
        let csv = makeCSV([validPitchDiscriminationRow])
        let result = CSVImportParser.parse(csv)
        let discs = pitchDiscriminations(from: result)
        #expect(discs.count == 1)
        #expect(result.errors.isEmpty)

        let record = discs[0]
        #expect(record.payload.referenceNote == 60)
        #expect(record.payload.targetNote == 64)
        #expect(record.payload.centOffset == 15.5)
        #expect(record.payload.isCorrect == true)
        #expect(record.payload.interval == 4)
        #expect(record.payload.tuningSystem == "equalTemperament")
        #expect(record.timestamp == fixedDate())
    }

    @Test("parses valid pitch matching row")
    func parsesValidPitchMatching() async {
        let csv = makeCSV([validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        let matchings = pitchMatchings(from: result)
        #expect(matchings.count == 1)
        #expect(result.errors.isEmpty)

        let record = matchings[0]
        #expect(record.payload.referenceNote == 60)
        #expect(record.payload.targetNote == 67)
        #expect(record.payload.initialCentOffset == 25.0)
        #expect(record.payload.userCentError == 3.2)
        #expect(record.payload.interval == 7)
        #expect(record.payload.tuningSystem == "equalTemperament")
        #expect(record.timestamp == fixedDate())
    }

    @Test("row with wrong column count produces error")
    func rowWithWrongColumnCountProducesError() async {
        let csv = makeCSV(["pitchDiscrimination,2026-03-03T14:30:00Z,60"])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("row with invalid field produces error")
    func rowWithInvalidFieldProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,abc,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    // MARK: - Top-Level Parse Method

    @Test("parses complete CSV with mixed types")
    func parsesMixedTypes() async {
        let csv = makeCSV([validPitchDiscriminationRow, validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("header-only CSV returns empty result")
    func headerOnlyCSVReturnsEmptyResult() async {
        let csv = CSVExportSchema.metadataLine + "\n" + CSVExportSchema.headerRow
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(pitchMatchings(from: result).isEmpty)
        #expect(result.errors.isEmpty)
    }

    @Test("invalid header CSV returns error with no records")
    func invalidHeaderCSVReturnsError() async {
        let csv = CSVExportSchema.metadataLine + "\nwrong,headers\ndata,here"
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(pitchMatchings(from: result).isEmpty)
        #expect(result.errors.isEmpty == false)
    }

    @Test("CSV with mix of valid and invalid rows parses valid rows")
    func mixOfValidAndInvalidRows() async {
        let invalidRow = "pitchDiscrimination,2026-03-03T14:30:00Z,999,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([validPitchDiscriminationRow, invalidRow, validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).count == 1)
        #expect(result.errors.count == 1)
    }

    @Test("empty string input returns missingVersion error")
    func emptyStringReturnsMissingVersionError() async {
        let result = CSVImportParser.parse("")
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(pitchMatchings(from: result).isEmpty)
        #expect(result.errors.count == 1)
        if case .missingVersion = result.errors.first {} else {
            Issue.record("Expected missingVersion error")
        }
    }

    @Test("MIDI note 0 is valid")
    func midiNote0IsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,0,C-1,0,C-1,P1,equalTemperament,5.0,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("MIDI note 127 is valid")
    func midiNote127IsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,127,G9,127,G9,P1,equalTemperament,5.0,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("MIDI note 128 is invalid")
    func midiNote128IsInvalid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,128,X,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("negative MIDI note is invalid")
    func negativeMidiNoteIsInvalid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,-1,X,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid training type produces error")
    func invalidTrainingTypeProducesError() async {
        let row = "unknown,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid timestamp produces error")
    func invalidTimestampProducesError() async {
        let row = "pitchDiscrimination,not-a-date,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid tuning system produces error")
    func invalidTuningSystemProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,pythagorean,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid isCorrect value produces error")
    func invalidIsCorrectProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,True,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("non-numeric cent offset produces error")
    func nonNumericCentOffsetProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,abc,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("negative cent offset is valid for pitch discrimination")
    func negativeCentOffsetIsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,-8.3,false,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        let discs = pitchDiscriminations(from: result)
        #expect(discs.count == 1)
        #expect(discs[0].payload.centOffset == -8.3)
    }

    @Test("justIntonation tuning system is valid")
    func justIntonationIsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,justIntonation,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        let discs = pitchDiscriminations(from: result)
        #expect(discs.count == 1)
        #expect(discs[0].payload.tuningSystem == "justIntonation")
    }

    // MARK: - Version Migration

    /// V1 format: 12 columns, pitchComparison training type.
    private static let v1Header = "trainingType,timestamp,referenceNote,referenceNoteName,targetNote,targetNoteName,interval,tuningSystem,centOffset,isCorrect,initialCentOffset,userCentError"

    private func makeV1CSV(_ rows: [String]) -> String {
        (["# peach-export-format:1", Self.v1Header] + rows).joined(separator: "\n")
    }

    /// V2 format: 15 columns, pitchDiscrimination training type, rhythm columns added.
    private static let v2Header = "trainingType,timestamp,referenceNote,referenceNoteName,targetNote,targetNoteName,interval,tuningSystem,centOffset,isCorrect,initialCentOffset,userCentError,tempoBPM,offsetMs,userOffsetMs"

    private func makeV2CSV(_ rows: [String]) -> String {
        (["# peach-export-format:2", Self.v2Header] + rows).joined(separator: "\n")
    }

    @Test("v2 pitch discrimination CSV imports successfully after migration")
    func v2PitchDiscriminationImports() async {
        let csv = makeV2CSV(["pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,"])
        let result = CSVImportParser.parse(csv)
        let discs = pitchDiscriminations(from: result)
        #expect(result.errors.isEmpty)
        #expect(discs.count == 1)
        #expect(discs[0].payload.referenceNote == 60)
        #expect(discs[0].payload.targetNote == 64)
        #expect(discs[0].payload.centOffset == 15.5)
        #expect(discs[0].payload.isCorrect == true)
        #expect(discs[0].payload.interval == 4)
        #expect(discs[0].payload.tuningSystem == "equalTemperament")
    }

    @Test("v2 pitch matching CSV imports successfully after migration")
    func v2PitchMatchingImports() async {
        let csv = makeV2CSV(["pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2,,,"])
        let result = CSVImportParser.parse(csv)
        let matchings = pitchMatchings(from: result)
        #expect(result.errors.isEmpty)
        #expect(matchings.count == 1)
        #expect(matchings[0].payload.initialCentOffset == 25.0)
        #expect(matchings[0].payload.userCentError == 3.2)
    }

    @Test("v2 rhythm offset detection CSV imports successfully after migration")
    func v2TimingOffsetDetectionImports() async {
        let csv = makeV2CSV(["rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,"])
        let result = CSVImportParser.parse(csv)
        let rhythms = rhythmOffsetDetections(from: result)
        #expect(result.errors.isEmpty)
        #expect(rhythms.count == 1)
        #expect(rhythms[0].payload.tempoBPM == 120)
        #expect(rhythms[0].payload.offsetMs == 5.3)
    }

#if PEACH_RESEARCH
    @Test("v2 rhythmMatching CSV migrates to continuousRhythmMatching with meanOffsetMs")
    func v2RhythmMatchingMigratesToContinuous() async {
        // V2 format: 15 columns; rhythmMatching row has empty pitch fields, tempoBPM at 12, offsetMs at 13 (empty), userOffsetMs at 14
        let csv = makeV2CSV(["rhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,120,,5.3"])
        let result = CSVImportParser.parse(csv)
        let continuous = continuousRhythmMatchings(from: result)
        #expect(result.errors.isEmpty)
        #expect(continuous.count == 1)
        #expect(continuous[0].payload.tempoBPM == 120)
        #expect(continuous[0].payload.meanOffsetMs == 5.3)
    }
#endif

    @Test("v1 CSV imports successfully through v1→v2→v3 migration chain")
    func v1ImportsThroughFullChain() async {
        let csv = makeV1CSV([
            "pitchComparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,",
            "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2",
        ])
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.isEmpty)

        let discs = pitchDiscriminations(from: result)
        #expect(discs.count == 1)
        #expect(discs[0].payload.referenceNote == 60)
        #expect(discs[0].payload.centOffset == 15.5)

        let matchings = pitchMatchings(from: result)
        #expect(matchings.count == 1)
        #expect(matchings[0].payload.initialCentOffset == 25.0)
    }

    @Test("v1 pitchComparison training type is migrated to pitchDiscrimination")
    func v1TrainingTypeRenamed() async {
        let csv = makeV1CSV(["pitchComparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"])
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.isEmpty)
        #expect(pitchDiscriminations(from: result).count == 1)
    }

    @Test("future version 99 produces unsupportedVersion error")
    func futureVersionProducesError() async {
        let csv = "# peach-export-format:99\n" + CSVExportSchema.headerRow + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
        if case .unsupportedVersion(let version) = result.errors.first {
            #expect(version == 99)
        } else {
            Issue.record("Expected unsupportedVersion error")
        }
    }

    @Test("v2 CSV with mixed pitch and rhythm rows imports all types")
    func v2MixedTypesImport() async {
        let csv = makeV2CSV([
            "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,",
            "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2,,,",
            "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,",
        ])
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.isEmpty)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).count == 1)
        #expect(rhythmOffsetDetections(from: result).count == 1)
    }

    // MARK: - Version Dispatch

    @Test("missing version metadata line is rejected")
    func missingVersionRejected() async {
        let csv = CSVExportSchema.headerRow + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
        if case .missingVersion = result.errors.first {} else {
            Issue.record("Expected missingVersion error")
        }
    }

    @Test("version 0 produces unsupportedVersion error")
    func version0Rejected() async {
        let csv = "# peach-export-format:0\n" + CSVExportSchema.headerRow + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(result.errors.count == 1)
        if case .unsupportedVersion = result.errors.first {} else {
            Issue.record("Expected unsupportedVersion error")
        }
    }

    // MARK: - Rhythm Types

    @Test("parses rhythm offset detection row")
    func parsesTimingOffsetDetectionRow() async {
        let csv = makeCSV([validTimingOffsetDetectionRow])
        let result = CSVImportParser.parse(csv)
        let rhythms = rhythmOffsetDetections(from: result)
        #expect(rhythms.count == 1)
        #expect(result.errors.isEmpty)
        #expect(rhythms[0].payload.tempoBPM == 120)
        #expect(rhythms[0].payload.offsetMs == 5.3)
        #expect(rhythms[0].payload.isCorrect == true)
    }

    @Test("parses mixed pitch and rhythm types")
    func parsesMixedPitchAndRhythmTypes() async {
        let csv = makeCSV([
            validPitchDiscriminationRow,
            validTimingOffsetDetectionRow,
        ])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(rhythmOffsetDetections(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("rhythm-only file produces non-empty result")
    func rhythmOnlyFileIsValid() async {
        let csv = makeCSV([validTimingOffsetDetectionRow])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(pitchMatchings(from: result).isEmpty)
        #expect(rhythmOffsetDetections(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Round-Trip

#if PEACH_RESEARCH
    @Test("round-trip preserves all record types")
    func roundTrip() async {
        let pitchDiscRow = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
        let pitchMatchRow = "pitchMatching,2026-03-03T14:30:00Z,69,A4,72,C5,m3,equalTemperament,,,25.0,3.2,,,,,,,"
        let rhythmRow = "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,,,,,"
        let continuousRow = "continuousRhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,100,,-2.5,-1.0,,,3.5"
        let csv = makeCSV([pitchDiscRow, pitchMatchRow, rhythmRow, continuousRow])

        let result = CSVImportParser.parse(csv)
        #expect(result.errors.isEmpty)

        let discs = pitchDiscriminations(from: result)
        #expect(discs.count == 1)
        #expect(discs[0].payload.referenceNote == 60)
        #expect(discs[0].payload.targetNote == 64)
        #expect(discs[0].payload.centOffset == 15.5)
        #expect(discs[0].payload.isCorrect == true)

        let matchings = pitchMatchings(from: result)
        #expect(matchings.count == 1)
        #expect(matchings[0].payload.referenceNote == 69)
        #expect(matchings[0].payload.targetNote == 72)
        #expect(matchings[0].payload.initialCentOffset == 25.0)
        #expect(matchings[0].payload.userCentError == 3.2)

        let rhythms = rhythmOffsetDetections(from: result)
        #expect(rhythms.count == 1)
        #expect(rhythms[0].payload.tempoBPM == 120)
        #expect(rhythms[0].payload.offsetMs == 5.3)
        #expect(rhythms[0].payload.isCorrect == true)

        let continuous = continuousRhythmMatchings(from: result)
        #expect(continuous.count == 1)
        #expect(continuous[0].payload.tempoBPM == 100)
        #expect(continuous[0].payload.meanOffsetMs == -2.5)
        #expect(continuous[0].payload.meanOffsetMsPosition0 == -1.0)
        #expect(continuous[0].payload.meanOffsetMsPosition1 == nil)
        #expect(continuous[0].payload.meanOffsetMsPosition2 == nil)
        #expect(continuous[0].payload.meanOffsetMsPosition3 == 3.5)
    }

    @Test("continuous rhythm matching round-trip preserves all fields")
    func continuousRhythmMatchingRoundTrip() async {
        let row = "continuousRhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,140,,1.23,-2.0,4.5,,0.0"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)

        #expect(result.errors.isEmpty)
        let continuous = continuousRhythmMatchings(from: result)
        #expect(continuous.count == 1)

        let imported = continuous[0]
        #expect(imported.payload.tempoBPM == 140)
        #expect(imported.payload.meanOffsetMs == 1.23)
        #expect(imported.payload.meanOffsetMsPosition0 == -2.0)
        #expect(imported.payload.meanOffsetMsPosition1 == 4.5)
        #expect(imported.payload.meanOffsetMsPosition2 == nil)
        #expect(imported.payload.meanOffsetMsPosition3 == 0.0)
        #expect(imported.timestamp == fixedDate())
    }
#endif
}

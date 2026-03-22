import Testing
import Foundation
@testable import Peach

@Suite("CSVImportParser")
struct CSVImportParserTests {

    // MARK: - Test Helpers

    private func makeCSV(_ rows: [String]) -> String {
        ([CSVExportSchema.metadataLine, CSVExportSchema.headerRow] + rows).joined(separator: "\n")
    }

    private func fixedDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 3, hour: 14, minute: 30, second: 0)
        return calendar.date(from: components)!
    }

    private var validComparisonRow: String {
        "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
    }

    private var validPitchMatchingRow: String {
        "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2"
    }

    // MARK: - Task 1: CSVImportError

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
    func missingVersionErrorDescription() async {
        let error = CSVImportError.missingVersion
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test("unsupportedVersion error description contains the version number")
    func unsupportedVersionErrorDescription() async {
        let error = CSVImportError.unsupportedVersion(version: 99)
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description!.contains("99"))
    }

    @Test("invalidFormatMetadata error description contains the malformed line")
    func invalidFormatMetadataErrorDescription() async {
        let error = CSVImportError.invalidFormatMetadata(line: "# peach-export-format:abc")
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description!.contains("# peach-export-format:abc"))
    }

    // MARK: - Task 2: CSVImportResult

    @Test("result holds both comparison and pitch matching records")
    func resultHoldsBothRecordTypes() async {
        let comparison = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let pitchMatching = PitchMatchingRecord(
            referenceNote: 60, targetNote: 67, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 7, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let result = CSVImportParser.ImportResult(
            pitchDiscriminations: [comparison],
            pitchMatchings: [pitchMatching],
            rhythmOffsetDetections: [],
            rhythmMatchings: [],
            continuousRhythmMatchings: [],
            errors: []
        )

        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("result holds errors alongside valid records")
    func resultHoldsErrorsAlongsideRecords() async {
        let comparison = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let error = CSVImportError.invalidRowData(row: 3, column: "referenceNote", value: "abc", reason: "not an integer")
        let result = CSVImportParser.ImportResult(
            pitchDiscriminations: [comparison],
            pitchMatchings: [],
            rhythmOffsetDetections: [],
            rhythmMatchings: [],
            continuousRhythmMatchings: [],
            errors: [error]
        )

        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.errors.count == 1)
    }

    // MARK: - Task 3: Header Validation

    @Test("valid header passes validation")
    func validHeaderPassesValidation() async {
        let csv = makeCSV([validComparisonRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.allSatisfy { error in
            if case .invalidHeader = error { return false }
            return true
        })
    }

    @Test("missing column fails validation")
    func missingColumnFailsValidation() async {
        let incompleteHeader = "trainingType,timestamp,referenceNote"
        let csv = CSVExportSchema.metadataLine + "\n" + incompleteHeader + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
    }

    @Test("wrong column name fails validation")
    func wrongColumnFailsValidation() async {
        let wrongHeader = CSVExportSchema.headerRow.replacingOccurrences(of: "trainingType", with: "type")
        let csv = CSVExportSchema.metadataLine + "\n" + wrongHeader + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
    }

    @Test("extra column fails validation")
    func extraColumnFailsValidation() async {
        let extraHeader = CSVExportSchema.headerRow + ",extraColumn"
        let csv = CSVExportSchema.metadataLine + "\n" + extraHeader + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
    }

    // MARK: - Task 4: RFC 4180 CSV Line Parsing (via integration)

    @Test("handles quoted field with comma in note name column")
    func handlesQuotedFieldWithComma() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,\"C,4\",64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("handles quoted field with embedded quotes in note name column")
    func handlesQuotedFieldWithEmbeddedQuotes() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,\"C\"\"4\",64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("handles Windows-style CRLF line endings")
    func handlesCRLFLineEndings() async {
        let meta = CSVExportSchema.metadataLine
        let header = CSVExportSchema.headerRow
        let csv = meta + "\r\n" + header + "\r\n" + validComparisonRow + "\r\n" + validPitchMatchingRow
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Task 5: Field-Level Parsing (via integration)

    @Test("all 13 interval abbreviations parse successfully")
    func allIntervalAbbreviationsParse() async {
        let abbreviations = ["P1", "m2", "M2", "m3", "M3", "P4", "d5", "P5", "m6", "M6", "m7", "M7", "P8"]
        let expectedRawValues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

        let rows = abbreviations.map { abbr in
            "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,\(abbr),equalTemperament,15.5,true,,"
        }
        let csv = makeCSV(rows)
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 13)
        #expect(result.errors.isEmpty)
        for (index, rawValue) in expectedRawValues.enumerated() {
            #expect(result.pitchDiscriminations[index].interval == rawValue)
        }
    }

    @Test("invalid interval abbreviation produces error")
    func invalidIntervalAbbreviationProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,P6,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("timestamp with fractional seconds parses successfully")
    func timestampWithFractionalSeconds() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00.000Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Task 6: Row-to-Record Conversion

    @Test("parses valid comparison row")
    func parsesValidComparison() async {
        let csv = makeCSV([validComparisonRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)

        let record = result.pitchDiscriminations[0]
        #expect(record.referenceNote == 60)
        #expect(record.targetNote == 64)
        #expect(record.centOffset == 15.5)
        #expect(record.isCorrect == true)
        #expect(record.interval == 4)
        #expect(record.tuningSystem == "equalTemperament")
        #expect(record.timestamp == fixedDate())
    }

    @Test("parses valid pitch matching row")
    func parsesValidPitchMatching() async {
        let csv = makeCSV([validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)

        let record = result.pitchMatchings[0]
        #expect(record.referenceNote == 60)
        #expect(record.targetNote == 67)
        #expect(record.initialCentOffset == 25.0)
        #expect(record.userCentError == 3.2)
        #expect(record.interval == 7)
        #expect(record.tuningSystem == "equalTemperament")
        #expect(record.timestamp == fixedDate())
    }

    @Test("row with wrong column count produces error")
    func rowWithWrongColumnCountProducesError() async {
        let csv = makeCSV(["pitchDiscrimination,2026-03-03T14:30:00Z,60"])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("row with invalid field produces error")
    func rowWithInvalidFieldProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,abc,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("comparison row with non-empty pitch matching fields produces error")
    func comparisonRowWithNonEmptyPitchMatchingFieldsProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,25.0,3.2"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("pitch matching row with non-empty comparison fields produces error")
    func pitchMatchingRowWithNonEmptyComparisonFieldsProducesError() async {
        let row = "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,15.5,true,25.0,3.2"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.errors.count == 1)
    }

    // MARK: - Task 7: Top-Level Parse Method

    @Test("parses complete CSV with mixed types")
    func parsesMixedTypes() async {
        let csv = makeCSV([validComparisonRow, validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("header-only CSV returns empty result")
    func headerOnlyCSVReturnsEmptyResult() async {
        let csv = CSVExportSchema.metadataLine + "\n" + CSVExportSchema.headerRow
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.errors.isEmpty)
    }

    @Test("invalid header CSV returns error with no records")
    func invalidHeaderCSVReturnsError() async {
        let csv = CSVExportSchema.metadataLine + "\nwrong,headers\ndata,here"
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(!result.errors.isEmpty)
    }

    @Test("CSV with mix of valid and invalid rows parses valid rows")
    func mixOfValidAndInvalidRows() async {
        let invalidRow = "pitchDiscrimination,2026-03-03T14:30:00Z,999,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([validComparisonRow, invalidRow, validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.count == 1)
    }

    @Test("empty string input returns missingVersion error")
    func emptyStringReturnsMissingVersionError() async {
        let result = CSVImportParser.parse("")
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.errors.count == 1)
        if case .missingVersion = result.errors.first {} else {
            Issue.record("Expected missingVersion error")
        }
    }

    @Test("MIDI note 0 is valid")
    func midiNote0IsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,0,C-1,0,C-1,P1,equalTemperament,5.0,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("MIDI note 127 is valid")
    func midiNote127IsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,127,G9,127,G9,P1,equalTemperament,5.0,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("MIDI note 128 is invalid")
    func midiNote128IsInvalid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,128,X,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("negative MIDI note is invalid")
    func negativeMidiNoteIsInvalid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,-1,X,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid training type produces error")
    func invalidTrainingTypeProducesError() async {
        let row = "unknown,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid timestamp produces error")
    func invalidTimestampProducesError() async {
        let row = "pitchDiscrimination,not-a-date,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid tuning system produces error")
    func invalidTuningSystemProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,pythagorean,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid isCorrect value produces error")
    func invalidIsCorrectProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,True,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("non-numeric cent offset produces error")
    func nonNumericCentOffsetProducesError() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,abc,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("negative cent offset is valid for comparison")
    func negativeCentOffsetIsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,-8.3,false,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchDiscriminations[0].centOffset == -8.3)
    }

    @Test("justIntonation tuning system is valid")
    func justIntonationIsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,justIntonation,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchDiscriminations[0].tuningSystem == "justIntonation")
    }

    // MARK: - Orchestrator: Version Dispatch

    @Test("missing version metadata line is rejected")
    func missingVersionRejected() async {
        let csv = CSVExportSchema.headerRow + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
        if case .missingVersion = result.errors.first {} else {
            Issue.record("Expected missingVersion error")
        }
    }

    @Test("unknown version number is rejected")
    func unknownVersionRejected() async {
        let csv = "# peach-export-format:99\n" + CSVExportSchema.headerRow + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
        if case .unsupportedVersion(let version) = result.errors.first {
            #expect(version == 99)
        } else {
            Issue.record("Expected unsupportedVersion error")
        }
    }

    @Test("version 1 dispatches to v1 parser")
    func version1DispatchesToV1Parser() async {
        let csv = makeCSV([validComparisonRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - V2 Dispatch

    private func makeV2CSV(_ rows: [String]) -> String {
        ([CSVExportSchemaV2.metadataLine, CSVExportSchemaV2.headerRow] + rows).joined(separator: "\n")
    }

    private var validV2PitchDiscriminationRow: String {
        "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,,"
    }

    private var validV2RhythmOffsetDetectionRow: String {
        "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,,,,,,"
    }

    private var validV2RhythmMatchingRow: String {
        "rhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,120,,7.1,,,,,"
    }

    @Test("version 2 dispatches to v2 parser")
    func version2DispatchesToV2Parser() async {
        let csv = makeV2CSV([validV2PitchDiscriminationRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("version 2 parses all four training types via top-level parse")
    func v2ParsesAllFourTypes() async {
        let csv = makeV2CSV([
            validV2PitchDiscriminationRow,
            validV2RhythmOffsetDetectionRow,
            validV2RhythmMatchingRow,
        ])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - V1 Backward Compatibility

    @Test("V1 files still import via V1 parser after V2 registration")
    func v1BackwardCompatibility() async {
        let csv = makeCSV([validComparisonRow, validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.rhythmOffsetDetections.isEmpty)
        #expect(result.rhythmMatchings.isEmpty)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Rhythm-Only File Validation

    @Test("rhythm-only V2 file produces non-empty result")
    func rhythmOnlyFileIsValid() async {
        let csv = makeV2CSV([validV2RhythmOffsetDetectionRow, validV2RhythmMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - V2 Round-Trip

    @Test("export V2 then import V2 produces identical records for all five types")
    func v2RoundTrip() async {
        let pitchDisc = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let pitchMatch = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let rhythmOffset = RhythmOffsetDetectionRecord(
            tempoBPM: 120, offsetMs: 5.3, isCorrect: true, timestamp: fixedDate()
        )
        let rhythmMatch = RhythmMatchingRecord(
            tempoBPM: 90, userOffsetMs: -3.7, timestamp: fixedDate()
        )
        let continuousRhythm = ContinuousRhythmMatchingRecord(
            tempoBPM: 100, meanOffsetMs: -2.5, meanOffsetMsPosition0: -1.0, meanOffsetMsPosition3: 3.5, timestamp: fixedDate()
        )

        // Export
        let rows = [
            CSVRecordFormatter.format(pitchDisc),
            CSVRecordFormatter.format(pitchMatch),
            CSVRecordFormatter.format(rhythmOffset),
            CSVRecordFormatter.format(rhythmMatch),
            CSVRecordFormatter.format(continuousRhythm),
        ]
        let csv = makeV2CSV(rows)

        // Import
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.isEmpty)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.continuousRhythmMatchings.count == 1)

        let importedPitchDisc = result.pitchDiscriminations[0]
        #expect(importedPitchDisc.referenceNote == 60)
        #expect(importedPitchDisc.targetNote == 64)
        #expect(importedPitchDisc.centOffset == 15.5)
        #expect(importedPitchDisc.isCorrect == true)

        let importedPitchMatch = result.pitchMatchings[0]
        #expect(importedPitchMatch.referenceNote == 69)
        #expect(importedPitchMatch.targetNote == 72)
        #expect(importedPitchMatch.initialCentOffset == 25.0)
        #expect(importedPitchMatch.userCentError == 3.2)

        let importedRhythmOffset = result.rhythmOffsetDetections[0]
        #expect(importedRhythmOffset.tempoBPM == 120)
        #expect(importedRhythmOffset.offsetMs == 5.3)
        #expect(importedRhythmOffset.isCorrect == true)

        let importedRhythmMatch = result.rhythmMatchings[0]
        #expect(importedRhythmMatch.tempoBPM == 90)
        #expect(importedRhythmMatch.userOffsetMs == -3.7)

        let importedContinuous = result.continuousRhythmMatchings[0]
        #expect(importedContinuous.tempoBPM == 100)
        #expect(importedContinuous.meanOffsetMs == -2.5)
        #expect(importedContinuous.meanOffsetMsPosition0 == -1.0)
        #expect(importedContinuous.meanOffsetMsPosition1 == nil)
        #expect(importedContinuous.meanOffsetMsPosition2 == nil)
        #expect(importedContinuous.meanOffsetMsPosition3 == 3.5)
    }

    @Test("continuous rhythm matching round-trip preserves all fields")
    func continuousRhythmMatchingRoundTrip() async {
        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 140, meanOffsetMs: 1.23,
            meanOffsetMsPosition0: -2.0, meanOffsetMsPosition1: 4.5,
            meanOffsetMsPosition2: nil, meanOffsetMsPosition3: 0.0,
            timestamp: fixedDate()
        )

        let csv = makeV2CSV([CSVRecordFormatter.format(record)])
        let result = CSVImportParser.parse(csv)

        #expect(result.errors.isEmpty)
        #expect(result.continuousRhythmMatchings.count == 1)

        let imported = result.continuousRhythmMatchings[0]
        #expect(imported.tempoBPM == record.tempoBPM)
        #expect(imported.meanOffsetMs == record.meanOffsetMs)
        #expect(imported.meanOffsetMsPosition0 == -2.0)
        #expect(imported.meanOffsetMsPosition1 == 4.5)
        #expect(imported.meanOffsetMsPosition2 == nil)
        #expect(imported.meanOffsetMsPosition3 == 0.0)
        #expect(imported.timestamp == record.timestamp)
    }
}

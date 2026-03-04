import Testing
import Foundation
@testable import Peach

@Suite("CSVImportParser")
struct CSVImportParserTests {

    // MARK: - Test Helpers

    private func makeCSV(_ rows: [String]) -> String {
        ([CSVExportSchema.headerRow] + rows).joined(separator: "\n")
    }

    private func fixedDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 3, hour: 14, minute: 30, second: 0)
        return calendar.date(from: components)!
    }

    private var validComparisonRow: String {
        "comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
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

    // MARK: - Task 2: CSVImportResult

    @Test("result holds both comparison and pitch matching records")
    func resultHoldsBothRecordTypes() async {
        let comparison = ComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let pitchMatching = PitchMatchingRecord(
            referenceNote: 60, targetNote: 67, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 7, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let result = CSVImportParser.Result(
            comparisons: [comparison],
            pitchMatchings: [pitchMatching],
            errors: []
        )

        #expect(result.comparisons.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("result holds errors alongside valid records")
    func resultHoldsErrorsAlongsideRecords() async {
        let comparison = ComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        let error = CSVImportError.invalidRowData(row: 3, column: "referenceNote", value: "abc", reason: "not an integer")
        let result = CSVImportParser.Result(
            comparisons: [comparison],
            pitchMatchings: [],
            errors: [error]
        )

        #expect(result.comparisons.count == 1)
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
        let csv = incompleteHeader + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
        #expect(result.comparisons.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
    }

    @Test("wrong column name fails validation")
    func wrongColumnFailsValidation() async {
        let wrongHeader = CSVExportSchema.headerRow.replacingOccurrences(of: "trainingType", with: "type")
        let csv = wrongHeader + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
    }

    @Test("extra column fails validation")
    func extraColumnFailsValidation() async {
        let extraHeader = CSVExportSchema.headerRow + ",extraColumn"
        let csv = extraHeader + "\n" + validComparisonRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
    }

    // MARK: - Task 4: RFC 4180 CSV Line Parsing

    @Test("parses unescaped fields")
    func parsesUnescapedFields() async {
        let fields = CSVImportParser.parseCSVLine("a,b,c")
        #expect(fields == ["a", "b", "c"])
    }

    @Test("parses quoted fields with commas")
    func parsesQuotedFieldsWithCommas() async {
        let fields = CSVImportParser.parseCSVLine("\"a,b\",c,d")
        #expect(fields == ["a,b", "c", "d"])
    }

    @Test("parses quoted fields with embedded quotes")
    func parsesQuotedFieldsWithEmbeddedQuotes() async {
        let fields = CSVImportParser.parseCSVLine("\"say \"\"hi\"\"\",b,c")
        #expect(fields == ["say \"hi\"", "b", "c"])
    }

    @Test("parses empty fields")
    func parsesEmptyFields() async {
        let fields = CSVImportParser.parseCSVLine("a,,c,")
        #expect(fields == ["a", "", "c", ""])
    }

    // MARK: - Task 5: Field-Level Parsing

    @Test("valid interval abbreviations reverse lookup")
    func validIntervalAbbreviationsReverseLookup() async {
        let expected: [(String, Int)] = [
            ("P1", 0), ("m2", 1), ("M2", 2), ("m3", 3), ("M3", 4),
            ("P4", 5), ("d5", 6), ("P5", 7), ("m6", 8), ("M6", 9),
            ("m7", 10), ("M7", 11), ("P8", 12),
        ]
        for (abbreviation, rawValue) in expected {
            #expect(CSVImportParser.intervalRawValue(from: abbreviation) == rawValue,
                    "Expected \(rawValue) for '\(abbreviation)'")
        }
    }

    @Test("invalid interval abbreviation returns nil")
    func invalidIntervalAbbreviationReturnsNil() async {
        #expect(CSVImportParser.intervalRawValue(from: "P6") == nil)
        #expect(CSVImportParser.intervalRawValue(from: "") == nil)
        #expect(CSVImportParser.intervalRawValue(from: "invalid") == nil)
    }

    // MARK: - Task 6: Row-to-Record Conversion

    @Test("parses valid comparison row")
    func parsesValidComparison() async {
        let csv = makeCSV([validComparisonRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.count == 1)
        #expect(result.errors.isEmpty)

        let record = result.comparisons[0]
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
        let csv = makeCSV(["comparison,2026-03-03T14:30:00Z,60"])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("row with invalid field produces error")
    func rowWithInvalidFieldProducesError() async {
        let row = "comparison,2026-03-03T14:30:00Z,abc,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("comparison row with non-empty pitch matching fields produces error")
    func comparisonRowWithNonEmptyPitchMatchingFieldsProducesError() async {
        let row = "comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,25.0,3.2"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
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
        #expect(result.comparisons.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("header-only CSV returns empty result")
    func headerOnlyCSVReturnsEmptyResult() async {
        let csv = CSVExportSchema.headerRow
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.errors.isEmpty)
    }

    @Test("invalid header CSV returns error with no records")
    func invalidHeaderCSVReturnsError() async {
        let csv = "wrong,headers\ndata,here"
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(!result.errors.isEmpty)
    }

    @Test("CSV with mix of valid and invalid rows parses valid rows")
    func mixOfValidAndInvalidRows() async {
        let invalidRow = "comparison,2026-03-03T14:30:00Z,999,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([validComparisonRow, invalidRow, validPitchMatchingRow])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.count == 1)
    }

    @Test("empty string input returns empty result with no errors")
    func emptyStringReturnsEmptyResult() async {
        let result = CSVImportParser.parse("")
        #expect(result.comparisons.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(!result.errors.isEmpty)
    }

    @Test("MIDI note 0 is valid")
    func midiNote0IsValid() async {
        let row = "comparison,2026-03-03T14:30:00Z,0,C-1,0,C-1,P1,equalTemperament,5.0,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("MIDI note 127 is valid")
    func midiNote127IsValid() async {
        let row = "comparison,2026-03-03T14:30:00Z,127,G9,127,G9,P1,equalTemperament,5.0,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("MIDI note 128 is invalid")
    func midiNote128IsInvalid() async {
        let row = "comparison,2026-03-03T14:30:00Z,128,X,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("negative MIDI note is invalid")
    func negativeMidiNoteIsInvalid() async {
        let row = "comparison,2026-03-03T14:30:00Z,-1,X,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid training type produces error")
    func invalidTrainingTypeProducesError() async {
        let row = "unknown,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid timestamp produces error")
    func invalidTimestampProducesError() async {
        let row = "comparison,not-a-date,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid tuning system produces error")
    func invalidTuningSystemProducesError() async {
        let row = "comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,pythagorean,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("invalid isCorrect value produces error")
    func invalidIsCorrectProducesError() async {
        let row = "comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,True,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("non-numeric cent offset produces error")
    func nonNumericCentOffsetProducesError() async {
        let row = "comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,abc,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("negative cent offset is valid for comparison")
    func negativeCentOffsetIsValid() async {
        let row = "comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,-8.3,false,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.count == 1)
        #expect(result.comparisons[0].centOffset == -8.3)
    }

    @Test("justIntonation tuning system is valid")
    func justIntonationIsValid() async {
        let row = "comparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,justIntonation,15.5,true,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        #expect(result.comparisons.count == 1)
        #expect(result.comparisons[0].tuningSystem == "justIntonation")
    }
}

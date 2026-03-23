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

    /// 19-column pitch discrimination row (V3 format).
    private var validPitchDiscriminationRow: String {
        "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,,,,"
    }

    /// 19-column pitch matching row (V3 format).
    private var validPitchMatchingRow: String {
        "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2,,,,,,,"
    }

    /// 19-column rhythm offset detection row (V3 format).
    private var validRhythmOffsetDetectionRow: String {
        "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,,,,,"
    }

    private func pitchDiscriminations(from result: CSVImportParser.ImportResult) -> [PitchDiscriminationRecord] {
        (result.records["pitchDiscrimination"] ?? []).compactMap { $0 as? PitchDiscriminationRecord }
    }

    private func pitchMatchings(from result: CSVImportParser.ImportResult) -> [PitchMatchingRecord] {
        (result.records["pitchMatching"] ?? []).compactMap { $0 as? PitchMatchingRecord }
    }

    private func rhythmOffsetDetections(from result: CSVImportParser.ImportResult) -> [RhythmOffsetDetectionRecord] {
        (result.records["rhythmOffsetDetection"] ?? []).compactMap { $0 as? RhythmOffsetDetectionRecord }
    }

    private func continuousRhythmMatchings(from result: CSVImportParser.ImportResult) -> [ContinuousRhythmMatchingRecord] {
        (result.records["continuousRhythmMatching"] ?? []).compactMap { $0 as? ContinuousRhythmMatchingRecord }
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

    // MARK: - ImportResult

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
            records: [
                "pitchDiscrimination": [comparison],
                "pitchMatching": [pitchMatching],
            ],
            errors: []
        )

        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(pitchMatchings(from: result).count == 1)
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
            records: ["pitchDiscrimination": [comparison]],
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

    @Test("missing column fails validation")
    func missingColumnFailsValidation() async {
        let incompleteHeader = "trainingType,timestamp,referenceNote"
        let csv = CSVExportSchema.metadataLine + "\n" + incompleteHeader + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(pitchMatchings(from: result).isEmpty)
    }

    @Test("wrong column name fails validation")
    func wrongColumnFailsValidation() async {
        let wrongHeader = CSVExportSchema.headerRow.replacingOccurrences(of: "trainingType", with: "type")
        let csv = CSVExportSchema.metadataLine + "\n" + wrongHeader + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
    }

    @Test("extra column fails validation")
    func extraColumnFailsValidation() async {
        let extraHeader = CSVExportSchema.headerRow + ",extraColumn"
        let csv = CSVExportSchema.metadataLine + "\n" + extraHeader + "\n" + validPitchDiscriminationRow
        let result = CSVImportParser.parse(csv)
        #expect(result.errors.contains { error in
            if case .invalidHeader = error { return true }
            return false
        })
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
        let meta = CSVExportSchema.metadataLine
        let header = CSVExportSchema.headerRow
        let csv = meta + "\r\n" + header + "\r\n" + validPitchDiscriminationRow + "\r\n" + validPitchMatchingRow
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
            #expect(discs[index].interval == rawValue)
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
        let matchings = pitchMatchings(from: result)
        #expect(matchings.count == 1)
        #expect(result.errors.isEmpty)

        let record = matchings[0]
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
        #expect(!result.errors.isEmpty)
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
        #expect(discs[0].centOffset == -8.3)
    }

    @Test("justIntonation tuning system is valid")
    func justIntonationIsValid() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,justIntonation,15.5,true,,,,,,,,,"
        let csv = makeCSV([row])
        let result = CSVImportParser.parse(csv)
        let discs = pitchDiscriminations(from: result)
        #expect(discs.count == 1)
        #expect(discs[0].tuningSystem == "justIntonation")
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

    @Test("unknown version number is rejected")
    func unknownVersionRejected() async {
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

    // MARK: - Rhythm Types

    @Test("parses rhythm offset detection row")
    func parsesRhythmOffsetDetectionRow() async {
        let csv = makeCSV([validRhythmOffsetDetectionRow])
        let result = CSVImportParser.parse(csv)
        let rhythms = rhythmOffsetDetections(from: result)
        #expect(rhythms.count == 1)
        #expect(result.errors.isEmpty)
        #expect(rhythms[0].tempoBPM == 120)
        #expect(rhythms[0].offsetMs == 5.3)
        #expect(rhythms[0].isCorrect == true)
    }

    @Test("parses mixed pitch and rhythm types")
    func parsesMixedPitchAndRhythmTypes() async {
        let csv = makeCSV([
            validPitchDiscriminationRow,
            validRhythmOffsetDetectionRow,
        ])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).count == 1)
        #expect(rhythmOffsetDetections(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("rhythm-only file produces non-empty result")
    func rhythmOnlyFileIsValid() async {
        let csv = makeCSV([validRhythmOffsetDetectionRow])
        let result = CSVImportParser.parse(csv)
        #expect(pitchDiscriminations(from: result).isEmpty)
        #expect(pitchMatchings(from: result).isEmpty)
        #expect(rhythmOffsetDetections(from: result).count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Round-Trip

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
        #expect(discs[0].referenceNote == 60)
        #expect(discs[0].targetNote == 64)
        #expect(discs[0].centOffset == 15.5)
        #expect(discs[0].isCorrect == true)

        let matchings = pitchMatchings(from: result)
        #expect(matchings.count == 1)
        #expect(matchings[0].referenceNote == 69)
        #expect(matchings[0].targetNote == 72)
        #expect(matchings[0].initialCentOffset == 25.0)
        #expect(matchings[0].userCentError == 3.2)

        let rhythms = rhythmOffsetDetections(from: result)
        #expect(rhythms.count == 1)
        #expect(rhythms[0].tempoBPM == 120)
        #expect(rhythms[0].offsetMs == 5.3)
        #expect(rhythms[0].isCorrect == true)

        let continuous = continuousRhythmMatchings(from: result)
        #expect(continuous.count == 1)
        #expect(continuous[0].tempoBPM == 100)
        #expect(continuous[0].meanOffsetMs == -2.5)
        #expect(continuous[0].meanOffsetMsPosition0 == -1.0)
        #expect(continuous[0].meanOffsetMsPosition1 == nil)
        #expect(continuous[0].meanOffsetMsPosition2 == nil)
        #expect(continuous[0].meanOffsetMsPosition3 == 3.5)
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
        #expect(imported.tempoBPM == 140)
        #expect(imported.meanOffsetMs == 1.23)
        #expect(imported.meanOffsetMsPosition0 == -2.0)
        #expect(imported.meanOffsetMsPosition1 == 4.5)
        #expect(imported.meanOffsetMsPosition2 == nil)
        #expect(imported.meanOffsetMsPosition3 == 0.0)
        #expect(imported.timestamp == fixedDate())
    }
}

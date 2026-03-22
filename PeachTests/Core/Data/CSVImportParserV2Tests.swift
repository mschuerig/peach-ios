import Testing
import Foundation
@testable import Peach

@Suite("CSVImportParserV2")
struct CSVImportParserV2Tests {

    private let parser = CSVImportParserV2()

    // MARK: - Test Data Helpers

    private func fixedDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 3, hour: 14, minute: 30, second: 0)
        return calendar.date(from: components)!
    }

    private var v2Header: String { CSVExportSchemaV2.headerRow }

    private var validPitchDiscriminationRow: String {
        "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,,,,"
    }

    private var validPitchMatchingRow: String {
        "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2,,,,"
    }

    private var validRhythmOffsetDetectionRow: String {
        "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,,"
    }

    private var validRhythmMatchingRow: String {
        "rhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,120,,7.1,"
    }

    private var validContinuousRhythmMatchingRow: String {
        "continuousRhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,120,,,-3.5"
    }

    private func makeV2CSV(_ rows: [String]) -> String {
        ([CSVExportSchemaV2.metadataLine, v2Header] + rows).joined(separator: "\n")
    }

    // MARK: - Supported Version

    @Test("supportedVersion is 2")
    func supportedVersionIs2() async {
        #expect(parser.supportedVersion == 2)
    }

    // MARK: - Header Validation

    @Test("valid V2 header passes validation")
    func validV2HeaderPasses() async {
        let lines = [v2Header, validPitchDiscriminationRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("missing header returns error")
    func missingHeader() async {
        let result = parser.parse(lines: [])
        #expect(result.errors.count == 1)
        if case .invalidHeader = result.errors.first {} else {
            Issue.record("Expected invalidHeader error")
        }
    }

    @Test("V1 header is rejected by V2 parser (column count mismatch)")
    func v1HeaderRejected() async {
        let lines = [CSVExportSchema.headerRow, validPitchDiscriminationRow]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
        if case .invalidHeader = result.errors.first {} else {
            Issue.record("Expected invalidHeader error")
        }
    }

    @Test("wrong column name in header returns error")
    func wrongColumnName() async {
        let wrongHeader = v2Header.replacingOccurrences(of: "trainingType", with: "type")
        let lines = [wrongHeader, validPitchDiscriminationRow]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
        if case .invalidHeader = result.errors.first {} else {
            Issue.record("Expected invalidHeader error")
        }
    }

    // MARK: - Pitch Discrimination Parsing

    @Test("parses pitch discrimination row correctly")
    func parsesPitchDiscriminationRow() async {
        let lines = [v2Header, validPitchDiscriminationRow]
        let result = parser.parse(lines: lines)
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

    // MARK: - Pitch Matching Parsing

    @Test("parses pitch matching row correctly")
    func parsesPitchMatchingRow() async {
        let lines = [v2Header, validPitchMatchingRow]
        let result = parser.parse(lines: lines)
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

    // MARK: - Rhythm Offset Detection Parsing

    @Test("parses rhythm offset detection row correctly")
    func parsesRhythmOffsetDetectionRow() async {
        let lines = [v2Header, validRhythmOffsetDetectionRow]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.errors.isEmpty)

        let record = result.rhythmOffsetDetections[0]
        #expect(record.tempoBPM == 120)
        #expect(record.offsetMs == 5.3)
        #expect(record.isCorrect == true)
        #expect(record.timestamp == fixedDate())
    }

    @Test("parses rhythm offset detection with negative offset")
    func parsesNegativeRhythmOffset() async {
        let row = "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,false,,,90,-12.5,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.rhythmOffsetDetections[0].offsetMs == -12.5)
        #expect(result.rhythmOffsetDetections[0].isCorrect == false)
    }

    // MARK: - Rhythm Matching Parsing

    @Test("parses rhythm matching row correctly")
    func parsesRhythmMatchingRow() async {
        let lines = [v2Header, validRhythmMatchingRow]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.errors.isEmpty)

        let record = result.rhythmMatchings[0]
        #expect(record.tempoBPM == 120)
        #expect(record.userOffsetMs == 7.1)
        #expect(record.timestamp == fixedDate())
    }

    @Test("parses rhythm matching with negative user offset")
    func parsesNegativeRhythmMatchingOffset() async {
        let row = "rhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,80,,-3.7,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.rhythmMatchings[0].userOffsetMs == -3.7)
    }

    // MARK: - Continuous Rhythm Matching Parsing

    @Test("parses continuous rhythm matching row correctly")
    func parsesContinuousRhythmMatchingRow() async {
        let lines = [v2Header, validContinuousRhythmMatchingRow]
        let result = parser.parse(lines: lines)
        #expect(result.continuousRhythmMatchings.count == 1)
        #expect(result.errors.isEmpty)

        let record = result.continuousRhythmMatchings[0]
        #expect(record.tempoBPM == 120)
        #expect(record.meanOffsetMs == -3.5)
        #expect(record.timestamp == fixedDate())
    }

    @Test("parses continuous rhythm matching with positive meanOffsetMs")
    func parsesContinuousRhythmMatchingPositiveOffset() async {
        let row = "continuousRhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,90,,,1.2"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.continuousRhythmMatchings.count == 1)
        #expect(result.continuousRhythmMatchings[0].meanOffsetMs == 1.2)
    }

    @Test("continuous rhythm matching with non-numeric meanOffsetMs produces error")
    func continuousRhythmMatchingInvalidMeanOffset() async {
        let row = "continuousRhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,120,,,abc"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    @Test("continuous rhythm matching with non-empty pitch columns produces error")
    func continuousRhythmMatchingWithPitchColumnsErrors() async {
        let row = "continuousRhythmMatching,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,,,,,120,,,-3.5"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
        #expect(result.continuousRhythmMatchings.isEmpty)
    }

    // MARK: - All Five Training Types

    @Test("parses all five training types in one file")
    func parsesAllFiveTypes() async {
        let lines = [v2Header, validPitchDiscriminationRow, validPitchMatchingRow,
                     validRhythmOffsetDetectionRow, validRhythmMatchingRow, validContinuousRhythmMatchingRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.continuousRhythmMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Empty Lines

    @Test("empty lines are skipped")
    func emptyLinesSkipped() async {
        let lines = [v2Header, "", validRhythmOffsetDetectionRow, "", validRhythmMatchingRow, ""]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("header-only input returns empty result with no errors")
    func headerOnly() async {
        let lines = [v2Header]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.rhythmOffsetDetections.isEmpty)
        #expect(result.rhythmMatchings.isEmpty)
        #expect(result.continuousRhythmMatchings.isEmpty)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Cross-Type Column Validation

    @Test("pitch discrimination row with non-empty rhythm columns produces error")
    func pitchDiscriminationWithRhythmColumnsErrors() async {
        let row = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,,120,5.0,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("pitch matching row with non-empty rhythm columns produces error")
    func pitchMatchingWithRhythmColumnsErrors() async {
        let row = "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2,120,,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm offset detection row with non-empty pitch columns produces error")
    func rhythmOffsetWithPitchColumnsErrors() async {
        let row = "rhythmOffsetDetection,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,,true,,,120,5.3,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmOffsetDetections.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm matching row with non-empty pitch columns produces error")
    func rhythmMatchingWithPitchColumnsErrors() async {
        let row = "rhythmMatching,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,,,,,,7.1,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmMatchings.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm offset detection row with non-empty userOffsetMs produces error")
    func rhythmOffsetWithUserOffsetMsErrors() async {
        let row = "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,2.0,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmOffsetDetections.isEmpty)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm matching row with non-empty offsetMs produces error")
    func rhythmMatchingWithOffsetMsErrors() async {
        let row = "rhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,120,5.3,7.1,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmMatchings.isEmpty)
        #expect(result.errors.count == 1)
    }

    // MARK: - Invalid Rhythm Fields

    @Test("rhythm offset detection with non-integer tempoBPM produces error")
    func invalidTempoBPMForRhythmOffset() async {
        let row = "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,abc,5.3,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm offset detection with non-numeric offsetMs produces error")
    func invalidOffsetMsForRhythmOffset() async {
        let row = "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,120,abc,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm offset detection with invalid isCorrect produces error")
    func invalidIsCorrectForRhythmOffset() async {
        let row = "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,yes,,,120,5.3,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm matching with non-integer tempoBPM produces error")
    func invalidTempoBPMForRhythmMatching() async {
        let row = "rhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,abc,,7.1,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    @Test("rhythm matching with non-numeric userOffsetMs produces error")
    func invalidUserOffsetMsForRhythmMatching() async {
        let row = "rhythmMatching,2026-03-03T14:30:00Z,,,,,,,,,,,120,,abc,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    @Test("invalid timestamp produces error for rhythm rows")
    func invalidTimestampForRhythm() async {
        let row = "rhythmOffsetDetection,not-a-date,,,,,,,,true,,,120,5.3,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    // MARK: - Invalid Training Type

    @Test("unknown training type produces error")
    func unknownTrainingTypeProducesError() async {
        let row = "unknown,2026-03-03T14:30:00Z,,,,,,,,true,,,120,5.3,,"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    // MARK: - Wrong Column Count

    @Test("row with wrong column count produces error")
    func wrongColumnCount() async {
        let row = "rhythmOffsetDetection,2026-03-03T14:30:00Z,120"
        let lines = [v2Header, row]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
    }

    // MARK: - Valid and Invalid Rows Mixed

    @Test("invalid row produces error alongside valid rows")
    func invalidAlongsideValid() async {
        let invalidRow = "rhythmOffsetDetection,2026-03-03T14:30:00Z,,,,,,,,true,,,abc,5.3,,"
        let lines = [v2Header, validRhythmOffsetDetectionRow, invalidRow, validRhythmMatchingRow]
        let result = parser.parse(lines: lines)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.rhythmMatchings.count == 1)
        #expect(result.errors.count == 1)
    }

    // MARK: - V2 CSV Without Continuous Rhythm Matching (AC #5)

    @Test("V2 CSV without continuousRhythmMatching rows imports successfully")
    func v2WithoutContinuousImportsSuccessfully() async {
        let lines = [v2Header, validPitchDiscriminationRow, validRhythmOffsetDetectionRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.rhythmOffsetDetections.count == 1)
        #expect(result.continuousRhythmMatchings.isEmpty)
        #expect(result.errors.isEmpty)
    }
}

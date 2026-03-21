import Testing
import Foundation
@testable import Peach

@Suite("CSVImportParserV1")
struct CSVImportParserV1Tests {

    private let parser = CSVImportParserV1()

    private var validComparisonRow: String {
        "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
    }

    private var validPitchMatchingRow: String {
        "pitchMatching,2026-03-03T14:30:00Z,60,C4,67,G4,P5,equalTemperament,,,25.0,3.2"
    }

    private func fixedDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 3, hour: 14, minute: 30, second: 0)
        return calendar.date(from: components)!
    }

    // MARK: - Header Validation

    @Test("valid header passes validation")
    func validHeaderPasses() async {
        let lines = [CSVExportSchema.headerRow, validComparisonRow]
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

    @Test("wrong header returns error")
    func wrongHeader() async {
        let lines = ["wrong,headers,only"]
        let result = parser.parse(lines: lines)
        #expect(result.errors.count == 1)
        if case .invalidHeader = result.errors.first {} else {
            Issue.record("Expected invalidHeader error")
        }
    }

    // MARK: - Row Parsing

    @Test("parses comparison row from pre-split lines")
    func parsesComparisonRow() async {
        let lines = [CSVExportSchema.headerRow, validComparisonRow]
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

    @Test("parses pitch matching row from pre-split lines")
    func parsesPitchMatchingRow() async {
        let lines = [CSVExportSchema.headerRow, validPitchMatchingRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)

        let record = result.pitchMatchings[0]
        #expect(record.referenceNote == 60)
        #expect(record.targetNote == 67)
        #expect(record.initialCentOffset == 25.0)
        #expect(record.userCentError == 3.2)
    }

    @Test("parses mixed rows")
    func parsesMixedRows() async {
        let lines = [CSVExportSchema.headerRow, validComparisonRow, validPitchMatchingRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.pitchMatchings.count == 1)
        #expect(result.errors.isEmpty)
    }

    @Test("invalid row produces error alongside valid rows")
    func invalidRowAlongsideValid() async {
        let invalidRow = "pitchDiscrimination,2026-03-03T14:30:00Z,999,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let lines = [CSVExportSchema.headerRow, validComparisonRow, invalidRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.count == 1)
    }

    @Test("header-only input returns empty result with no errors")
    func headerOnly() async {
        let lines = [CSVExportSchema.headerRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.isEmpty)
        #expect(result.pitchMatchings.isEmpty)
        #expect(result.errors.isEmpty)
    }

    @Test("empty lines are skipped")
    func emptyLinesSkipped() async {
        let lines = [CSVExportSchema.headerRow, "", validComparisonRow, ""]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Legacy Training Type Normalization

    @Test("legacy pitchComparison training type imports correctly")
    func legacyPitchComparisonImports() async {
        let legacyRow = "pitchComparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let lines = [CSVExportSchema.headerRow, legacyRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 1)
        #expect(result.errors.isEmpty)
        #expect(result.pitchDiscriminations[0].referenceNote == 60)
    }

    @Test("legacy pitchComparison mixed with new format imports correctly")
    func legacyMixedWithNewFormat() async {
        let legacyRow = "pitchComparison,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,10.0,true,,"
        let newRow = validComparisonRow
        let lines = [CSVExportSchema.headerRow, legacyRow, newRow]
        let result = parser.parse(lines: lines)
        #expect(result.pitchDiscriminations.count == 2)
        #expect(result.errors.isEmpty)
    }
}

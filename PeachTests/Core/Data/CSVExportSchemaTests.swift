import Testing
import Foundation
@testable import Peach

@Suite("CSVExportSchema Tests")
struct CSVExportSchemaTests {

    init() {
        TrainingDisciplineRegistry._replaceSharedForTesting(disciplines: DisciplineBootstrap.allDisciplines)
    }

    // MARK: - Format Version

    @Test("formatVersion is 3")
    func formatVersionIsThree() async {
        #expect(CSVExportSchema.formatVersion == 3)
    }

    @Test("metadataLine uses shared prefix with version 3")
    func metadataLineDerived() async {
        #expect(CSVExportSchema.metadataLine == "# peach-export-format:3")
    }

    // MARK: - Header Row Invariants
    //
    // The wire format is column-name keyed: import looks columns up by name,
    // not by position. Tests assert structural invariants that hold under any
    // discipline registration, not specific column counts or positions.

    @Test("headerRow starts with common columns")
    func headerRowStartsWithCommonColumns() async {
        let columns = CSVExportSchema.headerRow.split(separator: ",").map(String.init)
        let common = CSVExportSchema.commonColumns
        #expect(Array(columns.prefix(common.count)) == common)
    }

    @Test("headerRow contains every registered discipline's csvColumns")
    func headerRowContainsAllRegisteredDisciplineColumns() async {
        let headerSet = Set(CSVExportSchema.headerRow.split(separator: ",").map(String.init))
        for discipline in TrainingDisciplineRegistry.shared.all {
            for column in discipline.csvColumns {
                #expect(headerSet.contains(column),
                        "headerRow missing column '\(column)' for discipline '\(discipline.csvTrainingType)'")
            }
        }
    }

    @Test("headerRow has no duplicate column names")
    func headerRowHasNoDuplicates() async {
        let columns = CSVExportSchema.headerRow.split(separator: ",").map(String.init)
        #expect(columns.count == Set(columns).count)
    }

    @Test("columnIndex is bijective with allColumns")
    func columnIndexIsBijective() async {
        let columns = CSVExportSchema.allColumns
        let index = CSVExportSchema.columnIndex
        #expect(index.count == columns.count)
        for (position, name) in columns.enumerated() {
            #expect(index[name] == position)
        }
    }

    @Test("allColumns are assembled from common columns plus registry columns")
    func allColumnsFromRegistry() async {
        let columns = CSVExportSchema.allColumns
        let common = CSVExportSchema.commonColumns
        #expect(Array(columns.prefix(common.count)) == common)
        #expect(columns.count == common.count + TrainingDisciplineRegistry.shared.csvDisciplineColumns.count)
    }
}

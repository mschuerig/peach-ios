import Testing
import Foundation
@testable import Peach

@Suite("CSVExportSchema Tests")
struct CSVExportSchemaTests {

    // MARK: - Format Version

    @Test("formatVersion is 3")
    func formatVersionIsThree() async {
        #expect(CSVExportSchema.formatVersion == 3)
    }

    @Test("metadataLine uses shared prefix with version 3")
    func metadataLineDerived() async {
        #expect(CSVExportSchema.metadataLine == "# peach-export-format:3")
    }

    // MARK: - Header Row

    @Test("headerRow contains 19 columns in correct order")
    func headerRowContains19Columns() async {
        let header = CSVExportSchema.headerRow
        let columns = header.split(separator: ",").map(String.init)

        #expect(columns.count == 19)
        // Common columns
        #expect(columns[0] == "trainingType")
        #expect(columns[1] == "timestamp")
        // Pitch discrimination columns
        #expect(columns[2] == "referenceNote")
        #expect(columns[3] == "referenceNoteName")
        #expect(columns[4] == "targetNote")
        #expect(columns[5] == "targetNoteName")
        #expect(columns[6] == "interval")
        #expect(columns[7] == "tuningSystem")
        #expect(columns[8] == "centOffset")
        #expect(columns[9] == "isCorrect")
        // Pitch matching adds
        #expect(columns[10] == "initialCentOffset")
        #expect(columns[11] == "userCentError")
        // Rhythm offset detection adds (isCorrect/tempoBPM already present)
        #expect(columns[12] == "tempoBPM")
        #expect(columns[13] == "offsetMs")
        // Continuous rhythm matching adds
        #expect(columns[14] == "meanOffsetMs")
        #expect(columns[15] == "meanOffsetMsPosition0")
        #expect(columns[16] == "meanOffsetMsPosition1")
        #expect(columns[17] == "meanOffsetMsPosition2")
        #expect(columns[18] == "meanOffsetMsPosition3")
    }

    @Test("columnIndex maps all column names to correct indices")
    func columnIndexMapsCorrectly() async {
        let index = CSVExportSchema.columnIndex
        #expect(index["trainingType"] == 0)
        #expect(index["timestamp"] == 1)
        #expect(index["referenceNote"] == 2)
        #expect(index["meanOffsetMsPosition3"] == 18)
        #expect(index.count == 19)
    }

    @Test("allColumns are assembled dynamically from registry")
    func allColumnsFromRegistry() async {
        let columns = CSVExportSchema.allColumns
        // Common columns come first
        #expect(columns[0] == "trainingType")
        #expect(columns[1] == "timestamp")
        // Remaining columns come from discipline registration order
        #expect(columns.count == 2 + TrainingDisciplineRegistry.shared.csvDisciplineColumns.count)
    }
}

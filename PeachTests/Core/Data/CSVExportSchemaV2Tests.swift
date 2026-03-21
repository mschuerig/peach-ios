import Testing
import Foundation
@testable import Peach

@Suite("CSVExportSchemaV2 Tests")
struct CSVExportSchemaV2Tests {

    // MARK: - Format Version

    @Test("formatVersion is 2")
    func formatVersionIsTwo() async {
        #expect(CSVExportSchemaV2.formatVersion == 2)
    }

    @Test("metadataLine uses shared prefix with version 2")
    func metadataLineDerived() async {
        #expect(CSVExportSchemaV2.metadataLine == "# peach-export-format:2")
    }

    @Test("metadataPrefix is shared with V1")
    func metadataPrefixSharedWithV1() async {
        #expect(CSVExportSchemaV2.metadataPrefix == CSVExportSchema.metadataPrefix)
    }

    // MARK: - Training Type

    @Test("TrainingType has four cases with correct csvValues")
    func trainingTypeCsvValues() async {
        #expect(CSVExportSchemaV2.TrainingType.pitchDiscrimination.csvValue == "pitchDiscrimination")
        #expect(CSVExportSchemaV2.TrainingType.pitchMatching.csvValue == "pitchMatching")
        #expect(CSVExportSchemaV2.TrainingType.rhythmOffsetDetection.csvValue == "rhythmOffsetDetection")
        #expect(CSVExportSchemaV2.TrainingType.rhythmMatching.csvValue == "rhythmMatching")
    }

    // MARK: - Header Row

    @Test("headerRow contains all 15 columns in correct order")
    func headerRowContainsAll15Columns() async {
        let header = CSVExportSchemaV2.headerRow
        let columns = header.split(separator: ",").map(String.init)

        #expect(columns.count == 15)
        #expect(columns[0] == "trainingType")
        #expect(columns[1] == "timestamp")
        #expect(columns[2] == "referenceNote")
        #expect(columns[3] == "referenceNoteName")
        #expect(columns[4] == "targetNote")
        #expect(columns[5] == "targetNoteName")
        #expect(columns[6] == "interval")
        #expect(columns[7] == "tuningSystem")
        #expect(columns[8] == "centOffset")
        #expect(columns[9] == "isCorrect")
        #expect(columns[10] == "initialCentOffset")
        #expect(columns[11] == "userCentError")
        #expect(columns[12] == "tempoBPM")
        #expect(columns[13] == "offsetMs")
        #expect(columns[14] == "userOffsetMs")
    }

    @Test("first 12 columns match V1 layout for backward compatibility")
    func first12ColumnsMatchV1() async {
        let v1Columns = CSVExportSchema.headerRow.split(separator: ",").map(String.init)
        let v2Columns = CSVExportSchemaV2.headerRow.split(separator: ",").map(String.init)

        for i in 0..<12 {
            #expect(v2Columns[i] == v1Columns[i], "Column \(i) mismatch: V2=\(v2Columns[i]), V1=\(v1Columns[i])")
        }
    }

    @Test("V1 schema has exactly 12 columns")
    func v1SchemaHas12Columns() async {
        #expect(CSVExportSchema.allColumns.count == 12)
    }
}

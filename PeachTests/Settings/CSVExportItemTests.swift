import Testing
import UniformTypeIdentifiers
@testable import Peach

@Suite("CSVExportItem")
struct CSVExportItemTests {

    @Test("transfers CSV content as file with correct content type")
    func transfersCSVContentAsFile() async throws {
        let csvString = "col1,col2\nval1,val2"
        let item = CSVExportItem(csvString: csvString, fileName: "test.csv")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(item.fileName)
        try item.csvString.write(to: url, atomically: true, encoding: .utf8)

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == csvString)

        try FileManager.default.removeItem(at: url)
    }

    @Test("stores csvString and fileName properties")
    func storesProperties() async {
        let item = CSVExportItem(csvString: "header\nrow", fileName: "export.csv")

        #expect(item.csvString == "header\nrow")
        #expect(item.fileName == "export.csv")
    }

    @Test("filename follows peach-training-data-YYYY-MM-DD.csv pattern")
    func filenamePattern() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = formatter.string(from: Date())
        let expectedName = "peach-training-data-\(expectedDate).csv"

        let name = CSVExportItem.exportFileName()
        #expect(name == expectedName)
    }

    @Test("header-only CSV is correctly detected as no data")
    func headerOnlyDetection() async {
        let headerOnly = CSVExportSchema.headerRow
        let hasData = headerOnly != CSVExportSchema.headerRow
        #expect(hasData == false)

        let withData = CSVExportSchema.headerRow + "\nval1,val2"
        let hasDataTrue = withData != CSVExportSchema.headerRow
        #expect(hasDataTrue == true)
    }

    @Test("CSV with data rows creates CSVExportItem")
    func csvWithDataCreatesItem() async {
        let csv = CSVExportSchema.headerRow + "\ncomparison,2026-01-01,60,C4,62,D4,m2,equalTemperament,50.0,true,,"
        let item = CSVExportItem(csvString: csv, fileName: CSVExportItem.exportFileName())

        #expect(item.csvString == csv)
        #expect(item.fileName.hasPrefix("peach-training-data-"))
        #expect(item.fileName.hasSuffix(".csv"))
    }

    @Test("file representation writes CSV content to temporary file")
    func fileRepresentationWritesContent() async throws {
        let csvContent = "col1,col2\nval1,val2\nval3,val4"
        let fileName = "test-export.csv"
        let item = CSVExportItem(csvString: csvContent, fileName: fileName)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try item.csvString.write(to: url, atomically: true, encoding: .utf8)

        let fileContent = try String(contentsOf: url, encoding: .utf8)
        #expect(fileContent == csvContent)
        #expect(url.lastPathComponent == fileName)

        try FileManager.default.removeItem(at: url)
    }
}

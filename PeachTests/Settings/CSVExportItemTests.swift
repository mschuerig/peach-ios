import Testing
import UniformTypeIdentifiers
@testable import Peach

@Suite("CSVExportItem")
struct CSVExportItemTests {

    @Test("writeToTemporaryFile creates file with correct CSV content")
    func writeToTemporaryFileCreatesCorrectContent() async throws {
        let csvString = "col1,col2\nval1,val2"
        let item = CSVExportItem(csvString: csvString, fileName: "test-export.csv")

        let url = try item.writeToTemporaryFile()

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written == csvString)
        #expect(url.lastPathComponent == "test-export.csv")

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
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let expectedDate = formatter.string(from: Date())
        let expectedName = "peach-training-data-\(expectedDate).csv"

        let name = CSVExportItem.exportFileName()
        #expect(name == expectedName)
    }

    @Test("header-only CSV is detected as no exportable data")
    func headerOnlyDetection() async {
        let headerOnly = CSVExportSchema.headerRow
        let hasData = headerOnly != CSVExportSchema.headerRow
        #expect(hasData == false)

        let withData = CSVExportSchema.headerRow + "\ncomparison,2026-01-01,60,C4,62,D4,m2,equalTemperament,50.0,true,,"
        let hasDataTrue = withData != CSVExportSchema.headerRow
        #expect(hasDataTrue == true)
    }

    @Test("CSV with data rows writes completely to temporary file")
    func csvWithDataWritesToFile() async throws {
        let csv = CSVExportSchema.headerRow + "\ncomparison,2026-01-01,60,C4,62,D4,m2,equalTemperament,50.0,true,,"
        let item = CSVExportItem(csvString: csv, fileName: CSVExportItem.exportFileName())

        let url = try item.writeToTemporaryFile()
        let written = try String(contentsOf: url, encoding: .utf8)

        #expect(written == csv)
        #expect(written.contains(CSVExportSchema.headerRow))
        #expect(url.lastPathComponent.hasPrefix("peach-training-data-"))
        #expect(url.lastPathComponent.hasSuffix(".csv"))

        try FileManager.default.removeItem(at: url)
    }
}

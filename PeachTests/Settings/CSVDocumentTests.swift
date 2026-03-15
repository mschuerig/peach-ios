import SwiftUI
import Testing
@testable import Peach

@Suite("CSVDocument")
struct CSVDocumentTests {

    @Test("stores csvString property")
    func storesProperties() async {
        let doc = CSVDocument(csvString: "header\nrow")

        #expect(doc.csvString == "header\nrow")
    }

    @Test("filename follows peach-training-data-YYYY-MM-DD-HHmm.csv pattern")
    func filenamePattern() async {
        let date = createDate(year: 2026, month: 3, day: 15, hour: 14, minute: 32)
        let name = CSVDocument.exportFileName(for: date)

        #expect(name == "peach-training-data-2026-03-15-1432.csv")
    }

    @Test("conforms to Transferable protocol")
    func conformsToTransferable() async {
        let doc = CSVDocument(csvString: "test")
        let _: any Transferable = doc
    }

    @Test("export filename has .csv extension for Transferable file type preservation")
    func exportFileNameHasCSVExtension() async {
        let name = CSVDocument.exportFileName()
        #expect(name.hasSuffix(".csv"))
    }

    @Test("exportDate is captured at construction time and used in filename")
    func exportDateCapturedAtConstruction() async {
        let fixedDate = createDate(year: 2026, month: 1, day: 10, hour: 9, minute: 5)
        let doc = CSVDocument(csvString: "data", exportDate: fixedDate)

        #expect(doc.exportDate == fixedDate)

        let expectedFileName = CSVDocument.exportFileName(for: fixedDate)
        #expect(expectedFileName == "peach-training-data-2026-01-10-0905.csv")
    }

    @Test("exportDate defaults to current time when not specified")
    func exportDateDefaultsToCurrent() async {
        let before = Date()
        let doc = CSVDocument(csvString: "data")
        let after = Date()

        #expect(doc.exportDate >= before)
        #expect(doc.exportDate <= after)
    }

    @Test("CSV data round-trips through UTF-8 encoding")
    func csvDataRoundTrips() async {
        let csvString = "col1,col2\nval1,val2\nval3,val4"
        let doc = CSVDocument(csvString: csvString)

        let data = doc.csvString.data(using: .utf8)

        #expect(data != nil)
        let restored = data.flatMap { String(data: $0, encoding: .utf8) }
        #expect(restored == csvString)
    }

    private func createDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}

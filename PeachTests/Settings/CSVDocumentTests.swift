import SwiftUI
import Testing
import UniformTypeIdentifiers
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

    @Test("readableContentTypes contains commaSeparatedText")
    func readableContentTypes() async {
        #expect(CSVDocument.readableContentTypes.contains(.commaSeparatedText))
    }

    @Test("conforms to FileDocument protocol")
    func conformsToFileDocument() async {
        let doc = CSVDocument(csvString: "test")
        let _: any FileDocument = doc
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

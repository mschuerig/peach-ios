import CoreTransferable
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
        let name = CSVDocument.exportFileName()

        let regex = /peach-training-data-\d{4}-\d{2}-\d{2}-\d{4}\.csv/
        #expect(name.wholeMatch(of: regex) != nil,
                "Expected minute-precision filename, got: \(name)")
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

    @Test("CSV data round-trips through UTF-8 encoding")
    func csvDataRoundTrips() async {
        let csvString = "col1,col2\nval1,val2\nval3,val4"
        let doc = CSVDocument(csvString: csvString)

        let data = doc.csvString.data(using: .utf8)!
        let restored = String(data: data, encoding: .utf8)

        #expect(restored == csvString)
    }
}

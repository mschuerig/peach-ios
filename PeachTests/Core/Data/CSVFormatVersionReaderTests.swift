import Testing
import Foundation
@testable import Peach

@Suite("CSVFormatVersionReader")
struct CSVFormatVersionReaderTests {

    @Test("reads valid version 1 from metadata line")
    func readsValidVersion() async {
        let content = "# peach-export-format:1\nheader\ndata"
        let result = CSVFormatVersionReader.readVersion(from: content)

        switch result {
        case .success(let version, let remainingLines):
            #expect(version == 1)
            #expect(remainingLines == ["header", "data"])
        case .failure:
            Issue.record("Expected success but got error")
        }
    }

    @Test("reads higher version number")
    func readsHigherVersion() async {
        let content = "# peach-export-format:42\nheader\ndata"
        let result = CSVFormatVersionReader.readVersion(from: content)

        switch result {
        case .success(let version, let remainingLines):
            #expect(version == 42)
            #expect(remainingLines.count == 2)
        case .failure:
            Issue.record("Expected success but got error")
        }
    }

    @Test("returns missingVersion error when no metadata line")
    func missingVersionLine() async {
        let content = "header\ndata"
        let result = CSVFormatVersionReader.readVersion(from: content)

        switch result {
        case .success:
            Issue.record("Expected error but got success")
        case .failure(let error):
            if case .missingVersion = error {
                // Expected
            } else {
                Issue.record("Expected missingVersion error but got \(error)")
            }
        }
    }

    @Test("returns invalidFormatMetadata error for non-integer version")
    func malformedVersion() async {
        let content = "# peach-export-format:abc\nheader"
        let result = CSVFormatVersionReader.readVersion(from: content)

        switch result {
        case .success:
            Issue.record("Expected error but got success")
        case .failure(let error):
            if case .invalidFormatMetadata(let line) = error {
                #expect(line == "# peach-export-format:abc")
            } else {
                Issue.record("Expected invalidFormatMetadata error but got \(error)")
            }
        }
    }

    @Test("returns missingVersion error for empty input")
    func emptyInput() async {
        let result = CSVFormatVersionReader.readVersion(from: "")

        switch result {
        case .success:
            Issue.record("Expected error but got success")
        case .failure(let error):
            if case .missingVersion = error {
                // Expected
            } else {
                Issue.record("Expected missingVersion error but got \(error)")
            }
        }
    }

    @Test("preserves data lines after metadata line")
    func preservesDataLines() async {
        let header = CSVExportSchema.headerRow
        let dataRow = "pitchDiscrimination,2026-03-03T14:30:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let content = "# peach-export-format:1\n\(header)\n\(dataRow)"
        let result = CSVFormatVersionReader.readVersion(from: content)

        switch result {
        case .success(let version, let remainingLines):
            #expect(version == 1)
            #expect(remainingLines.count == 2)
            #expect(remainingLines[0] == header)
            #expect(remainingLines[1] == dataRow)
        case .failure:
            Issue.record("Expected success but got error")
        }
    }

    @Test("handles CRLF line endings")
    func handlesCRLFLineEndings() async {
        let content = "# peach-export-format:1\r\nheader\r\ndata"
        let result = CSVFormatVersionReader.readVersion(from: content)

        switch result {
        case .success(let version, let remainingLines):
            #expect(version == 1)
            #expect(remainingLines == ["header", "data"])
        case .failure:
            Issue.record("Expected success but got error")
        }
    }

    @Test("metadata line with only prefix and no version value")
    func prefixOnly() async {
        let content = "# peach-export-format:\nheader"
        let result = CSVFormatVersionReader.readVersion(from: content)

        switch result {
        case .success:
            Issue.record("Expected error but got success")
        case .failure(let error):
            if case .invalidFormatMetadata = error {
                // Expected
            } else {
                Issue.record("Expected invalidFormatMetadata error but got \(error)")
            }
        }
    }
}

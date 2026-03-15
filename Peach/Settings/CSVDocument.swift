import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument, Transferable {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let csvString: String

    init(csvString: String) {
        self.csvString = csvString
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        csvString = string
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = csvString.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { document in
            let fileName = exportFileName()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            guard let data = document.csvString.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try data.write(to: tempURL)
            return SentTransferredFile(tempURL)
        }
    }

    static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: Date())
        return "peach-training-data-\(timestamp).csv"
    }
}

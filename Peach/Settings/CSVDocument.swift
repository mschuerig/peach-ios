import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: Transferable {
    let csvString: String
    let exportDate: Date

    init(csvString: String, exportDate: Date = Date()) {
        self.csvString = csvString
        self.exportDate = exportDate
    }

    nonisolated static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { document in
            let fileName = exportFileName(for: document.exportDate)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            guard let data = document.csvString.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try data.write(to: tempURL)
            return SentTransferredFile(tempURL)
        }
    }

    static func exportFileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        return "peach-training-data-\(timestamp).csv"
    }
}

import CoreTransferable
import UniformTypeIdentifiers

struct CSVExportItem: Transferable {
    let csvString: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(item.fileName)
            try item.csvString.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }

    static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "peach-training-data-\(formatter.string(from: Date())).csv"
    }
}

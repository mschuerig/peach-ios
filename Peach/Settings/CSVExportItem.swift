import CoreTransferable
import UniformTypeIdentifiers

struct CSVExportItem: Transferable {
    let csvString: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            let url = try item.writeToTemporaryFile()
            return SentTransferredFile(url)
        }
    }

    func writeToTemporaryFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "peach-training-data-\(formatter.string(from: Date())).csv"
    }
}

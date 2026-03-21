import Foundation
import SwiftData

@Observable
final class TrainingDataTransferService {
    private let dataStore: TrainingDataStore
    private let onDataChanged: () -> Void

    private(set) var exportCSV: String?
    private(set) var exportFileURL: URL?
    private(set) var exportError: Error?

    init(
        dataStore: TrainingDataStore,
        onDataChanged: @escaping () -> Void
    ) {
        self.dataStore = dataStore
        self.onDataChanged = onDataChanged
    }

    // MARK: - Export

    func refreshExport() {
        do {
            let csv = try TrainingDataExporter.export(from: dataStore)
            let emptyExport = CSVExportSchemaV2.metadataLine + "\n" + CSVExportSchemaV2.headerRow
            if csv == emptyExport {
                exportCSV = nil
                exportFileURL = nil
            } else {
                exportCSV = csv
                exportFileURL = writeExportFile(csv)
            }
            exportError = nil
        } catch {
            exportCSV = nil
            exportFileURL = nil
            exportError = error
        }
    }

    private func writeExportFile(_ csv: String) -> URL? {
        let fileName = Self.exportFileName()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard let data = csv.data(using: .utf8) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func exportFileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        return "peach-training-data-\(timestamp).csv"
    }

    // MARK: - Import

    enum FileReadResult {
        case success(CSVImportParser.ImportResult)
        case failure(String)
    }

    func readFileForImport(url: URL) -> FileReadResult {
        guard url.startAccessingSecurityScopedResource() else {
            return .failure(String(localized: "Could not access the selected file."))
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let parseResult = CSVImportParser.parse(csvString)
            if parseResult.pitchDiscriminations.isEmpty && parseResult.pitchMatchings.isEmpty {
                if parseResult.errors.isEmpty {
                    return .failure(String(localized: "The file contains no valid training data."))
                } else {
                    let details = parseResult.errors.prefix(5).map { $0.errorDescription ?? "" }.joined(separator: "\n")
                    return .failure(String(localized: "The file contains no valid training data.") + "\n\n" + details)
                }
            }
            return .success(parseResult)
        } catch {
            return .failure(String(localized: "Could not read the selected file."))
        }
    }

    func performImport(
        parseResult: CSVImportParser.ImportResult,
        mode: TrainingDataImporter.ImportMode
    ) throws -> TrainingDataImporter.ImportSummary {
        let summary = try TrainingDataImporter.importData(parseResult, mode: mode, into: dataStore)

        onDataChanged()

        refreshExport()
        return summary
    }

    // MARK: - Preview

    static func preview() -> TrainingDataTransferService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, RhythmOffsetDetectionRecord.self, RhythmMatchingRecord.self, configurations: config) else {
            fatalError("Failed to create preview ModelContainer for TrainingDataTransferService")
        }
        let dataStore = TrainingDataStore(modelContext: container.mainContext)
        return TrainingDataTransferService(
            dataStore: dataStore,
            onDataChanged: { }
        )
    }

    // MARK: - Formatting

    func formatImportSummary(_ summary: TrainingDataImporter.ImportSummary) -> String {
        var parts: [String] = []
        let imported = summary.totalImported
        parts.append(String(localized: "\(imported) records imported"))
        if summary.totalSkipped > 0 {
            let skipped = summary.totalSkipped
            parts.append(String(localized: "\(skipped) duplicates skipped"))
        }
        if summary.parseErrorCount > 0 {
            let errors = summary.parseErrorCount
            parts.append(String(localized: "\(errors) errors"))
        }
        return parts.joined(separator: ", ") + "."
    }
}

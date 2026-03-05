import Foundation
import SwiftData

@Observable
final class TrainingDataTransferService {
    private let dataStore: TrainingDataStore
    private let onDataChanged: ([ComparisonRecord], [PitchMatchingRecord]) -> Void

    private(set) var exportCSV: String?
    private(set) var exportError: Error?

    init(
        dataStore: TrainingDataStore,
        onDataChanged: @escaping ([ComparisonRecord], [PitchMatchingRecord]) -> Void
    ) {
        self.dataStore = dataStore
        self.onDataChanged = onDataChanged
    }

    // MARK: - Export

    func refreshExport() {
        do {
            let csv = try TrainingDataExporter.export(from: dataStore)
            exportCSV = csv == CSVExportSchema.headerRow ? nil : csv
            exportError = nil
        } catch {
            exportCSV = nil
            exportError = error
        }
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
            if parseResult.comparisons.isEmpty && parseResult.pitchMatchings.isEmpty {
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

        let allComparisons = try dataStore.fetchAllComparisons()
        let allPitchMatchings = try dataStore.fetchAllPitchMatchings()

        onDataChanged(allComparisons, allPitchMatchings)

        refreshExport()
        return summary
    }

    // MARK: - Preview

    static func preview() -> TrainingDataTransferService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config) else {
            fatalError("Failed to create preview ModelContainer for TrainingDataTransferService")
        }
        let dataStore = TrainingDataStore(modelContext: container.mainContext)
        return TrainingDataTransferService(
            dataStore: dataStore,
            onDataChanged: { _, _ in }
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

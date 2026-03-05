import Foundation
import SwiftData

@Observable
final class TrainingDataTransferService {
    private let dataStore: TrainingDataStore
    private let profile: PerceptualProfile
    private let trendAnalyzer: TrendAnalyzer
    private let thresholdTimeline: ThresholdTimeline

    private(set) var exportCSV: String?
    private(set) var exportError: Error?

    init(
        dataStore: TrainingDataStore,
        profile: PerceptualProfile,
        trendAnalyzer: TrendAnalyzer,
        thresholdTimeline: ThresholdTimeline
    ) {
        self.dataStore = dataStore
        self.profile = profile
        self.trendAnalyzer = trendAnalyzer
        self.thresholdTimeline = thresholdTimeline
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
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
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

        profile.reset()
        profile.resetMatching()
        for record in allComparisons {
            profile.update(note: MIDINote(record.referenceNote), centOffset: abs(record.centOffset), isCorrect: record.isCorrect)
        }
        for record in allPitchMatchings {
            profile.updateMatching(note: MIDINote(record.referenceNote), centError: record.userCentError)
        }
        trendAnalyzer.rebuild(from: allComparisons)
        thresholdTimeline.rebuild(from: allComparisons)

        refreshExport()
        return summary
    }

    // MARK: - Preview

    static func preview() -> TrainingDataTransferService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
        let dataStore = TrainingDataStore(modelContext: container.mainContext)
        return TrainingDataTransferService(
            dataStore: dataStore,
            profile: PerceptualProfile(),
            trendAnalyzer: TrendAnalyzer(),
            thresholdTimeline: ThresholdTimeline()
        )
    }

    // MARK: - Formatting

    func formatImportSummary(_ summary: TrainingDataImporter.ImportSummary) -> String {
        var parts: [String] = []
        parts.append("\(summary.totalImported) " + String(localized: "records imported"))
        if summary.totalSkipped > 0 {
            parts.append("\(summary.totalSkipped) " + String(localized: "duplicates skipped"))
        }
        if summary.parseErrorCount > 0 {
            parts.append("\(summary.parseErrorCount) " + String(localized: "errors"))
        }
        return parts.joined(separator: ", ") + "."
    }
}

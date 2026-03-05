import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingDataTransferService")
struct TrainingDataTransferServiceTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
    }

    private func makeService() throws -> (
        service: TrainingDataTransferService,
        dataStore: TrainingDataStore,
        profile: PerceptualProfile
    ) {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let dataStore = TrainingDataStore(modelContext: context)
        let profile = PerceptualProfile()
        let trendAnalyzer = TrendAnalyzer()
        let thresholdTimeline = ThresholdTimeline()
        let service = TrainingDataTransferService(
            dataStore: dataStore,
            profile: profile,
            trendAnalyzer: trendAnalyzer,
            thresholdTimeline: thresholdTimeline
        )
        return (service, dataStore, profile)
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000 + minutesOffset * 60)
    }

    private func makeComparison(minutesOffset: Double = 0, referenceNote: Int = 60, targetNote: Int = 64) -> ComparisonRecord {
        ComparisonRecord(
            referenceNote: referenceNote,
            targetNote: targetNote,
            centOffset: 15.5,
            isCorrect: true,
            interval: 4,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate(minutesOffset: minutesOffset)
        )
    }

    private func makePitchMatching(minutesOffset: Double = 0, referenceNote: Int = 69, targetNote: Int = 72) -> PitchMatchingRecord {
        PitchMatchingRecord(
            referenceNote: referenceNote,
            targetNote: targetNote,
            initialCentOffset: 25.0,
            userCentError: 3.2,
            interval: 3,
            tuningSystem: "equalTemperament",
            timestamp: fixedDate(minutesOffset: minutesOffset)
        )
    }

    // MARK: - refreshExport Tests

    @Test("refreshExport returns CSV string when records exist")
    func refreshExportWithRecords() async throws {
        let (service, dataStore, _) = try makeService()
        try dataStore.save(makeComparison())
        service.refreshExport()
        #expect(service.exportCSV != nil)
        #expect(service.exportCSV!.contains("comparison"))
    }

    @Test("refreshExport returns nil when store is empty")
    func refreshExportEmpty() async throws {
        let (service, _, _) = try makeService()
        service.refreshExport()
        #expect(service.exportCSV == nil)
    }

    // MARK: - readFileForImport Tests

    @Test("readFileForImport returns success with valid CSV file")
    func readFileForImportSuccess() async throws {
        let (service, _, _) = try makeService()
        let csv = CSVExportSchema.headerRow + "\n" +
            "comparison,2025-03-01T10:00:00Z,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import-\(UUID()).csv")
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = service.readFileForImport(url: tempURL)
        if case .success(let parseResult) = result {
            #expect(parseResult.comparisons.count == 1)
        } else {
            Issue.record("Expected success but got failure")
        }
    }

    @Test("readFileForImport returns failure for empty data file")
    func readFileForImportEmptyData() async throws {
        let (service, _, _) = try makeService()
        let csv = CSVExportSchema.headerRow + "\n"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import-empty-\(UUID()).csv")
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = service.readFileForImport(url: tempURL)
        guard case .failure = result else {
            Issue.record("Expected failure but got success")
            return
        }
    }

    @Test("readFileForImport returns failure with error details for parse-only-errors file")
    func readFileForImportParseErrors() async throws {
        let (service, _, _) = try makeService()
        let csv = CSVExportSchema.headerRow + "\n" +
            "comparison,bad-date,60,C4,64,E4,M3,equalTemperament,15.5,true,,"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-import-errors-\(UUID()).csv")
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = service.readFileForImport(url: tempURL)
        guard case .failure(let message) = result else {
            Issue.record("Expected failure but got success")
            return
        }
        #expect(message.count > 0)
    }

    // MARK: - performImport Tests

    @Test("performImport with replace mode returns correct summary")
    func performImportReplace() async throws {
        let (service, dataStore, _) = try makeService()
        try dataStore.save(makeComparison(minutesOffset: 0))

        let parseResult = CSVImportParser.ImportResult(
            comparisons: [makeComparison(minutesOffset: 10), makeComparison(minutesOffset: 11)],
            pitchMatchings: [makePitchMatching(minutesOffset: 12)],
            errors: []
        )
        let summary = try service.performImport(parseResult: parseResult, mode: .replace)
        #expect(summary.comparisonsImported == 2)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(try dataStore.fetchAllComparisons().count == 2)
    }

    @Test("performImport with merge mode returns correct summary")
    func performImportMerge() async throws {
        let (service, dataStore, _) = try makeService()
        try dataStore.save(makeComparison(minutesOffset: 0))

        let parseResult = CSVImportParser.ImportResult(
            comparisons: [makeComparison(minutesOffset: 0), makeComparison(minutesOffset: 5)],
            pitchMatchings: [],
            errors: []
        )
        let summary = try service.performImport(parseResult: parseResult, mode: .merge)
        #expect(summary.comparisonsImported == 1)
        #expect(summary.comparisonsSkipped == 1)
    }

    @Test("performImport rebuilds profile after import")
    func performImportRebuildsProfile() async throws {
        let (service, _, profile) = try makeService()
        #expect(profile.overallMean == nil)

        let parseResult = CSVImportParser.ImportResult(
            comparisons: [makeComparison()],
            pitchMatchings: [],
            errors: []
        )
        _ = try service.performImport(parseResult: parseResult, mode: .replace)
        #expect(profile.overallMean != nil)
    }

    @Test("performImport refreshes export CSV after import")
    func performImportRefreshesExport() async throws {
        let (service, _, _) = try makeService()
        #expect(service.exportCSV == nil)

        let parseResult = CSVImportParser.ImportResult(
            comparisons: [makeComparison()],
            pitchMatchings: [],
            errors: []
        )
        _ = try service.performImport(parseResult: parseResult, mode: .replace)
        #expect(service.exportCSV != nil)
    }

    // MARK: - formatImportSummary Tests

    @Test("formatImportSummary with only imported records")
    func formatSummaryImportedOnly() async throws {
        let (service, _, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 8, pitchMatchingsImported: 2,
            comparisonsSkipped: 0, pitchMatchingsSkipped: 0, parseErrorCount: 0
        )
        let message = service.formatImportSummary(summary)
        #expect(message == "10 records imported.")
    }

    @Test("formatImportSummary with skipped duplicates")
    func formatSummaryWithSkipped() async throws {
        let (service, _, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 5, pitchMatchingsImported: 0,
            comparisonsSkipped: 3, pitchMatchingsSkipped: 0, parseErrorCount: 0
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("5 records imported"))
        #expect(message.contains("3 duplicates skipped"))
    }

    @Test("formatImportSummary with parse errors")
    func formatSummaryWithErrors() async throws {
        let (service, _, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 10, pitchMatchingsImported: 0,
            comparisonsSkipped: 3, pitchMatchingsSkipped: 0, parseErrorCount: 2
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("10 records imported"))
        #expect(message.contains("3 duplicates skipped"))
        #expect(message.contains("2 errors"))
    }
}

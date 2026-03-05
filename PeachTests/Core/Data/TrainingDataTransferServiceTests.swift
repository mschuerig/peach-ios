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

    private func makeService(
        onDataChanged: @escaping ([ComparisonRecord], [PitchMatchingRecord]) -> Void = { _, _ in }
    ) throws -> (
        service: TrainingDataTransferService,
        dataStore: TrainingDataStore
    ) {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let dataStore = TrainingDataStore(modelContext: context)
        let service = TrainingDataTransferService(
            dataStore: dataStore,
            onDataChanged: onDataChanged
        )
        return (service, dataStore)
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
        let (service, dataStore) = try makeService()
        try dataStore.save(makeComparison())
        service.refreshExport()
        #expect(service.exportCSV != nil)
        #expect(service.exportCSV!.contains("comparison"))
    }

    @Test("refreshExport returns nil when store is empty")
    func refreshExportEmpty() async throws {
        let (service, _) = try makeService()
        service.refreshExport()
        #expect(service.exportCSV == nil)
    }

    // MARK: - readFileForImport Tests

    // Note: readFileForImport requires security-scoped URLs (from fileImporter),
    // which cannot be created in unit tests. The underlying parsing logic is tested
    // via CSVImportParserTests. The file read + security scoping is an integration concern.

    @Test("readFileForImport returns failure for non-security-scoped URL")
    func readFileForImportNonSecurityScoped() async throws {
        let (service, _) = try makeService()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).csv")
        try "test".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = service.readFileForImport(url: tempURL)
        guard case .failure = result else {
            Issue.record("Expected failure for non-security-scoped URL")
            return
        }
    }

    // MARK: - performImport Tests

    @Test("performImport with replace mode returns correct summary")
    func performImportReplace() async throws {
        let (service, dataStore) = try makeService()
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
        let (service, dataStore) = try makeService()
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

    @Test("performImport calls onDataChanged callback")
    func performImportCallsOnDataChanged() async throws {
        var callbackComparisons: [ComparisonRecord]?
        var callbackPitchMatchings: [PitchMatchingRecord]?

        let (service, _) = try makeService { comparisons, pitchMatchings in
            callbackComparisons = comparisons
            callbackPitchMatchings = pitchMatchings
        }

        let parseResult = CSVImportParser.ImportResult(
            comparisons: [makeComparison()],
            pitchMatchings: [makePitchMatching()],
            errors: []
        )
        _ = try service.performImport(parseResult: parseResult, mode: .replace)

        #expect(callbackComparisons?.count == 1)
        #expect(callbackPitchMatchings?.count == 1)
    }

    @Test("performImport refreshes export CSV after import")
    func performImportRefreshesExport() async throws {
        let (service, _) = try makeService()
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
        let (service, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 8, pitchMatchingsImported: 2,
            comparisonsSkipped: 0, pitchMatchingsSkipped: 0, parseErrorCount: 0
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("10"))
        #expect(message.hasSuffix("."))
    }

    @Test("formatImportSummary with skipped duplicates")
    func formatSummaryWithSkipped() async throws {
        let (service, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 5, pitchMatchingsImported: 0,
            comparisonsSkipped: 3, pitchMatchingsSkipped: 0, parseErrorCount: 0
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("5"))
        #expect(message.contains("3"))
    }

    @Test("formatImportSummary with parse errors")
    func formatSummaryWithErrors() async throws {
        let (service, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 10, pitchMatchingsImported: 0,
            comparisonsSkipped: 3, pitchMatchingsSkipped: 0, parseErrorCount: 2
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("10"))
        #expect(message.contains("3"))
        #expect(message.contains("2"))
    }
}

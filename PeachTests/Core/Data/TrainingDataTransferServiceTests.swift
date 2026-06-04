import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingDataTransferService")
struct TrainingDataTransferServiceTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TrainingRecord.self, configurations: config)
    }

    private func makeService(
        onDataChanged: @escaping () -> Void = { }
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

    private func makeDiscriminationEntry(
        minutesOffset: Double = 0,
        referenceNote: Int = 60,
        targetNote: Int = 64
    ) -> (timestamp: Date, payload: PitchDiscriminationPayload) {
        (
            fixedDate(minutesOffset: minutesOffset),
            PitchDiscriminationPayload(
                referenceNote: referenceNote,
                targetNote: targetNote,
                centOffset: 15.5,
                isCorrect: true,
                interval: 4,
                tuningSystem: "equalTemperament"
            )
        )
    }

    private func makeMatchingEntry(
        minutesOffset: Double = 0,
        referenceNote: Int = 69,
        targetNote: Int = 72
    ) -> (timestamp: Date, payload: PitchMatchingPayload) {
        (
            fixedDate(minutesOffset: minutesOffset),
            PitchMatchingPayload(
                referenceNote: referenceNote,
                targetNote: targetNote,
                initialCentOffset: 25.0,
                userCentError: 3.2,
                interval: 3,
                tuningSystem: "equalTemperament"
            )
        )
    }

    private func envelope(for payload: any TrainingDisciplinePayload, timestamp: Date) throws -> TrainingRecord {
        try JSONEnvelope.encode(payload, timestamp: timestamp)
    }

    private func saveDiscrimination(
        _ store: TrainingDataStore,
        minutesOffset: Double = 0,
        referenceNote: Int = 60,
        targetNote: Int = 64
    ) throws {
        let entry = makeDiscriminationEntry(minutesOffset: minutesOffset, referenceNote: referenceNote, targetNote: targetNote)
        try store.save(envelope(for: entry.payload, timestamp: entry.timestamp))
    }

    private func makeImportResult(
        pitchDiscriminations: [(timestamp: Date, payload: PitchDiscriminationPayload)] = [],
        pitchMatchings: [(timestamp: Date, payload: PitchMatchingPayload)] = [],
        timingOffsetDetections: [(timestamp: Date, payload: TimingOffsetDetectionPayload)] = []
    ) -> CSVImportParser.ImportResult {
        var payloads: [String: [(timestamp: Date, payload: any TrainingDisciplinePayload)]] = [:]
        if !pitchDiscriminations.isEmpty {
            payloads["pitchDiscrimination"] = pitchDiscriminations.map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
        }
        if !pitchMatchings.isEmpty {
            payloads["pitchMatching"] = pitchMatchings.map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
        }
        if !timingOffsetDetections.isEmpty {
            payloads["rhythmOffsetDetection"] = timingOffsetDetections.map { ($0.timestamp, $0.payload as any TrainingDisciplinePayload) }
        }
        return CSVImportParser.ImportResult(payloads: payloads, errors: [])
    }

    // MARK: - exportFileName Tests

    @Test("export filename follows peach-training-data-YYYY-MM-DD-HHmm.csv pattern")
    func exportFileNamePattern() async {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        components.hour = 14
        components.minute = 32
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let name = TrainingDataTransferService.exportFileName(for: date)

        #expect(name == "peach-training-data-2026-03-15-1432.csv")
    }

    @Test("export filename has .csv extension")
    func exportFileNameHasCSVExtension() async {
        let name = TrainingDataTransferService.exportFileName()
        #expect(name.hasSuffix(".csv"))
    }

    // MARK: - refreshExport Tests

    @Test("refreshExport returns CSV string when records exist")
    func refreshExportWithRecords() async throws {
        let (service, dataStore) = try makeService()
        try saveDiscrimination(dataStore)
        service.refreshExport()
        let csv = try #require(service.exportCSV)
        #expect(csv.contains("pitchDiscrimination"))
    }

    @Test("refreshExport returns nil when store is empty")
    func refreshExportEmpty() async throws {
        let (service, _) = try makeService()
        service.refreshExport()
        #expect(service.exportCSV == nil)
    }

    @Test("refreshExport produces file URL when records exist")
    func refreshExportProducesFileURL() async throws {
        let (service, dataStore) = try makeService()
        try saveDiscrimination(dataStore)
        service.refreshExport()
        guard let url = service.exportFileURL else {
            Issue.record("Expected exportFileURL to be set")
            return
        }
        #expect(url.pathExtension == "csv")
        #expect(FileManager.default.fileExists(atPath: url.path()))
    }

    @Test("refreshExport sets file URL to nil when store is empty")
    func refreshExportFileURLNilWhenEmpty() async throws {
        let (service, _) = try makeService()
        service.refreshExport()
        #expect(service.exportFileURL == nil)
    }

    @Test("export file URL contains CSV data matching exportCSV")
    func exportFileURLContainsCSVData() async throws {
        let (service, dataStore) = try makeService()
        try saveDiscrimination(dataStore)
        service.refreshExport()
        guard let url = service.exportFileURL else {
            Issue.record("Expected exportFileURL to be set")
            return
        }
        let fileContent = try String(contentsOf: url, encoding: .utf8)
        #expect(fileContent == service.exportCSV)
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
        try saveDiscrimination(dataStore, minutesOffset: 0)

        let parseResult = makeImportResult(
            pitchDiscriminations: [
                makeDiscriminationEntry(minutesOffset: 10),
                makeDiscriminationEntry(minutesOffset: 11),
            ],
            pitchMatchings: [makeMatchingEntry(minutesOffset: 12)]
        )
        let summary = try service.performImport(parseResult: parseResult, mode: .replace)
        #expect(summary.imported(for: .intervalPitchDiscrimination) == 2)
        #expect(summary.imported(for: .intervalPitchMatching) == 1)
        #expect(try dataStore.fetchPayloads(PitchDiscriminationPayload.self).count == 2)
    }

    @Test("performImport with merge mode returns correct summary")
    func performImportMerge() async throws {
        let (service, dataStore) = try makeService()
        try saveDiscrimination(dataStore, minutesOffset: 0)

        let parseResult = makeImportResult(
            pitchDiscriminations: [
                makeDiscriminationEntry(minutesOffset: 0),
                makeDiscriminationEntry(minutesOffset: 5),
            ]
        )
        let summary = try service.performImport(parseResult: parseResult, mode: .merge)
        #expect(summary.imported(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 1)
    }

    @Test("performImport calls onDataChanged callback")
    func performImportCallsOnDataChanged() async throws {
        var callbackCalled = false

        let (service, _) = try makeService {
            callbackCalled = true
        }

        let parseResult = makeImportResult(
            pitchDiscriminations: [makeDiscriminationEntry()],
            pitchMatchings: [makeMatchingEntry()]
        )
        _ = try service.performImport(parseResult: parseResult, mode: .replace)

        #expect(callbackCalled)
    }

    @Test("performImport refreshes export CSV after import")
    func performImportRefreshesExport() async throws {
        let (service, _) = try makeService()
        #expect(service.exportCSV == nil)

        let parseResult = makeImportResult(
            pitchDiscriminations: [makeDiscriminationEntry()]
        )
        _ = try service.performImport(parseResult: parseResult, mode: .replace)
        #expect(service.exportCSV != nil)
    }

    // MARK: - formatImportSummary Tests

    @Test("formatImportSummary with only imported records")
    func formatSummaryImportedOnly() async throws {
        let (service, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            perDiscipline: [
                .intervalPitchDiscrimination: (imported: 8, skipped: 0),
                .intervalPitchMatching: (imported: 2, skipped: 0),
            ],
            parseErrorCount: 0
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("10"))
        #expect(message.hasSuffix("."))
    }

    @Test("formatImportSummary with skipped duplicates")
    func formatSummaryWithSkipped() async throws {
        let (service, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            perDiscipline: [
                .intervalPitchDiscrimination: (imported: 5, skipped: 3),
            ],
            parseErrorCount: 0
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("5"))
        #expect(message.contains("3"))
    }

    @Test("formatImportSummary with parse errors")
    func formatSummaryWithErrors() async throws {
        let (service, _) = try makeService()
        let summary = TrainingDataImporter.ImportSummary(
            perDiscipline: [
                .intervalPitchDiscrimination: (imported: 10, skipped: 3),
            ],
            parseErrorCount: 2
        )
        let message = service.formatImportSummary(summary)
        #expect(message.contains("10"))
        #expect(message.contains("3"))
        #expect(message.contains("2"))
    }

    // MARK: - Rhythm-Aware Import

    @Test("performImport with rhythm-only records returns correct summary")
    func performImportRhythmOnly() async throws {
        let (service, dataStore) = try makeService()

        let entry: (timestamp: Date, payload: TimingOffsetDetectionPayload) = (
            fixedDate(),
            TimingOffsetDetectionPayload(tempoBPM: 120, offsetMs: 5.3, isCorrect: true)
        )

        let parseResult = makeImportResult(timingOffsetDetections: [entry])
        let summary = try service.performImport(parseResult: parseResult, mode: .replace)
        #expect(summary.imported(for: .timingOffsetDetection) == 1)
        #expect(summary.totalImported == 1)
        #expect(try dataStore.fetchPayloads(TimingOffsetDetectionPayload.self).count == 1)
    }
}

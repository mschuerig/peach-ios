import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingDataExporter Tests")
struct TrainingDataExporterTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PitchComparisonRecord.self, PitchMatchingRecord.self, RhythmComparisonRecord.self, RhythmMatchingRecord.self, configurations: config)
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 3, day: 4, hour: 10, minute: 0, second: 0)
        let base = calendar.date(from: components)!
        return base.addingTimeInterval(minutesOffset * 60)
    }

    private func makeStore() throws -> TrainingDataStore {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        return TrainingDataStore(modelContext: context)
    }

    // MARK: - Mixed Record Tests

    @Test("export with mixed comparison and pitch matching records produces correctly sorted CSV")
    func exportMixedRecords() async throws {
        let store = try makeStore()

        let comparison = PitchComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let pitchMatching = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        try store.save(comparison)
        try store.save(pitchMatching)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 4)
        #expect(lines[0] == CSVExportSchema.metadataLine)
        #expect(lines[1] == CSVExportSchema.headerRow)
        #expect(!csv.hasSuffix("\n"))

        // Verify pitch matching row (earlier timestamp — first data row)
        let pmFields = lines[2].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(pmFields[0] == "pitchMatching")
        #expect(pmFields[2] == "69")
        #expect(pmFields[3] == "A4")
        #expect(pmFields[10] == "25.0")
        #expect(pmFields[11] == "3.2")

        // Verify comparison row (later timestamp — second data row)
        let compFields = lines[3].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        #expect(compFields[0] == "pitchComparison")
        #expect(compFields[2] == "60")
        #expect(compFields[3] == "C4")
        #expect(compFields[8] == "15.5")
        #expect(compFields[9] == "true")
    }

    // MARK: - Comparison Only Tests

    @Test("export with only comparison records")
    func exportComparisonOnly() async throws {
        let store = try makeStore()

        let record = PitchComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 3)
        #expect(lines[0] == CSVExportSchema.metadataLine)
        #expect(lines[1] == CSVExportSchema.headerRow)
        #expect(lines[2].hasPrefix("pitchComparison"))
    }

    // MARK: - Pitch Matching Only Tests

    @Test("export with only pitch matching records")
    func exportPitchMatchingOnly() async throws {
        let store = try makeStore()

        let record = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 3)
        #expect(lines[0] == CSVExportSchema.metadataLine)
        #expect(lines[1] == CSVExportSchema.headerRow)
        #expect(lines[2].hasPrefix("pitchMatching"))
    }

    // MARK: - Empty Store Tests

    @Test("export with no records returns metadata line and header row")
    func exportEmptyStore() async throws {
        let store = try makeStore()

        let csv = try TrainingDataExporter.export(from: store)

        #expect(csv == CSVExportSchema.metadataLine + "\n" + CSVExportSchema.headerRow)
    }

    // MARK: - Timestamp Ordering Tests

    @Test("timestamp ordering across mixed record types")
    func timestampOrdering() async throws {
        let store = try makeStore()

        let pm1 = PitchMatchingRecord(
            referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 1.0,
            interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let comp1 = PitchComparisonRecord(
            referenceNote: 60, targetNote: 62, centOffset: 5.0, isCorrect: true,
            interval: 2, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let pm2 = PitchMatchingRecord(
            referenceNote: 64, targetNote: 64, initialCentOffset: 20.0, userCentError: -2.0,
            interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 2)
        )
        let comp2 = PitchComparisonRecord(
            referenceNote: 67, targetNote: 72, centOffset: -10.0, isCorrect: false,
            interval: 5, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 3)
        )

        try store.save(pm1)
        try store.save(comp1)
        try store.save(pm2)
        try store.save(comp2)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 6)
        #expect(lines[2].hasPrefix("pitchMatching"))
        #expect(lines[3].hasPrefix("pitchComparison"))
        #expect(lines[4].hasPrefix("pitchMatching"))
        #expect(lines[5].hasPrefix("pitchComparison"))
    }

    // MARK: - Stable Sort Tests

    @Test("records with same timestamp maintain stable insertion order")
    func sameTimestampStableOrder() async throws {
        let store = try makeStore()

        let timestamp = fixedDate()
        let comparison = PitchComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        let pitchMatching = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        try store.save(comparison)
        try store.save(pitchMatching)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 4)
        #expect(lines[2].hasPrefix("pitchComparison"))
        #expect(lines[3].hasPrefix("pitchMatching"))
    }

    // MARK: - Header Row Tests

    @Test("CSV output starts with metadata line followed by header row")
    func csvStartsWithMetadataAndHeader() async throws {
        let store = try makeStore()

        let record = PitchComparisonRecord(
            referenceNote: 60, targetNote: 60, centOffset: 0.0, isCorrect: true,
            interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()
        )
        try store.save(record)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(!lines.isEmpty)
        #expect(lines[0] == CSVExportSchema.metadataLine)
        #expect(lines[1] == CSVExportSchema.headerRow)
    }

    // MARK: - Row Count Tests

    @Test("row count equals record count plus metadata and header")
    func rowCountEqualsRecordsPlusMetadataAndHeader() async throws {
        let store = try makeStore()

        let comp = PitchComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let pm1 = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        let pm2 = PitchMatchingRecord(
            referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: -1.5,
            interval: 0, tuningSystem: "justIntonation", timestamp: fixedDate(minutesOffset: 2)
        )

        try store.save(comp)
        try store.save(pm1)
        try store.save(pm2)

        let csv = try TrainingDataExporter.export(from: store)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.count == 5)
    }

    // MARK: - Round-Trip Test

    @Test("exported CSV can be imported back and produces matching records")
    func roundTripExportImport() async throws {
        let store = try makeStore()

        let comparison = PitchComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let pitchMatching = PitchMatchingRecord(
            referenceNote: 69, targetNote: 72, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 3, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1)
        )
        try store.save(comparison)
        try store.save(pitchMatching)

        let csv = try TrainingDataExporter.export(from: store)
        let result = CSVImportParser.parse(csv)

        #expect(result.errors.isEmpty)
        #expect(result.pitchComparisons.count == 1)
        #expect(result.pitchMatchings.count == 1)

        let importedComp = result.pitchComparisons[0]
        #expect(importedComp.referenceNote == 60)
        #expect(importedComp.targetNote == 64)
        #expect(importedComp.centOffset == 15.5)
        #expect(importedComp.isCorrect == true)
        #expect(importedComp.interval == 4)
        #expect(importedComp.tuningSystem == "equalTemperament")

        let importedPM = result.pitchMatchings[0]
        #expect(importedPM.referenceNote == 69)
        #expect(importedPM.targetNote == 72)
        #expect(importedPM.initialCentOffset == 25.0)
        #expect(importedPM.userCentError == 3.2)
    }
}

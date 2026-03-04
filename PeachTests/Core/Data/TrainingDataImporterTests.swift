import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingDataImporter")
struct TrainingDataImporterTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
    }

    private func makeStore() throws -> (TrainingDataStore, ModelContainer) {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        return (TrainingDataStore(modelContext: context), container)
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000 + minutesOffset * 60)
    }

    // MARK: - ImportMode Tests

    @Test("ImportMode has replace and merge cases")
    func importModeHasBothCases() async throws {
        let replace = TrainingDataImporter.ImportMode.replace
        let merge = TrainingDataImporter.ImportMode.merge
        #expect(replace != merge)
    }

    // MARK: - ImportSummary Tests

    @Test("ImportSummary stores all field values")
    func importSummaryFields() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 5,
            pitchMatchingsImported: 3,
            comparisonsSkipped: 2,
            pitchMatchingsSkipped: 1,
            parseErrorCount: 4
        )
        #expect(summary.comparisonsImported == 5)
        #expect(summary.pitchMatchingsImported == 3)
        #expect(summary.comparisonsSkipped == 2)
        #expect(summary.pitchMatchingsSkipped == 1)
        #expect(summary.parseErrorCount == 4)
    }

    @Test("ImportSummary totalImported sums comparisons and pitch matchings")
    func importSummaryTotalImported() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 5,
            pitchMatchingsImported: 3,
            comparisonsSkipped: 0,
            pitchMatchingsSkipped: 0,
            parseErrorCount: 0
        )
        #expect(summary.totalImported == 8)
    }

    @Test("ImportSummary totalSkipped sums comparisons and pitch matchings skipped")
    func importSummaryTotalSkipped() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            comparisonsImported: 0,
            pitchMatchingsImported: 0,
            comparisonsSkipped: 2,
            pitchMatchingsSkipped: 1,
            parseErrorCount: 0
        )
        #expect(summary.totalSkipped == 3)
    }

    // MARK: - Replace Mode Tests

    private func makeImportResult(
        comparisons: [ComparisonRecord] = [],
        pitchMatchings: [PitchMatchingRecord] = [],
        errors: [CSVImportError] = []
    ) -> CSVImportParser.ImportResult {
        CSVImportParser.ImportResult(
            comparisons: comparisons,
            pitchMatchings: pitchMatchings,
            errors: errors
        )
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

    @Test("replace mode deletes existing and inserts all imported")
    func replaceModeDeletesAndInserts() async throws {
        let (store, _) = try makeStore()

        // Pre-populate existing records
        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))
        #expect(try store.fetchAllComparisons().count == 1)
        #expect(try store.fetchAllPitchMatchings().count == 1)

        // Import new records
        let importResult = makeImportResult(
            comparisons: [makeComparison(minutesOffset: 10), makeComparison(minutesOffset: 11)],
            pitchMatchings: [makePitchMatching(minutesOffset: 12)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.comparisonsImported == 2)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.comparisonsSkipped == 0)
        #expect(summary.pitchMatchingsSkipped == 0)

        // Verify only imported records exist
        let comparisons = try store.fetchAllComparisons()
        let pitchMatchings = try store.fetchAllPitchMatchings()
        #expect(comparisons.count == 2)
        #expect(pitchMatchings.count == 1)
    }

    @Test("replace with empty import deletes all existing")
    func replaceModeEmptyImport() async throws {
        let (store, _) = try makeStore()

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .replace, into: store)

        #expect(summary.comparisonsImported == 0)
        #expect(summary.pitchMatchingsImported == 0)

        let comparisons = try store.fetchAllComparisons()
        let pitchMatchings = try store.fetchAllPitchMatchings()
        #expect(comparisons.count == 0)
        #expect(pitchMatchings.count == 0)
    }

    @Test("replace mode passes through parse error count")
    func replaceModePassesThroughErrors() async throws {
        let (store, _) = try makeStore()

        let errors: [CSVImportError] = [
            .invalidRowData(row: 1, column: "test", value: "bad", reason: "bad"),
            .invalidRowData(row: 2, column: "test", value: "bad", reason: "bad")
        ]
        let importResult = makeImportResult(
            comparisons: [makeComparison()],
            errors: errors
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.parseErrorCount == 2)
        #expect(summary.comparisonsImported == 1)
    }

    // MARK: - Merge Mode Tests

    @Test("merge inserts only non-duplicate comparisons")
    func mergeInsertNonDuplicateComparison() async throws {
        let (store, _) = try makeStore()

        // Existing record
        try store.save(makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64))

        // Import: one duplicate (same timestamp+ref+target+type), one new
        let importResult = makeImportResult(
            comparisons: [
                makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64),
                makeComparison(minutesOffset: 5, referenceNote: 60, targetNote: 64)
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.comparisonsImported == 1)
        #expect(summary.comparisonsSkipped == 1)

        let comparisons = try store.fetchAllComparisons()
        #expect(comparisons.count == 2)
    }

    @Test("merge inserts only non-duplicate pitch matchings")
    func mergeInsertNonDuplicatePitchMatching() async throws {
        let (store, _) = try makeStore()

        try store.save(makePitchMatching(minutesOffset: 0, referenceNote: 69, targetNote: 72))

        let importResult = makeImportResult(
            pitchMatchings: [
                makePitchMatching(minutesOffset: 0, referenceNote: 69, targetNote: 72),
                makePitchMatching(minutesOffset: 5, referenceNote: 69, targetNote: 72)
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.pitchMatchingsSkipped == 1)

        let pitchMatchings = try store.fetchAllPitchMatchings()
        #expect(pitchMatchings.count == 2)
    }

    @Test("merge does not modify existing records")
    func mergeDoesNotModifyExisting() async throws {
        let (store, _) = try makeStore()

        let existing = ComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        try store.save(existing)

        // Import a duplicate with different centOffset
        let duplicate = ComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 99.9, isCorrect: false,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let importResult = makeImportResult(comparisons: [duplicate])

        _ = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        let comparisons = try store.fetchAllComparisons()
        #expect(comparisons.count == 1)
        #expect(comparisons[0].centOffset == 15.5)
        #expect(comparisons[0].isCorrect == true)
    }

    @Test("merge with all duplicates imports zero")
    func mergeAllDuplicates() async throws {
        let (store, _) = try makeStore()

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))

        let importResult = makeImportResult(
            comparisons: [makeComparison(minutesOffset: 0)],
            pitchMatchings: [makePitchMatching(minutesOffset: 1)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.totalImported == 0)
        #expect(summary.comparisonsSkipped == 1)
        #expect(summary.pitchMatchingsSkipped == 1)
    }

    @Test("merge with no duplicates imports all")
    func mergeNoDuplicates() async throws {
        let (store, _) = try makeStore()

        let importResult = makeImportResult(
            comparisons: [makeComparison(minutesOffset: 0), makeComparison(minutesOffset: 1)],
            pitchMatchings: [makePitchMatching(minutesOffset: 2)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.comparisonsImported == 2)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.totalSkipped == 0)
    }

    @Test("merge with mixed duplicates reports correct counts")
    func mergeMixedDuplicates() async throws {
        let (store, _) = try makeStore()

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))

        let importResult = makeImportResult(
            comparisons: [
                makeComparison(minutesOffset: 0),
                makeComparison(minutesOffset: 5)
            ],
            pitchMatchings: [
                makePitchMatching(minutesOffset: 1),
                makePitchMatching(minutesOffset: 6)
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.comparisonsImported == 1)
        #expect(summary.comparisonsSkipped == 1)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.pitchMatchingsSkipped == 1)

        #expect(try store.fetchAllComparisons().count == 2)
        #expect(try store.fetchAllPitchMatchings().count == 2)
    }

    // MARK: - Edge Case Tests

    @Test("empty import returns zero summary for replace mode")
    func emptyImportReplace() async throws {
        let (store, _) = try makeStore()

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .replace, into: store)

        #expect(summary.comparisonsImported == 0)
        #expect(summary.pitchMatchingsImported == 0)
        #expect(summary.comparisonsSkipped == 0)
        #expect(summary.pitchMatchingsSkipped == 0)
        #expect(summary.parseErrorCount == 0)
    }

    @Test("empty import returns zero summary for merge mode")
    func emptyImportMerge() async throws {
        let (store, _) = try makeStore()

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .merge, into: store)

        #expect(summary.comparisonsImported == 0)
        #expect(summary.pitchMatchingsImported == 0)
        #expect(summary.comparisonsSkipped == 0)
        #expect(summary.pitchMatchingsSkipped == 0)
        #expect(summary.parseErrorCount == 0)
    }

    @Test("import with only parse errors returns error count in summary")
    func onlyParseErrors() async throws {
        let (store, _) = try makeStore()

        let errors: [CSVImportError] = [
            .invalidRowData(row: 1, column: "test", value: "bad", reason: "bad"),
            .invalidRowData(row: 2, column: "test", value: "bad", reason: "bad"),
            .invalidRowData(row: 3, column: "test", value: "bad", reason: "bad")
        ]
        let importResult = makeImportResult(errors: errors)

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.parseErrorCount == 3)
        #expect(summary.totalImported == 0)
        #expect(summary.totalSkipped == 0)
    }

    @Test("records with identical timestamps but different training types are not duplicates")
    func sameTimestampDifferentType() async throws {
        let (store, _) = try makeStore()

        let timestamp = fixedDate()
        // Existing comparison
        let existing = ComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        try store.save(existing)

        // Import pitch matching with same timestamp, ref note, target note
        let imported = PitchMatchingRecord(
            referenceNote: 60, targetNote: 64, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        let importResult = makeImportResult(pitchMatchings: [imported])

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.pitchMatchingsSkipped == 0)
    }

    @Test("records with identical timestamps and training type but different notes are not duplicates")
    func sameTimestampDifferentNotes() async throws {
        let (store, _) = try makeStore()

        let timestamp = fixedDate()
        // Existing comparison with ref=60, target=64
        try store.save(ComparisonRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        ))

        // Import comparison with same timestamp but different notes
        let importResult = makeImportResult(comparisons: [
            ComparisonRecord(
                referenceNote: 60, targetNote: 67, centOffset: 10.0, isCorrect: false,
                interval: 7, tuningSystem: "equalTemperament", timestamp: timestamp
            ),
            ComparisonRecord(
                referenceNote: 65, targetNote: 64, centOffset: 5.0, isCorrect: true,
                interval: 1, tuningSystem: "equalTemperament", timestamp: timestamp
            )
        ])

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.comparisonsImported == 2)
        #expect(summary.comparisonsSkipped == 0)
        #expect(try store.fetchAllComparisons().count == 3)
    }
}

import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingDataImporter")
struct TrainingDataImporterTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, RhythmOffsetDetectionRecord.self, ContinuousRhythmMatchingRecord.self, configurations: config)
    }

    private func makeStore() throws -> TrainingDataStore {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        return TrainingDataStore(modelContext: context)
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000 + minutesOffset * 60)
    }

    // MARK: - ImportSummary Tests

    @Test("ImportSummary stores all field values")
    func importSummaryFields() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            pitchDiscriminationsImported: 5,
            pitchMatchingsImported: 3,
            rhythmOffsetDetectionsImported: 0,
            continuousRhythmMatchingsImported: 0,
            pitchDiscriminationsSkipped: 2,
            pitchMatchingsSkipped: 1,
            rhythmOffsetDetectionsSkipped: 0,
            continuousRhythmMatchingsSkipped: 0,
            parseErrorCount: 4
        )
        #expect(summary.pitchDiscriminationsImported == 5)
        #expect(summary.pitchMatchingsImported == 3)
        #expect(summary.pitchDiscriminationsSkipped == 2)
        #expect(summary.pitchMatchingsSkipped == 1)
        #expect(summary.parseErrorCount == 4)
    }

    @Test("ImportSummary totalImported sums comparisons and pitch matchings")
    func importSummaryTotalImported() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            pitchDiscriminationsImported: 5,
            pitchMatchingsImported: 3,
            rhythmOffsetDetectionsImported: 0,
            continuousRhythmMatchingsImported: 0,
            pitchDiscriminationsSkipped: 0,
            pitchMatchingsSkipped: 0,
            rhythmOffsetDetectionsSkipped: 0,
            continuousRhythmMatchingsSkipped: 0,
            parseErrorCount: 0
        )
        #expect(summary.totalImported == 8)
    }

    @Test("ImportSummary totalSkipped sums comparisons and pitch matchings skipped")
    func importSummaryTotalSkipped() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            pitchDiscriminationsImported: 0,
            pitchMatchingsImported: 0,
            rhythmOffsetDetectionsImported: 0,
            continuousRhythmMatchingsImported: 0,
            pitchDiscriminationsSkipped: 2,
            pitchMatchingsSkipped: 1,
            rhythmOffsetDetectionsSkipped: 0,
            continuousRhythmMatchingsSkipped: 0,
            parseErrorCount: 0
        )
        #expect(summary.totalSkipped == 3)
    }

    // MARK: - Replace Mode Tests

    private func makeImportResult(
        pitchDiscriminations: [PitchDiscriminationRecord] = [],
        pitchMatchings: [PitchMatchingRecord] = [],
        rhythmOffsetDetections: [RhythmOffsetDetectionRecord] = [],
        continuousRhythmMatchings: [ContinuousRhythmMatchingRecord] = [],
        errors: [CSVImportError] = []
    ) -> CSVImportParser.ImportResult {
        CSVImportParser.ImportResult(
            pitchDiscriminations: pitchDiscriminations,
            pitchMatchings: pitchMatchings,
            rhythmOffsetDetections: rhythmOffsetDetections,
            continuousRhythmMatchings: continuousRhythmMatchings,
            errors: errors
        )
    }

    private func makeComparison(minutesOffset: Double = 0, referenceNote: Int = 60, targetNote: Int = 64) -> PitchDiscriminationRecord {
        PitchDiscriminationRecord(
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
        let store = try makeStore()

        // Pre-populate existing records
        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))
        #expect(try store.fetchAllPitchDiscriminations().count == 1)
        #expect(try store.fetchAllPitchMatchings().count == 1)

        // Import new records
        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 10), makeComparison(minutesOffset: 11)],
            pitchMatchings: [makePitchMatching(minutesOffset: 12)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.pitchDiscriminationsImported == 2)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.pitchDiscriminationsSkipped == 0)
        #expect(summary.pitchMatchingsSkipped == 0)

        // Verify only imported records exist
        let comparisons = try store.fetchAllPitchDiscriminations()
        let pitchMatchings = try store.fetchAllPitchMatchings()
        #expect(comparisons.count == 2)
        #expect(pitchMatchings.count == 1)
    }

    @Test("replace with empty import deletes all existing")
    func replaceModeEmptyImport() async throws {
        let store = try makeStore()

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .replace, into: store)

        #expect(summary.pitchDiscriminationsImported == 0)
        #expect(summary.pitchMatchingsImported == 0)

        let comparisons = try store.fetchAllPitchDiscriminations()
        let pitchMatchings = try store.fetchAllPitchMatchings()
        #expect(comparisons.count == 0)
        #expect(pitchMatchings.count == 0)
    }

    @Test("replace mode passes through parse error count")
    func replaceModePassesThroughErrors() async throws {
        let store = try makeStore()

        let errors: [CSVImportError] = [
            .invalidRowData(row: 1, column: "test", value: "bad", reason: "bad"),
            .invalidRowData(row: 2, column: "test", value: "bad", reason: "bad")
        ]
        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison()],
            errors: errors
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.parseErrorCount == 2)
        #expect(summary.pitchDiscriminationsImported == 1)
    }

    // MARK: - Merge Mode Tests

    @Test("merge inserts only non-duplicate comparisons")
    func mergeInsertNonDuplicateComparison() async throws {
        let store = try makeStore()

        // Existing record
        try store.save(makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64))

        // Import: one duplicate (same timestamp+ref+target+type), one new
        let importResult = makeImportResult(
            pitchDiscriminations: [
                makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64),
                makeComparison(minutesOffset: 5, referenceNote: 60, targetNote: 64)
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchDiscriminationsImported == 1)
        #expect(summary.pitchDiscriminationsSkipped == 1)

        let comparisons = try store.fetchAllPitchDiscriminations()
        #expect(comparisons.count == 2)
    }

    @Test("merge inserts only non-duplicate pitch matchings")
    func mergeInsertNonDuplicatePitchMatching() async throws {
        let store = try makeStore()

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
        let store = try makeStore()

        let existing = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        try store.save(existing)

        // Import a duplicate with different centOffset
        let duplicate = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 99.9, isCorrect: false,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let importResult = makeImportResult(pitchDiscriminations: [duplicate])

        _ = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        let comparisons = try store.fetchAllPitchDiscriminations()
        #expect(comparisons.count == 1)
        #expect(comparisons[0].centOffset == 15.5)
        #expect(comparisons[0].isCorrect == true)
    }

    @Test("merge with all duplicates imports zero")
    func mergeAllDuplicates() async throws {
        let store = try makeStore()

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))

        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 0)],
            pitchMatchings: [makePitchMatching(minutesOffset: 1)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.totalImported == 0)
        #expect(summary.pitchDiscriminationsSkipped == 1)
        #expect(summary.pitchMatchingsSkipped == 1)
    }

    @Test("merge with no duplicates imports all")
    func mergeNoDuplicates() async throws {
        let store = try makeStore()

        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 0), makeComparison(minutesOffset: 1)],
            pitchMatchings: [makePitchMatching(minutesOffset: 2)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchDiscriminationsImported == 2)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.totalSkipped == 0)
    }

    @Test("merge with mixed duplicates reports correct counts")
    func mergeMixedDuplicates() async throws {
        let store = try makeStore()

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))

        let importResult = makeImportResult(
            pitchDiscriminations: [
                makeComparison(minutesOffset: 0),
                makeComparison(minutesOffset: 5)
            ],
            pitchMatchings: [
                makePitchMatching(minutesOffset: 1),
                makePitchMatching(minutesOffset: 6)
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchDiscriminationsImported == 1)
        #expect(summary.pitchDiscriminationsSkipped == 1)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.pitchMatchingsSkipped == 1)

        #expect(try store.fetchAllPitchDiscriminations().count == 2)
        #expect(try store.fetchAllPitchMatchings().count == 2)
    }

    // MARK: - Edge Case Tests

    @Test("empty import returns zero summary for replace mode")
    func emptyImportReplace() async throws {
        let store = try makeStore()

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .replace, into: store)

        #expect(summary.pitchDiscriminationsImported == 0)
        #expect(summary.pitchMatchingsImported == 0)
        #expect(summary.pitchDiscriminationsSkipped == 0)
        #expect(summary.pitchMatchingsSkipped == 0)
        #expect(summary.parseErrorCount == 0)
    }

    @Test("empty import returns zero summary for merge mode")
    func emptyImportMerge() async throws {
        let store = try makeStore()

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .merge, into: store)

        #expect(summary.pitchDiscriminationsImported == 0)
        #expect(summary.pitchMatchingsImported == 0)
        #expect(summary.pitchDiscriminationsSkipped == 0)
        #expect(summary.pitchMatchingsSkipped == 0)
        #expect(summary.parseErrorCount == 0)
    }

    @Test("import with only parse errors returns error count in summary")
    func onlyParseErrors() async throws {
        let store = try makeStore()

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

    @Test("merge deduplicates identical records within the same import file")
    func mergeDeduplicatesWithinImportFile() async throws {
        let store = try makeStore()

        // Import two identical comparison records in the same batch
        let importResult = makeImportResult(
            pitchDiscriminations: [
                makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64),
                makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64)
            ],
            pitchMatchings: [
                makePitchMatching(minutesOffset: 1, referenceNote: 69, targetNote: 72),
                makePitchMatching(minutesOffset: 1, referenceNote: 69, targetNote: 72)
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchDiscriminationsImported == 1)
        #expect(summary.pitchDiscriminationsSkipped == 1)
        #expect(summary.pitchMatchingsImported == 1)
        #expect(summary.pitchMatchingsSkipped == 1)
        #expect(try store.fetchAllPitchDiscriminations().count == 1)
        #expect(try store.fetchAllPitchMatchings().count == 1)
    }

    @Test("records with identical timestamps but different training types are not duplicates")
    func sameTimestampDifferentType() async throws {
        let store = try makeStore()

        let timestamp = fixedDate()
        // Existing comparison
        let existing = PitchDiscriminationRecord(
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
        let store = try makeStore()

        let timestamp = fixedDate()
        // Existing comparison with ref=60, target=64
        try store.save(PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        ))

        // Import comparison with same timestamp but different notes
        let importResult = makeImportResult(pitchDiscriminations: [
            PitchDiscriminationRecord(
                referenceNote: 60, targetNote: 67, centOffset: 10.0, isCorrect: false,
                interval: 7, tuningSystem: "equalTemperament", timestamp: timestamp
            ),
            PitchDiscriminationRecord(
                referenceNote: 65, targetNote: 64, centOffset: 5.0, isCorrect: true,
                interval: 1, tuningSystem: "equalTemperament", timestamp: timestamp
            )
        ])

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchDiscriminationsImported == 2)
        #expect(summary.pitchDiscriminationsSkipped == 0)
        #expect(try store.fetchAllPitchDiscriminations().count == 3)
    }

    // MARK: - CSV Round-Trip Duplicate Detection

    @Test("merge detects duplicates after export-import round-trip with sub-second timestamps")
    func mergeDetectsDuplicatesAfterRoundTrip() async throws {
        let store = try makeStore()

        // Record with sub-second precision (like Date() produces)
        let timestamp = Date(timeIntervalSinceReferenceDate: 794_394_000.999)
        let record = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        try store.save(record)

        // Simulate export → import: format to ISO8601 without fractional seconds, parse back
        let exported = timestamp.formatted(.iso8601)
        let reimported = try Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(exported)

        let importedRecord = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: reimported
        )
        let importResult = makeImportResult(pitchDiscriminations: [importedRecord])

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.pitchDiscriminationsImported == 0)
        #expect(summary.pitchDiscriminationsSkipped == 1)
        #expect(try store.fetchAllPitchDiscriminations().count == 1)
    }

    // MARK: - Rhythm Record Helpers

    private func makeRhythmOffsetDetection(minutesOffset: Double = 0, tempoBPM: Int = 120) -> RhythmOffsetDetectionRecord {
        RhythmOffsetDetectionRecord(
            tempoBPM: tempoBPM,
            offsetMs: 5.3,
            isCorrect: true,
            timestamp: fixedDate(minutesOffset: minutesOffset)
        )
    }

    // MARK: - Rhythm Replace Mode

    @Test("replace mode inserts rhythm records alongside pitch records")
    func replaceModeInsertsRhythmRecords() async throws {
        let store = try makeStore()

        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 0)],
            rhythmOffsetDetections: [makeRhythmOffsetDetection(minutesOffset: 1)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.pitchDiscriminationsImported == 1)
        #expect(summary.rhythmOffsetDetectionsImported == 1)
        #expect(try store.fetchAllPitchDiscriminations().count == 1)
        #expect(try store.fetchAllRhythmOffsetDetections().count == 1)
    }

    @Test("replace mode replaces existing rhythm records")
    func replaceModeReplacesExistingRhythm() async throws {
        let store = try makeStore()

        try store.save(makeRhythmOffsetDetection(minutesOffset: 0))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [makeRhythmOffsetDetection(minutesOffset: 10), makeRhythmOffsetDetection(minutesOffset: 11)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.rhythmOffsetDetectionsImported == 2)
        #expect(try store.fetchAllRhythmOffsetDetections().count == 2)
    }

    // MARK: - Rhythm Merge Mode

    @Test("merge inserts only non-duplicate rhythm offset detections")
    func mergeInsertNonDuplicateRhythmOffset() async throws {
        let store = try makeStore()

        try store.save(makeRhythmOffsetDetection(minutesOffset: 0, tempoBPM: 120))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [
                makeRhythmOffsetDetection(minutesOffset: 0, tempoBPM: 120),
                makeRhythmOffsetDetection(minutesOffset: 5, tempoBPM: 120),
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.rhythmOffsetDetectionsImported == 1)
        #expect(summary.rhythmOffsetDetectionsSkipped == 1)
        #expect(try store.fetchAllRhythmOffsetDetections().count == 2)
    }

    @Test("rhythm records with same timestamp but different tempo are not duplicates")
    func sameTimestampDifferentTempoNotDuplicate() async throws {
        let store = try makeStore()

        try store.save(makeRhythmOffsetDetection(minutesOffset: 0, tempoBPM: 120))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [makeRhythmOffsetDetection(minutesOffset: 0, tempoBPM: 90)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.rhythmOffsetDetectionsImported == 1)
        #expect(summary.rhythmOffsetDetectionsSkipped == 0)
    }

    @Test("merge deduplicates identical rhythm records within the same import file")
    func mergeDeduplicatesRhythmWithinFile() async throws {
        let store = try makeStore()

        let importResult = makeImportResult(
            rhythmOffsetDetections: [
                makeRhythmOffsetDetection(minutesOffset: 0, tempoBPM: 120),
                makeRhythmOffsetDetection(minutesOffset: 0, tempoBPM: 120),
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.rhythmOffsetDetectionsImported == 1)
        #expect(summary.rhythmOffsetDetectionsSkipped == 1)
    }

    // MARK: - ImportSummary Totals with Rhythm

    @Test("totalImported includes rhythm records")
    func totalImportedIncludesRhythm() async throws {
        let store = try makeStore()

        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 0)],
            rhythmOffsetDetections: [makeRhythmOffsetDetection(minutesOffset: 1)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.totalImported == 2)
    }

    @Test("totalSkipped includes rhythm records")
    func totalSkippedIncludesRhythm() async throws {
        let store = try makeStore()

        try store.save(makeRhythmOffsetDetection(minutesOffset: 0))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [makeRhythmOffsetDetection(minutesOffset: 0)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.totalSkipped == 1)
        #expect(summary.totalImported == 0)
    }
}

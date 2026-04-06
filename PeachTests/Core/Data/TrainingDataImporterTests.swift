import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TrainingDataImporter")
struct TrainingDataImporterTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, TimingOffsetDetectionRecord.self, ContinuousRhythmMatchingRecord.self, configurations: config)
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

    @Test("ImportSummary stores per-discipline values")
    func importSummaryFields() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            perDiscipline: [
                .intervalPitchDiscrimination: (imported: 5, skipped: 2),
                .intervalPitchMatching: (imported: 3, skipped: 1),
            ],
            parseErrorCount: 4
        )
        #expect(summary.imported(for: .intervalPitchDiscrimination) == 5)
        #expect(summary.imported(for: .intervalPitchMatching) == 3)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 2)
        #expect(summary.skipped(for: .intervalPitchMatching) == 1)
        #expect(summary.parseErrorCount == 4)
    }

    @Test("ImportSummary totalImported sums all disciplines")
    func importSummaryTotalImported() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            perDiscipline: [
                .intervalPitchDiscrimination: (imported: 5, skipped: 0),
                .intervalPitchMatching: (imported: 3, skipped: 0),
            ],
            parseErrorCount: 0
        )
        #expect(summary.totalImported == 8)
    }

    @Test("ImportSummary totalSkipped sums all disciplines")
    func importSummaryTotalSkipped() async throws {
        let summary = TrainingDataImporter.ImportSummary(
            perDiscipline: [
                .intervalPitchDiscrimination: (imported: 0, skipped: 2),
                .intervalPitchMatching: (imported: 0, skipped: 1),
            ],
            parseErrorCount: 0
        )
        #expect(summary.totalSkipped == 3)
    }

    // MARK: - Import Result Helpers

    private func makeImportResult(
        pitchDiscriminations: [PitchDiscriminationRecord] = [],
        pitchMatchings: [PitchMatchingRecord] = [],
        rhythmOffsetDetections: [TimingOffsetDetectionRecord] = [],
        continuousRhythmMatchings: [ContinuousRhythmMatchingRecord] = [],
        errors: [CSVImportError] = []
    ) -> CSVImportParser.ImportResult {
        var records: [String: [any PersistentModel]] = [:]
        if !pitchDiscriminations.isEmpty { records["pitchDiscrimination"] = pitchDiscriminations }
        if !pitchMatchings.isEmpty { records["pitchMatching"] = pitchMatchings }
        if !rhythmOffsetDetections.isEmpty { records["rhythmOffsetDetection"] = rhythmOffsetDetections }
        if !continuousRhythmMatchings.isEmpty { records["continuousRhythmMatching"] = continuousRhythmMatchings }
        return CSVImportParser.ImportResult(records: records, errors: errors)
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

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))
        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 1)
        #expect(try store.fetchAllSorted(PitchMatchingRecord.self).count == 1)

        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 10), makeComparison(minutesOffset: 11)],
            pitchMatchings: [makePitchMatching(minutesOffset: 12)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 2)
        #expect(summary.imported(for: .intervalPitchMatching) == 1)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 0)
        #expect(summary.skipped(for: .intervalPitchMatching) == 0)

        let comparisons = try store.fetchAllSorted(PitchDiscriminationRecord.self)
        let pitchMatchings = try store.fetchAllSorted(PitchMatchingRecord.self)
        #expect(comparisons.count == 2)
        #expect(pitchMatchings.count == 1)
    }

    @Test("replace with empty import deletes all existing")
    func replaceModeEmptyImport() async throws {
        let store = try makeStore()

        try store.save(makeComparison(minutesOffset: 0))
        try store.save(makePitchMatching(minutesOffset: 1))

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .replace, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 0)
        #expect(summary.imported(for: .intervalPitchMatching) == 0)

        let comparisons = try store.fetchAllSorted(PitchDiscriminationRecord.self)
        let pitchMatchings = try store.fetchAllSorted(PitchMatchingRecord.self)
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
        #expect(summary.imported(for: .intervalPitchDiscrimination) == 1)
    }

    // MARK: - Merge Mode Tests

    @Test("merge inserts only non-duplicate comparisons")
    func mergeInsertNonDuplicateComparison() async throws {
        let store = try makeStore()

        try store.save(makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64))

        let importResult = makeImportResult(
            pitchDiscriminations: [
                makeComparison(minutesOffset: 0, referenceNote: 60, targetNote: 64),
                makeComparison(minutesOffset: 5, referenceNote: 60, targetNote: 64)
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 1)

        let comparisons = try store.fetchAllSorted(PitchDiscriminationRecord.self)
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

        #expect(summary.imported(for: .intervalPitchMatching) == 1)
        #expect(summary.skipped(for: .intervalPitchMatching) == 1)

        let pitchMatchings = try store.fetchAllSorted(PitchMatchingRecord.self)
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

        let duplicate = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 99.9, isCorrect: false,
            interval: 4, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 0)
        )
        let importResult = makeImportResult(pitchDiscriminations: [duplicate])

        _ = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        let comparisons = try store.fetchAllSorted(PitchDiscriminationRecord.self)
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
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.skipped(for: .intervalPitchMatching) == 1)
    }

    @Test("merge with no duplicates imports all")
    func mergeNoDuplicates() async throws {
        let store = try makeStore()

        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 0), makeComparison(minutesOffset: 1)],
            pitchMatchings: [makePitchMatching(minutesOffset: 2)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 2)
        #expect(summary.imported(for: .intervalPitchMatching) == 1)
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

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.imported(for: .intervalPitchMatching) == 1)
        #expect(summary.skipped(for: .intervalPitchMatching) == 1)

        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 2)
        #expect(try store.fetchAllSorted(PitchMatchingRecord.self).count == 2)
    }

    // MARK: - Edge Case Tests

    @Test("empty import returns zero summary for replace mode")
    func emptyImportReplace() async throws {
        let store = try makeStore()

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .replace, into: store)

        #expect(summary.totalImported == 0)
        #expect(summary.totalSkipped == 0)
        #expect(summary.parseErrorCount == 0)
    }

    @Test("empty import returns zero summary for merge mode")
    func emptyImportMerge() async throws {
        let store = try makeStore()

        let summary = try TrainingDataImporter.importData(makeImportResult(), mode: .merge, into: store)

        #expect(summary.totalImported == 0)
        #expect(summary.totalSkipped == 0)
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

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.imported(for: .intervalPitchMatching) == 1)
        #expect(summary.skipped(for: .intervalPitchMatching) == 1)
        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 1)
        #expect(try store.fetchAllSorted(PitchMatchingRecord.self).count == 1)
    }

    @Test("records with identical timestamps but different training types are not duplicates")
    func sameTimestampDifferentType() async throws {
        let store = try makeStore()

        let timestamp = fixedDate()
        let existing = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        try store.save(existing)

        let imported = PitchMatchingRecord(
            referenceNote: 60, targetNote: 64, initialCentOffset: 25.0, userCentError: 3.2,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        let importResult = makeImportResult(pitchMatchings: [imported])

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .intervalPitchMatching) == 1)
        #expect(summary.skipped(for: .intervalPitchMatching) == 0)
    }

    @Test("records with identical timestamps and training type but different notes are not duplicates")
    func sameTimestampDifferentNotes() async throws {
        let store = try makeStore()

        let timestamp = fixedDate()
        try store.save(PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        ))

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

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 2)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 0)
        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 3)
    }

    // MARK: - CSV Round-Trip Duplicate Detection

    @Test("merge detects duplicates after export-import round-trip with whole-second timestamps")
    func mergeDetectsDuplicatesAfterRoundTrip() async throws {
        let store = try makeStore()

        // Use a whole-second timestamp since CSV export uses ISO8601 without fractional seconds
        let timestamp = Date(timeIntervalSinceReferenceDate: 794_394_000.0)
        let record = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        try store.save(record)

        let exported = timestamp.formatted(.iso8601)
        let reimported = try Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(exported)

        let importedRecord = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: reimported
        )
        let importResult = makeImportResult(pitchDiscriminations: [importedRecord])

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 0)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 1)
        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 1)
    }

    // MARK: - Rhythm Record Helpers

    private func makeTimingOffsetDetection(minutesOffset: Double = 0, tempoBPM: Int = 120) -> TimingOffsetDetectionRecord {
        TimingOffsetDetectionRecord(
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
            rhythmOffsetDetections: [makeTimingOffsetDetection(minutesOffset: 1)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.imported(for: .timingOffsetDetection) == 1)
        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 1)
        #expect(try store.fetchAllSorted(TimingOffsetDetectionRecord.self).count == 1)
    }

    @Test("replace mode replaces existing rhythm records")
    func replaceModeReplacesExistingRhythm() async throws {
        let store = try makeStore()

        try store.save(makeTimingOffsetDetection(minutesOffset: 0))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [makeTimingOffsetDetection(minutesOffset: 10), makeTimingOffsetDetection(minutesOffset: 11)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.imported(for: .timingOffsetDetection) == 2)
        #expect(try store.fetchAllSorted(TimingOffsetDetectionRecord.self).count == 2)
    }

    // MARK: - Rhythm Merge Mode

    @Test("merge inserts only non-duplicate rhythm offset detections")
    func mergeInsertNonDuplicateTimingOffset() async throws {
        let store = try makeStore()

        try store.save(makeTimingOffsetDetection(minutesOffset: 0, tempoBPM: 120))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [
                makeTimingOffsetDetection(minutesOffset: 0, tempoBPM: 120),
                makeTimingOffsetDetection(minutesOffset: 5, tempoBPM: 120),
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .timingOffsetDetection) == 1)
        #expect(summary.skipped(for: .timingOffsetDetection) == 1)
        #expect(try store.fetchAllSorted(TimingOffsetDetectionRecord.self).count == 2)
    }

    @Test("rhythm records with same timestamp but different tempo are not duplicates")
    func sameTimestampDifferentTempoNotDuplicate() async throws {
        let store = try makeStore()

        try store.save(makeTimingOffsetDetection(minutesOffset: 0, tempoBPM: 120))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [makeTimingOffsetDetection(minutesOffset: 0, tempoBPM: 90)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .timingOffsetDetection) == 1)
        #expect(summary.skipped(for: .timingOffsetDetection) == 0)
    }

    @Test("merge deduplicates identical rhythm records within the same import file")
    func mergeDeduplicatesRhythmWithinFile() async throws {
        let store = try makeStore()

        let importResult = makeImportResult(
            rhythmOffsetDetections: [
                makeTimingOffsetDetection(minutesOffset: 0, tempoBPM: 120),
                makeTimingOffsetDetection(minutesOffset: 0, tempoBPM: 120),
            ]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .timingOffsetDetection) == 1)
        #expect(summary.skipped(for: .timingOffsetDetection) == 1)
    }

    // MARK: - ImportSummary Totals with Rhythm

    @Test("totalImported includes rhythm records")
    func totalImportedIncludesRhythm() async throws {
        let store = try makeStore()

        let importResult = makeImportResult(
            pitchDiscriminations: [makeComparison(minutesOffset: 0)],
            rhythmOffsetDetections: [makeTimingOffsetDetection(minutesOffset: 1)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .replace, into: store)

        #expect(summary.totalImported == 2)
    }

    @Test("totalSkipped includes rhythm records")
    func totalSkippedIncludesRhythm() async throws {
        let store = try makeStore()

        try store.save(makeTimingOffsetDetection(minutesOffset: 0))

        let importResult = makeImportResult(
            rhythmOffsetDetections: [makeTimingOffsetDetection(minutesOffset: 0)]
        )

        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.totalSkipped == 1)
        #expect(summary.totalImported == 0)
    }

    // MARK: - Millisecond Timestamp Precision

    @Test("two records 500ms apart with same key fields are both imported")
    func subSecondRecordsNotFalselyDeduplicated() async throws {
        let store = try makeStore()

        let base = Date(timeIntervalSinceReferenceDate: 794_394_000.0)
        let record1 = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: base
        )
        let record2 = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 12.0, isCorrect: false,
            interval: 4, tuningSystem: "equalTemperament",
            timestamp: base.addingTimeInterval(0.5)
        )

        let importResult = makeImportResult(pitchDiscriminations: [record1, record2])
        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 2)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 0)
        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 2)
    }

    @Test("two records at the exact same millisecond with same key fields are deduplicated")
    func exactMillisecondDuplicateDetected() async throws {
        let store = try makeStore()

        let timestamp = Date(timeIntervalSinceReferenceDate: 794_394_000.123)
        let record1 = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 15.5, isCorrect: true,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )
        let record2 = PitchDiscriminationRecord(
            referenceNote: 60, targetNote: 64, centOffset: 99.0, isCorrect: false,
            interval: 4, tuningSystem: "equalTemperament", timestamp: timestamp
        )

        let importResult = makeImportResult(pitchDiscriminations: [record1, record2])
        let summary = try TrainingDataImporter.importData(importResult, mode: .merge, into: store)

        #expect(summary.imported(for: .intervalPitchDiscrimination) == 1)
        #expect(summary.skipped(for: .intervalPitchDiscrimination) == 1)
        #expect(try store.fetchAllSorted(PitchDiscriminationRecord.self).count == 1)
    }
}

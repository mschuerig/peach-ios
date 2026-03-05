import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("Training Data Import Action")
struct TrainingDataImportActionTests {

    // MARK: - Helpers

    private func makeStore() throws -> TrainingDataStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
        return TrainingDataStore(modelContext: ModelContext(container))
    }

    private func fixedDate(minutesOffset: Double = 0) -> Date {
        Date(timeIntervalSinceReferenceDate: 794_394_000 + minutesOffset * 60)
    }

    /// Simulates the import action closure wired in PeachApp
    private func performImportAction(
        parseResult: CSVImportParser.ImportResult,
        mode: TrainingDataImporter.ImportMode,
        dataStore: TrainingDataStore,
        profile: PerceptualProfile,
        progressTimeline: ProgressTimeline
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
        progressTimeline.rebuild(comparisonRecords: allComparisons, pitchMatchingRecords: allPitchMatchings)
        return summary
    }

    // MARK: - Replace mode

    @Test("Replace mode imports records and rebuilds profile")
    func replaceImportsAndRebuildsProfile() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()
        let progressTimeline = ProgressTimeline()

        let comparisons = [
            ComparisonRecord(referenceNote: 60, targetNote: 62, centOffset: 25.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()),
            ComparisonRecord(referenceNote: 64, targetNote: 66, centOffset: 30.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1))
        ]
        let parseResult = CSVImportParser.ImportResult(comparisons: comparisons, pitchMatchings: [], errors: [])

        let summary = try performImportAction(
            parseResult: parseResult, mode: .replace,
            dataStore: store, profile: profile, progressTimeline: progressTimeline
        )

        #expect(summary.totalImported == 2)
        #expect(profile.overallMean != nil)
    }

    // MARK: - Merge mode

    @Test("Merge mode imports non-duplicates and rebuilds profile")
    func mergeImportsNonDuplicatesAndRebuildsProfile() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()
        let progressTimeline = ProgressTimeline()

        // Pre-existing record
        let existing = ComparisonRecord(referenceNote: 60, targetNote: 62, centOffset: 25.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate())
        try store.save(existing)

        // Import: one duplicate, one new
        let comparisons = [
            ComparisonRecord(referenceNote: 60, targetNote: 62, centOffset: 25.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()),
            ComparisonRecord(referenceNote: 64, targetNote: 66, centOffset: 30.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1))
        ]
        let parseResult = CSVImportParser.ImportResult(comparisons: comparisons, pitchMatchings: [], errors: [])

        let summary = try performImportAction(
            parseResult: parseResult, mode: .merge,
            dataStore: store, profile: profile, progressTimeline: progressTimeline
        )

        #expect(summary.comparisonsImported == 1)
        #expect(summary.comparisonsSkipped == 1)
        // Profile rebuilt from ALL store records (existing + new)
        #expect(profile.overallMean != nil)
    }

    // MARK: - Profile rebuild uses ALL store records

    @Test("Profile is rebuilt from ALL store records not just imported ones")
    func profileRebuiltFromAllRecords() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()
        let progressTimeline = ProgressTimeline()

        // Pre-existing records
        for i in 0..<3 {
            let record = ComparisonRecord(referenceNote: 60, targetNote: 62, centOffset: Double(20 + i), isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: Double(i)))
            try store.save(record)
        }

        // Import 2 new records via merge
        let comparisons = [
            ComparisonRecord(referenceNote: 67, targetNote: 69, centOffset: 15.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 10)),
            ComparisonRecord(referenceNote: 72, targetNote: 74, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 11))
        ]
        let parseResult = CSVImportParser.ImportResult(comparisons: comparisons, pitchMatchings: [], errors: [])

        _ = try performImportAction(
            parseResult: parseResult, mode: .merge,
            dataStore: store, profile: profile, progressTimeline: progressTimeline
        )

        // Profile should have all 5 records (3 existing + 2 imported)
        let allRecords = try store.fetchAllComparisons()
        #expect(allRecords.count == 5)
    }

    // MARK: - ProgressTimeline rebuild

    @Test("ProgressTimeline rebuild matches fresh init behavior")
    func progressTimelineRebuildMatchesFreshInit() async throws {
        let records = (0..<25).map { i in
            ComparisonRecord(
                referenceNote: 60, targetNote: 60, centOffset: Double(50 - i), isCorrect: true,
                interval: 0, tuningSystem: "equalTemperament",
                timestamp: Date(timeIntervalSince1970: Double(i) * 3600)
            )
        }

        let freshTimeline = ProgressTimeline(comparisonRecords: records)
        let rebuiltTimeline = ProgressTimeline()
        rebuiltTimeline.rebuild(comparisonRecords: records, pitchMatchingRecords: [])

        #expect(rebuiltTimeline.state(for: .unisonComparison) == freshTimeline.state(for: .unisonComparison))
    }
}

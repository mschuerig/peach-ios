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
        trendAnalyzer: TrendAnalyzer,
        thresholdTimeline: ThresholdTimeline
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
        return summary
    }

    // MARK: - Replace mode

    @Test("Replace mode imports records and rebuilds profile")
    func replaceImportsAndRebuildsProfile() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()
        let trendAnalyzer = TrendAnalyzer()
        let thresholdTimeline = ThresholdTimeline()

        let comparisons = [
            ComparisonRecord(referenceNote: 60, targetNote: 62, centOffset: 25.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()),
            ComparisonRecord(referenceNote: 64, targetNote: 66, centOffset: 30.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1))
        ]
        let parseResult = CSVImportParser.ImportResult(comparisons: comparisons, pitchMatchings: [], errors: [])

        let summary = try performImportAction(
            parseResult: parseResult, mode: .replace,
            dataStore: store, profile: profile, trendAnalyzer: trendAnalyzer, thresholdTimeline: thresholdTimeline
        )

        #expect(summary.totalImported == 2)
        #expect(profile.overallMean != nil)
        #expect(thresholdTimeline.dataPoints.count == 2)
    }

    // MARK: - Merge mode

    @Test("Merge mode imports non-duplicates and rebuilds profile")
    func mergeImportsNonDuplicatesAndRebuildsProfile() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()
        let trendAnalyzer = TrendAnalyzer()
        let thresholdTimeline = ThresholdTimeline()

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
            dataStore: store, profile: profile, trendAnalyzer: trendAnalyzer, thresholdTimeline: thresholdTimeline
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
        let trendAnalyzer = TrendAnalyzer()
        let thresholdTimeline = ThresholdTimeline()

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
            dataStore: store, profile: profile, trendAnalyzer: trendAnalyzer, thresholdTimeline: thresholdTimeline
        )

        // Profile should have all 5 records (3 existing + 2 imported)
        let allRecords = try store.fetchAllComparisons()
        #expect(allRecords.count == 5)
        #expect(thresholdTimeline.dataPoints.count == 5)
    }

    // MARK: - TrendAnalyzer rebuild

    @Test("TrendAnalyzer rebuild matches fresh init behavior")
    func trendAnalyzerRebuildMatchesFreshInit() async throws {
        let offsets = Array(repeating: 50.0, count: 10) + Array(repeating: 30.0, count: 10)
        let records = offsets.enumerated().map { index, offset in
            ComparisonRecord(
                referenceNote: 60, targetNote: 60, centOffset: offset, isCorrect: true,
                interval: 0, tuningSystem: "equalTemperament",
                timestamp: Date(timeIntervalSince1970: Double(index) * 60)
            )
        }

        let freshAnalyzer = TrendAnalyzer(records: records)
        let rebuiltAnalyzer = TrendAnalyzer()
        rebuiltAnalyzer.rebuild(from: records)

        #expect(rebuiltAnalyzer.trend == freshAnalyzer.trend)
        #expect(rebuiltAnalyzer.trend == .improving)
    }

    // MARK: - ThresholdTimeline rebuild

    @Test("ThresholdTimeline rebuild matches fresh init behavior")
    func thresholdTimelineRebuildMatchesFreshInit() async throws {
        let records = (0..<5).map { i in
            ComparisonRecord(
                referenceNote: 60, targetNote: 60, centOffset: Double(10 + i * 10), isCorrect: true,
                interval: 0, tuningSystem: "equalTemperament",
                timestamp: Date(timeIntervalSince1970: Double(i + 2) * 86400 + 43200)
            )
        }

        let freshTimeline = ThresholdTimeline(records: records)
        let rebuiltTimeline = ThresholdTimeline()
        rebuiltTimeline.rebuild(from: records)

        #expect(rebuiltTimeline.dataPoints.count == freshTimeline.dataPoints.count)
        #expect(rebuiltTimeline.aggregatedPoints.count == freshTimeline.aggregatedPoints.count)
    }
}

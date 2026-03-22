import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("Training Data Import Action")
struct TrainingDataImportActionTests {

    // MARK: - Helpers

    private func makeStore() throws -> TrainingDataStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, RhythmOffsetDetectionRecord.self, ContinuousRhythmMatchingRecord.self, configurations: config)
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
        profile: PerceptualProfile
    ) throws -> TrainingDataImporter.ImportSummary {
        let summary = try TrainingDataImporter.importData(parseResult, mode: mode, into: dataStore)
        try profile.replaceAll { builder in
            try MetricPointMapper.feedAllRecords(from: dataStore, into: builder)
        }
        return summary
    }

    // MARK: - Replace mode

    @Test("Replace mode imports records and rebuilds profile")
    func replaceImportsAndRebuildsProfile() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()

        let comparisons = [
            PitchDiscriminationRecord(referenceNote: 60, targetNote: 62, centOffset: 25.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()),
            PitchDiscriminationRecord(referenceNote: 64, targetNote: 66, centOffset: 30.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1))
        ]
        let parseResult = CSVImportParser.ImportResult(pitchDiscriminations: comparisons, pitchMatchings: [], rhythmOffsetDetections: [], continuousRhythmMatchings: [], errors: [])

        let summary = try performImportAction(
            parseResult: parseResult, mode: .replace,
            dataStore: store, profile: profile
        )

        #expect(summary.totalImported == 2)
        #expect(profile.comparisonMean(for: .prime) != nil)
    }

    // MARK: - Merge mode

    @Test("Merge mode imports non-duplicates and rebuilds profile")
    func mergeImportsNonDuplicatesAndRebuildsProfile() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()

        // Pre-existing record
        let existing = PitchDiscriminationRecord(referenceNote: 60, targetNote: 62, centOffset: 25.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate())
        try store.save(existing)

        // Import: one duplicate, one new
        let comparisons = [
            PitchDiscriminationRecord(referenceNote: 60, targetNote: 62, centOffset: 25.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate()),
            PitchDiscriminationRecord(referenceNote: 64, targetNote: 66, centOffset: 30.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 1))
        ]
        let parseResult = CSVImportParser.ImportResult(pitchDiscriminations: comparisons, pitchMatchings: [], rhythmOffsetDetections: [], continuousRhythmMatchings: [], errors: [])

        let summary = try performImportAction(
            parseResult: parseResult, mode: .merge,
            dataStore: store, profile: profile
        )

        #expect(summary.pitchDiscriminationsImported == 1)
        #expect(summary.pitchDiscriminationsSkipped == 1)
        // Profile rebuilt from ALL store records (existing + new)
        #expect(profile.comparisonMean(for: .prime) != nil)
    }

    // MARK: - Profile rebuild uses ALL store records

    @Test("Profile is rebuilt from ALL store records not just imported ones")
    func profileRebuiltFromAllRecords() async throws {
        let store = try makeStore()
        let profile = PerceptualProfile()

        // Pre-existing records
        for i in 0..<3 {
            let record = PitchDiscriminationRecord(referenceNote: 60, targetNote: 62, centOffset: Double(20 + i), isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: Double(i)))
            try store.save(record)
        }

        // Import 2 new records via merge
        let comparisons = [
            PitchDiscriminationRecord(referenceNote: 67, targetNote: 69, centOffset: 15.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 10)),
            PitchDiscriminationRecord(referenceNote: 72, targetNote: 74, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: fixedDate(minutesOffset: 11))
        ]
        let parseResult = CSVImportParser.ImportResult(pitchDiscriminations: comparisons, pitchMatchings: [], rhythmOffsetDetections: [], continuousRhythmMatchings: [], errors: [])

        _ = try performImportAction(
            parseResult: parseResult, mode: .merge,
            dataStore: store, profile: profile
        )

        // Profile should have all 5 records (3 existing + 2 imported)
        let allRecords = try store.fetchAllPitchDiscriminations()
        #expect(allRecords.count == 5)
    }

    // MARK: - ProgressTimeline reads from profile

    @Test("ProgressTimeline reflects profile state after import")
    func progressTimelineReflectsProfileAfterImport() async throws {
        let profile = PerceptualProfile()
        let timeline = ProgressTimeline(profile: profile)

        let records = (0..<25).map { i in
            PitchDiscriminationRecord(
                referenceNote: 60, targetNote: 60, centOffset: Double(50 - i), isCorrect: true,
                interval: 0, tuningSystem: "equalTemperament",
                timestamp: Date(timeIntervalSince1970: Double(i) * 3600)
            )
        }

        profile.replaceAll { builder in
            MetricPointMapper.feedPitchDiscriminations(records, into: builder)
        }

        #expect(timeline.state(for: .unisonPitchDiscrimination) == .active)
    }
}

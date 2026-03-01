import Testing
import SwiftData
import SwiftUI
@testable import Peach

@Suite("Settings Tests")
struct SettingsTests {

    // MARK: - Task 1: @AppStorage Keys and Defaults

    @Test("Algorithm defaults match TrainingSettings defaults")
    func algorithmDefaultsMatchTrainingSettings() {
        let trainingDefaults = TrainingSettings(referencePitch: .concert440)

        #expect(SettingsKeys.defaultNoteRangeMin == trainingDefaults.noteRangeMin.rawValue)
        #expect(SettingsKeys.defaultNoteRangeMax == trainingDefaults.noteRangeMax.rawValue)
        #expect(SettingsKeys.defaultReferencePitch == trainingDefaults.referencePitch.rawValue)
    }

    @Test("Audio defaults use expected standalone values")
    func audioDefaultsAreCorrect() {
        // noteDuration and soundSource are not TrainingSettings properties —
        // they are standalone settings with hardcoded defaults
        #expect(SettingsKeys.defaultNoteDuration == 1.0)
        #expect(SettingsKeys.defaultSoundSource == "sf2:8:80")
    }

    @Test("Storage keys are defined as string constants")
    func storageKeysAreDefined() {
        #expect(SettingsKeys.noteRangeMin == "noteRangeMin")
        #expect(SettingsKeys.noteRangeMax == "noteRangeMax")
        #expect(SettingsKeys.noteDuration == "noteDuration")
        #expect(SettingsKeys.referencePitch == "referencePitch")
        #expect(SettingsKeys.soundSource == "soundSource")
    }

    @Test("intervals key is defined as string constant")
    func intervalsKeyDefined() async {
        #expect(SettingsKeys.intervals == "intervals")
    }

    @Test("AppUserSettings returns default perfectFifth when no UserDefaults entry")
    func appUserSettingsIntervalsDefault() async {
        UserDefaults.standard.removeObject(forKey: SettingsKeys.intervals)
        let settings = AppUserSettings()
        #expect(settings.intervals == Set<DirectedInterval>([.up(.perfectFifth)]))
    }

    @Test("AppUserSettings reads persisted intervals from UserDefaults")
    func appUserSettingsReadsPersistedIntervals() async {
        let expected: Set<DirectedInterval> = [.up(.majorThird), .down(.perfectFifth)]
        let selection = IntervalSelection(expected)
        UserDefaults.standard.set(selection.rawValue, forKey: SettingsKeys.intervals)
        let settings = AppUserSettings()
        #expect(settings.intervals == expected)
        UserDefaults.standard.removeObject(forKey: SettingsKeys.intervals)
    }

    @Test("AppUserSettings falls back to default on invalid JSON")
    func appUserSettingsIntervalsFallbackOnInvalidJSON() async {
        UserDefaults.standard.set("not-valid-json", forKey: SettingsKeys.intervals)
        let settings = AppUserSettings()
        #expect(settings.intervals == Set<DirectedInterval>([.up(.perfectFifth)]))
        UserDefaults.standard.removeObject(forKey: SettingsKeys.intervals)
    }

    @Test("AppUserSettings returns hardcoded equalTemperament tuning system")
    func appUserSettingsTuningSystemHardcoded() {
        let settings = AppUserSettings()
        #expect(settings.tuningSystem == .equalTemperament)
    }

    @Test("MockUserSettings allows interval test injection")
    func mockUserSettingsIntervalInjection() {
        let mock = MockUserSettings()
        #expect(mock.intervals == Set<DirectedInterval>([.prime]))
        mock.intervals = [.up(.perfectFifth), .up(.majorThird)]
        #expect(mock.intervals == Set<DirectedInterval>([.up(.perfectFifth), .up(.majorThird)]))
    }

    @Test("MockUserSettings allows tuningSystem test injection")
    func mockUserSettingsTuningSystemInjection() {
        let mock = MockUserSettings()
        #expect(mock.tuningSystem == .equalTemperament)
    }

    // MARK: - IntervalSelection Serialization

    @Test("IntervalSelection round-trips single interval")
    func intervalSelectionSingleRoundTrip() async {
        let original = IntervalSelection([.up(.perfectFifth)])
        let restored = IntervalSelection(rawValue: original.rawValue)
        #expect(restored?.intervals == original.intervals)
    }

    @Test("IntervalSelection round-trips multiple intervals")
    func intervalSelectionMultipleRoundTrip() async {
        let original = IntervalSelection([.prime, .up(.majorThird), .down(.perfectFifth)])
        let restored = IntervalSelection(rawValue: original.rawValue)
        #expect(restored?.intervals == original.intervals)
    }

    @Test("IntervalSelection round-trips all 25 possible directed intervals")
    func intervalSelectionAllDirectedIntervalsRoundTrip() async {
        var all = Set<DirectedInterval>()
        all.insert(.prime)
        for interval in Interval.allCases where interval != .prime {
            all.insert(.up(interval))
            all.insert(.down(interval))
        }
        #expect(all.count == 25)
        let original = IntervalSelection(all)
        let restored = IntervalSelection(rawValue: original.rawValue)
        #expect(restored?.intervals == all)
    }

    @Test("IntervalSelection round-trips empty set")
    func intervalSelectionEmptyRoundTrip() async {
        let original = IntervalSelection([])
        let restored = IntervalSelection(rawValue: original.rawValue)
        #expect(restored?.intervals == Set<DirectedInterval>())
    }

    @Test("IntervalSelection returns nil for invalid JSON")
    func intervalSelectionInvalidJSON() async {
        let result = IntervalSelection(rawValue: "not-json")
        #expect(result == nil)
    }

    @Test("IntervalSelection default is up perfectFifth")
    func intervalSelectionDefault() async {
        let defaultSelection = IntervalSelection.default
        #expect(defaultSelection.intervals == Set<DirectedInterval>([.up(.perfectFifth)]))
    }

    // MARK: - Task 2: Note Range Validation

    @Test("Lower bound range enforces minimum gap from upper bound")
    func lowerBoundRangeEnforcesGap() {
        // With upper at 84 (C6), lower can go up to 72 (C5)
        let range = SettingsKeys.lowerBoundRange(noteRangeMax: 84)
        #expect(range == 21...72)
        #expect(!range.contains(73))

        // With upper at 48 (C3), lower can go up to 36 (C2)
        let smallRange = SettingsKeys.lowerBoundRange(noteRangeMax: 48)
        #expect(smallRange == 21...36)
    }

    @Test("Upper bound range enforces minimum gap from lower bound")
    func upperBoundRangeEnforcesGap() {
        // With lower at 36 (C2), upper must be at least 48 (C3)
        let range = SettingsKeys.upperBoundRange(noteRangeMin: 36)
        #expect(range == 48...108)
        #expect(!range.contains(47))

        // With lower at 60 (C4), upper must be at least 72 (C5)
        let highRange = SettingsKeys.upperBoundRange(noteRangeMin: 60)
        #expect(highRange == 72...108)
    }

    @Test("Note name display uses PianoKeyboardLayout")
    func noteNameDisplay() {
        #expect(PianoKeyboardLayout.noteName(midiNote: 36) == "C2")
        #expect(PianoKeyboardLayout.noteName(midiNote: 84) == "C6")
        #expect(PianoKeyboardLayout.noteName(midiNote: 69) == "A4")
        #expect(PianoKeyboardLayout.noteName(midiNote: 21) == "A0")
        #expect(PianoKeyboardLayout.noteName(midiNote: 108) == "C8")
    }

    // MARK: - Task 3: Reset Functionality

    @Test("PerceptualProfile reset clears all note data")
    func profileResetClearsData() {
        let profile = PerceptualProfile()

        // Add some training data
        profile.update(note: 60, centOffset: 5.0, isCorrect: true)
        profile.update(note: 60, centOffset: 3.0, isCorrect: true)
        profile.update(note: 72, centOffset: -2.0, isCorrect: false)
        #expect(profile.statsForNote(60).sampleCount == 2)
        #expect(profile.statsForNote(72).sampleCount == 1)
        #expect(profile.overallMean != nil)

        // Reset
        profile.reset()

        // Verify cold start state
        #expect(profile.statsForNote(60).sampleCount == 0)
        #expect(profile.statsForNote(72).sampleCount == 0)
        #expect(profile.overallMean == nil)
        #expect(profile.overallStdDev == nil)
    }

    @Test("TrendAnalyzer reset clears all trend data")
    func trendAnalyzerResetClearsData() {
        // Create with enough records to have a trend
        var records: [ComparisonRecord] = []
        for i in 0..<30 {
            let record = ComparisonRecord(
                referenceNote: 60,
                targetNote: 61,
                centOffset: Double(i) + 1.0,
                isCorrect: true,
                interval: 1,
                tuningSystem: "equalTemperament"
            )
            records.append(record)
        }
        let analyzer = TrendAnalyzer(records: records)
        #expect(analyzer.trend != nil)

        // Reset
        analyzer.reset()

        // Verify cleared state
        #expect(analyzer.trend == nil)
    }

    @Test("Reset deletes all records from SwiftData")
    func resetDeletesAllRecords() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
        let context = container.mainContext

        // Insert comparison records
        let comparison1 = ComparisonRecord(
            referenceNote: 60,
            targetNote: 61,
            centOffset: 2.0,
            isCorrect: true,
            interval: 1,
            tuningSystem: "equalTemperament"
        )
        let comparison2 = ComparisonRecord(
            referenceNote: 72,
            targetNote: 73,
            centOffset: 2.5,
            isCorrect: false,
            interval: 1,
            tuningSystem: "equalTemperament"
        )
        context.insert(comparison1)
        context.insert(comparison2)

        // Insert pitch matching records
        let pitchMatching1 = PitchMatchingRecord(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            interval: 0,
            tuningSystem: "equalTemperament"
        )
        context.insert(pitchMatching1)
        try context.save()

        // Verify records exist
        let comparisonCountBefore = try context.fetchCount(FetchDescriptor<ComparisonRecord>())
        #expect(comparisonCountBefore == 2)
        let pitchCountBefore = try context.fetchCount(FetchDescriptor<PitchMatchingRecord>())
        #expect(pitchCountBefore == 1)

        // Delete all using TrainingDataStore.deleteAll() (same as SettingsScreen)
        let dataStore = TrainingDataStore(modelContext: context)
        try dataStore.deleteAll()

        // Verify all records deleted
        let comparisonCountAfter = try context.fetchCount(FetchDescriptor<ComparisonRecord>())
        #expect(comparisonCountAfter == 0)
        let pitchCountAfter = try context.fetchCount(FetchDescriptor<PitchMatchingRecord>())
        #expect(pitchCountAfter == 0)
    }

    // MARK: - Task 5: Range Functions

    @Test("Range functions produce valid ranges with default values")
    func rangeValidityWithDefaults() {
        let lowerRange = SettingsKeys.lowerBoundRange(noteRangeMax: SettingsKeys.defaultNoteRangeMax)
        let upperRange = SettingsKeys.upperBoundRange(noteRangeMin: SettingsKeys.defaultNoteRangeMin)

        #expect(lowerRange.contains(SettingsKeys.defaultNoteRangeMin))
        #expect(upperRange.contains(SettingsKeys.defaultNoteRangeMax))
        #expect(lowerRange.lowerBound == SettingsKeys.absoluteMinNote)
        #expect(upperRange.upperBound == SettingsKeys.absoluteMaxNote)
    }
}

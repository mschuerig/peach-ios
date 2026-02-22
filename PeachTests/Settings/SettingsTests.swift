import Testing
import SwiftData
import SwiftUI
@testable import Peach

@Suite("Settings Tests")
struct SettingsTests {

    // MARK: - Task 1: @AppStorage Keys and Defaults

    @Test("Algorithm defaults match TrainingSettings defaults")
    func algorithmDefaultsMatchTrainingSettings() {
        let trainingDefaults = TrainingSettings()

        #expect(SettingsKeys.defaultNaturalVsMechanical == trainingDefaults.naturalVsMechanical)
        #expect(SettingsKeys.defaultNoteRangeMin == trainingDefaults.noteRangeMin)
        #expect(SettingsKeys.defaultNoteRangeMax == trainingDefaults.noteRangeMax)
        #expect(SettingsKeys.defaultReferencePitch == trainingDefaults.referencePitch)
    }

    @Test("Audio defaults use expected standalone values")
    func audioDefaultsAreCorrect() {
        // noteDuration and soundSource are not TrainingSettings properties —
        // they are standalone settings with hardcoded defaults
        #expect(SettingsKeys.defaultNoteDuration == 1.0)
        #expect(SettingsKeys.defaultSoundSource == "sine")
    }

    @Test("Storage keys are defined as string constants")
    func storageKeysAreDefined() {
        #expect(SettingsKeys.naturalVsMechanical == "naturalVsMechanical")
        #expect(SettingsKeys.noteRangeMin == "noteRangeMin")
        #expect(SettingsKeys.noteRangeMax == "noteRangeMax")
        #expect(SettingsKeys.noteDuration == "noteDuration")
        #expect(SettingsKeys.referencePitch == "referencePitch")
        #expect(SettingsKeys.soundSource == "soundSource")
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
    @MainActor
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
    @MainActor
    func trendAnalyzerResetClearsData() {
        // Create with enough records to have a trend
        var records: [ComparisonRecord] = []
        for i in 0..<30 {
            let record = ComparisonRecord(
                note1: 60,
                note2: 61,
                note2CentOffset: Double(i) + 1.0,
                isCorrect: true
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

    @Test("Reset deletes all ComparisonRecords from SwiftData")
    @MainActor
    func resetDeletesComparisonRecords() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ComparisonRecord.self, configurations: config)
        let context = container.mainContext

        // Insert test records
        let record1 = ComparisonRecord(
            note1: 60,
            note2: 61,
            note2CentOffset: 2.0,
            isCorrect: true
        )
        let record2 = ComparisonRecord(
            note1: 72,
            note2: 73,
            note2CentOffset: 2.5,
            isCorrect: false
        )
        context.insert(record1)
        context.insert(record2)
        try context.save()

        // Verify records exist
        let fetchBefore = FetchDescriptor<ComparisonRecord>()
        let countBefore = try context.fetchCount(fetchBefore)
        #expect(countBefore == 2)

        // Delete all using TrainingDataStore.deleteAll() (same as SettingsScreen)
        let dataStore = TrainingDataStore(modelContext: context)
        try dataStore.deleteAll()

        // Verify records deleted
        let fetchAfter = FetchDescriptor<ComparisonRecord>()
        let countAfter = try context.fetchCount(fetchAfter)
        #expect(countAfter == 0)
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

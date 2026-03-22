import Testing
import SwiftData
import SwiftUI
@testable import Peach

@Suite("Settings Tests")
struct SettingsTests {

    // MARK: - Task 1: @AppStorage Keys and Defaults

    @Test("Algorithm defaults match PitchDiscriminationSettings defaults")
    func algorithmDefaultsMatchTrainingSettings() async {
        let trainingDefaults = PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime])

        #expect(SettingsKeys.defaultNoteRangeMin == trainingDefaults.noteRange.lowerBound)
        #expect(SettingsKeys.defaultNoteRangeMax == trainingDefaults.noteRange.upperBound)
        #expect(SettingsKeys.defaultReferencePitch == trainingDefaults.referencePitch)
    }

    @Test("Audio defaults use expected standalone values")
    func audioDefaultsAreCorrect() async {
        // noteDuration and soundSource are not TrainingSettings properties —
        // they are standalone settings with hardcoded defaults
        #expect(SettingsKeys.defaultNoteDuration == NoteDuration(1.0))
        #expect(SettingsKeys.defaultSoundSource == "sf2:0:0")
    }

    @Test("Storage keys are defined as string constants")
    func storageKeysAreDefined() async {
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
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.intervals) }
        let expected: Set<DirectedInterval> = [.up(.majorThird), .down(.perfectFifth)]
        let selection = IntervalSelection(expected)
        UserDefaults.standard.set(selection.rawValue, forKey: SettingsKeys.intervals)
        let settings = AppUserSettings()
        #expect(settings.intervals == expected)
    }

    @Test("AppUserSettings falls back to default on invalid JSON")
    func appUserSettingsIntervalsFallbackOnInvalidJSON() async {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.intervals) }
        UserDefaults.standard.set("not-valid-json", forKey: SettingsKeys.intervals)
        let settings = AppUserSettings()
        #expect(settings.intervals == Set<DirectedInterval>([.up(.perfectFifth)]))
    }

    @Test("tuningSystem key is defined as string constant")
    func tuningSystemKeyDefined() async {
        #expect(SettingsKeys.tuningSystem == "tuningSystem")
    }

    @Test("defaultTuningSystem is equalTemperament storage identifier")
    func defaultTuningSystemValue() async {
        #expect(SettingsKeys.defaultTuningSystem == .equalTemperament)
    }

    @Test("AppUserSettings returns equalTemperament when no UserDefaults entry")
    func appUserSettingsTuningSystemDefault() async {
        UserDefaults.standard.removeObject(forKey: SettingsKeys.tuningSystem)
        let settings = AppUserSettings()
        #expect(settings.tuningSystem == .equalTemperament)
    }

    @Test("AppUserSettings reads persisted tuningSystem from UserDefaults")
    func appUserSettingsReadsPersistedTuningSystem() async {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.tuningSystem) }
        UserDefaults.standard.set("justIntonation", forKey: SettingsKeys.tuningSystem)
        let settings = AppUserSettings()
        #expect(settings.tuningSystem == .justIntonation)
    }

    @Test("AppUserSettings falls back to equalTemperament on invalid tuningSystem string")
    func appUserSettingsTuningSystemFallbackOnInvalid() async {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.tuningSystem) }
        UserDefaults.standard.set("pythagorean", forKey: SettingsKeys.tuningSystem)
        let settings = AppUserSettings()
        #expect(settings.tuningSystem == .equalTemperament)
    }

    @Test("MockUserSettings allows interval test injection")
    func mockUserSettingsIntervalInjection() async {
        let mock = MockUserSettings()
        #expect(mock.intervals == Set<DirectedInterval>([.prime]))
        mock.intervals = [.up(.perfectFifth), .up(.majorThird)]
        #expect(mock.intervals == Set<DirectedInterval>([.up(.perfectFifth), .up(.majorThird)]))
    }

    @Test("MockUserSettings allows tuningSystem test injection")
    func mockUserSettingsTuningSystemInjection() async {
        let mock = MockUserSettings()
        #expect(mock.tuningSystem == .equalTemperament)
    }

    // MARK: - Note Gap Settings

    @Test("noteGap key is defined as string constant")
    func noteGapKeyDefined() async {
        #expect(SettingsKeys.noteGap == "noteGap")
    }

    @Test("defaultNoteGap is zero")
    func defaultNoteGapIsZero() async {
        #expect(SettingsKeys.defaultNoteGap == .zero)
    }

    @Test("AppUserSettings returns default noteGap when no UserDefaults entry")
    func appUserSettingsNoteGapDefault() async {
        UserDefaults.standard.removeObject(forKey: SettingsKeys.noteGap)
        let settings = AppUserSettings()
        #expect(settings.noteGap == .zero)
    }

    @Test("AppUserSettings reads persisted noteGap from UserDefaults")
    func appUserSettingsReadsPersistedNoteGap() async {
        defer { UserDefaults.standard.removeObject(forKey: SettingsKeys.noteGap) }
        UserDefaults.standard.set(2.5, forKey: SettingsKeys.noteGap)
        let settings = AppUserSettings()
        #expect(settings.noteGap == .seconds(2.5))
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

    @Test("IntervalSelection rejects empty set deserialization")
    func intervalSelectionRejectsEmptySet() async {
        let original = IntervalSelection([])
        let restored = IntervalSelection(rawValue: original.rawValue)
        #expect(restored == nil)
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

    // MARK: - Minimum-Selection Guard

    @Test("isLastRemaining returns true for sole remaining interval")
    func isLastRemainingTrue() async {
        let selection = IntervalSelection([.up(.perfectFifth)])
        #expect(selection.isLastRemaining(.up(.perfectFifth)))
    }

    @Test("isLastRemaining returns false when multiple intervals selected")
    func isLastRemainingFalseMultiple() async {
        let selection = IntervalSelection([.up(.perfectFifth), .up(.majorThird)])
        #expect(!selection.isLastRemaining(.up(.perfectFifth)))
    }

    @Test("isLastRemaining returns false for interval not in selection")
    func isLastRemainingFalseNotInSelection() async {
        let selection = IntervalSelection([.up(.perfectFifth)])
        #expect(!selection.isLastRemaining(.up(.majorThird)))
    }

    // MARK: - NoteRange Integration

    @Test("SettingsKeys defaultNoteRange is C2-C6")
    func defaultNoteRange() async {
        let range = SettingsKeys.defaultNoteRange
        #expect(range.lowerBound == MIDINote(36))
        #expect(range.upperBound == MIDINote(84))
    }

    @Test("AppUserSettings returns default NoteRange when no UserDefaults entries")
    func appUserSettingsNoteRangeDefault() async {
        UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMax)
        let settings = AppUserSettings()
        #expect(settings.noteRange == NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)))
    }

    @Test("AppUserSettings reads custom NoteRange from UserDefaults")
    func appUserSettingsNoteRangeCustom() async {
        defer {
            UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMin)
            UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMax)
        }
        UserDefaults.standard.set(48, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(96, forKey: SettingsKeys.noteRangeMax)
        let settings = AppUserSettings()
        #expect(settings.noteRange == NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(96)))
    }

    @Test("MockUserSettings noteRange defaults to C2-C6")
    func mockUserSettingsNoteRange() async {
        let mock = MockUserSettings()
        #expect(mock.noteRange == NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)))
    }

    @Test("AppUserSettings falls back to default NoteRange when UserDefaults has invalid gap")
    func appUserSettingsNoteRangeFallbackOnInvalidGap() async {
        defer {
            UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMin)
            UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMax)
        }
        UserDefaults.standard.set(60, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(65, forKey: SettingsKeys.noteRangeMax)
        let settings = AppUserSettings()
        #expect(settings.noteRange == SettingsKeys.defaultNoteRange)
    }

    @Test("MockUserSettings allows noteRange injection")
    func mockUserSettingsNoteRangeInjection() async {
        let mock = MockUserSettings()
        mock.noteRange = NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72))
        #expect(mock.noteRange.lowerBound == MIDINote(48))
        #expect(mock.noteRange.upperBound == MIDINote(72))
    }

    // MARK: - Settings Help Sections

    @Test("helpSections returns six sections matching settings groups")
    func helpSectionsCount() async {
        #expect(SettingsScreen.helpSections.count == 6)
    }

    @Test("help section titles match settings groups in order")
    func helpSectionTitlesMatchSettingsGroups() async {
        let expectedTitles = [
            String(localized: "Training Range"),
            String(localized: "Intervals"),
            String(localized: "Sound"),
            String(localized: "Difficulty"),
            String(localized: "Rhythm"),
            String(localized: "Data"),
        ]
        let actualTitles = SettingsScreen.helpSections.map(\.title)
        #expect(actualTitles == expectedTitles)
    }

    @Test("each help section has a non-empty body")
    func helpSectionBodiesNonEmpty() async {
        for section in SettingsScreen.helpSections {
            #expect(!section.body.isEmpty, "Section '\(section.title)' has empty body")
        }
    }

    @Test("concert pitch help contains practical 440 Hz context")
    func concertPitchHelpContainsPracticalContext() async {
        let soundTitle = String(localized: "Sound")
        let soundSection = SettingsScreen.helpSections.first { $0.title == soundTitle }
        #expect(soundSection != nil)
        #expect(soundSection?.body.contains("440") == true)
    }

    @Test("tuning system help contains Equal Temperament reference")
    func tuningSystemHelpContainsKeyTerm() async {
        let soundTitle = String(localized: "Sound")
        let soundSection = SettingsScreen.helpSections.first { $0.title == soundTitle }
        #expect(soundSection != nil)
        let bodyLower = soundSection?.body.lowercased() ?? ""
        #expect(bodyLower.contains("equal temperament") || bodyLower.contains("gleichstufig"))
    }

    // MARK: - Sound Preview

    @Test("previewDuration is 2 seconds")
    func previewDurationValue() async {
        #expect(SettingsScreen.previewDuration == .seconds(2))
    }

    // MARK: - Task 2: Note Range Validation

    @Test("Lower bound range enforces minimum gap from upper bound")
    func lowerBoundRangeEnforcesGap() async {
        // With upper at 84 (C6), lower can go up to 72 (C5)
        let range = SettingsKeys.lowerBoundRange(noteRangeMax: 84)
        #expect(range == 21...72)
        #expect(!range.contains(73))

        // With upper at 48 (C3), lower can go up to 36 (C2)
        let smallRange = SettingsKeys.lowerBoundRange(noteRangeMax: 48)
        #expect(smallRange == 21...36)
    }

    @Test("Upper bound range enforces minimum gap from lower bound")
    func upperBoundRangeEnforcesGap() async {
        // With lower at 36 (C2), upper must be at least 48 (C3)
        let range = SettingsKeys.upperBoundRange(noteRangeMin: 36)
        #expect(range == 48...108)
        #expect(!range.contains(47))

        // With lower at 60 (C4), upper must be at least 72 (C5)
        let highRange = SettingsKeys.upperBoundRange(noteRangeMin: 60)
        #expect(highRange == 72...108)
    }

    // MARK: - Task 3: Reset Functionality

    @Test("PerceptualProfile reset clears all note data")
    func profileResetClearsData() async {
        let profile = PerceptualProfile()

        // Add some training data via observer
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(5.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(3.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))
        #expect(profile.comparisonMean(for: .prime) != nil)

        // Reset
        profile.resetAll()

        // Verify cold start state
        #expect(profile.comparisonMean(for: .prime) == nil)
    }

    @Test("ProgressTimeline reflects profile reset")
    func progressTimelineReflectsProfileReset() async {
        let profile = PerceptualProfile { builder in
            for i in 0..<30 {
                builder.addPoint(
                    MetricPoint(timestamp: Date().addingTimeInterval(Double(i) * 60), value: Double(i) + 1.0),
                    for: .pitch(.unisonPitchDiscrimination)
                )
            }
        }
        let timeline = ProgressTimeline(profile: profile)
        #expect(timeline.state(for: .unisonPitchDiscrimination) != .noData)

        profile.resetAll()

        #expect(timeline.state(for: .unisonPitchDiscrimination) == .noData)
    }

    @Test("Reset deletes all records from SwiftData")
    func resetDeletesAllRecords() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, RhythmOffsetDetectionRecord.self, ContinuousRhythmMatchingRecord.self, configurations: config)
        let context = container.mainContext

        // Insert comparison records
        let comparison1 = PitchDiscriminationRecord(
            referenceNote: 60,
            targetNote: 61,
            centOffset: 2.0,
            isCorrect: true,
            interval: 1,
            tuningSystem: "equalTemperament"
        )
        let comparison2 = PitchDiscriminationRecord(
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
        let comparisonCountBefore = try context.fetchCount(FetchDescriptor<PitchDiscriminationRecord>())
        #expect(comparisonCountBefore == 2)
        let pitchCountBefore = try context.fetchCount(FetchDescriptor<PitchMatchingRecord>())
        #expect(pitchCountBefore == 1)

        // Delete all using TrainingDataStore.deleteAll() (same as SettingsScreen)
        let dataStore = TrainingDataStore(modelContext: context)
        try dataStore.deleteAll()

        // Verify all records deleted
        let comparisonCountAfter = try context.fetchCount(FetchDescriptor<PitchDiscriminationRecord>())
        #expect(comparisonCountAfter == 0)
        let pitchCountAfter = try context.fetchCount(FetchDescriptor<PitchMatchingRecord>())
        #expect(pitchCountAfter == 0)
    }

    // MARK: - Task 5: Range Functions

    @Test("Range functions produce valid ranges with default values")
    func rangeValidityWithDefaults() async {
        let lowerRange = SettingsKeys.lowerBoundRange(noteRangeMax: SettingsKeys.defaultNoteRangeMax.rawValue)
        let upperRange = SettingsKeys.upperBoundRange(noteRangeMin: SettingsKeys.defaultNoteRangeMin.rawValue)

        #expect(lowerRange.contains(SettingsKeys.defaultNoteRangeMin.rawValue))
        #expect(upperRange.contains(SettingsKeys.defaultNoteRangeMax.rawValue))
        #expect(lowerRange.lowerBound == SettingsKeys.absoluteMinNote.rawValue)
        #expect(upperRange.upperBound == SettingsKeys.absoluteMaxNote.rawValue)
    }
}

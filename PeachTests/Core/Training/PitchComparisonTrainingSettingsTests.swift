import Testing
@testable import Peach

@Suite("PitchComparisonTrainingSettings Tests")
struct PitchComparisonTrainingSettingsTests {

    @Test("default values are correct")
    func defaultValues() async {
        let settings = PitchComparisonTrainingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime]
        )

        #expect(settings.noteRange.lowerBound == MIDINote(36))
        #expect(settings.noteRange.upperBound == MIDINote(84))
        #expect(settings.referencePitch == Frequency(440.0))
        #expect(settings.tuningSystem == .equalTemperament)
        #expect(settings.noteDuration == NoteDuration(0.75))
        #expect(settings.varyLoudness == UnitInterval(0.0))
        #expect(settings.minCentDifference == Cents(0.1))
        #expect(settings.maxCentDifference == Cents(100.0))
        #expect(settings.maxLoudnessOffsetDB == AmplitudeDB(10.0))
        #expect(settings.velocity == MIDIVelocity(63))
        #expect(settings.feedbackDuration == .milliseconds(400))
    }

    @Test("from(userSettings) maps user-configurable values correctly")
    func fromUserSettings() async {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72))
        mockSettings.referencePitch = Frequency(432.0)
        mockSettings.noteDuration = NoteDuration(1.5)
        mockSettings.varyLoudness = UnitInterval(0.7)
        mockSettings.tuningSystem = .justIntonation

        let intervals: Set<DirectedInterval> = [.up(.perfectFifth)]
        let settings = PitchComparisonTrainingSettings.from(mockSettings, intervals: intervals)

        #expect(settings.noteRange.lowerBound == MIDINote(48))
        #expect(settings.noteRange.upperBound == MIDINote(72))
        #expect(settings.referencePitch == Frequency(432.0))
        #expect(settings.intervals == intervals)
        #expect(settings.tuningSystem == .justIntonation)
        #expect(settings.noteDuration == NoteDuration(1.5))
        #expect(settings.varyLoudness == UnitInterval(0.7))
    }

    @Test("from(userSettings) keeps constant defaults")
    func fromUserSettingsKeepsDefaults() async {
        let mockSettings = MockUserSettings()
        let settings = PitchComparisonTrainingSettings.from(mockSettings, intervals: [.prime])

        #expect(settings.maxLoudnessOffsetDB == AmplitudeDB(10.0))
        #expect(settings.velocity == MIDIVelocity(63))
        #expect(settings.feedbackDuration == .milliseconds(400))
        #expect(settings.minCentDifference == Cents(0.1))
        #expect(settings.maxCentDifference == Cents(100.0))
    }
}

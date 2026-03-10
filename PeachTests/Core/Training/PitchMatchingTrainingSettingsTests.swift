import Testing
@testable import Peach

@Suite("PitchMatchingTrainingSettings Tests")
struct PitchMatchingTrainingSettingsTests {

    @Test("default values are correct")
    func defaultValues() async {
        let settings = PitchMatchingTrainingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime]
        )

        #expect(settings.noteRange.lowerBound == MIDINote(36))
        #expect(settings.noteRange.upperBound == MIDINote(84))
        #expect(settings.referencePitch == Frequency(440.0))
        #expect(settings.tuningSystem == .equalTemperament)
        #expect(settings.noteDuration == NoteDuration(0.75))
        #expect(settings.varyLoudness == UnitInterval(0.0))
        #expect(settings.initialCentOffsetRange == -20.0...20.0)
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
        let settings = PitchMatchingTrainingSettings.from(mockSettings, intervals: intervals)

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
        let settings = PitchMatchingTrainingSettings.from(mockSettings, intervals: [.prime])

        #expect(settings.maxLoudnessOffsetDB == AmplitudeDB(10.0))
        #expect(settings.velocity == MIDIVelocity(63))
        #expect(settings.feedbackDuration == .milliseconds(400))
        #expect(settings.initialCentOffsetRange == -20.0...20.0)
    }
}

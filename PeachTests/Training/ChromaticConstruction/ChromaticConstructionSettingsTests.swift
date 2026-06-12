import Testing
@testable import Peach

@Suite("ChromaticConstructionSettings")
struct ChromaticConstructionSettingsTests {

    @Test("init carries the supplied fields verbatim")
    func initStoresFields() {
        let settings = ChromaticConstructionSettings(
            lowerAnchor: MIDINote(60),
            outerIntervals: [.up(.perfectFifth)],
            referencePitch: Frequency(440.0)
        )
        #expect(settings.lowerAnchor == MIDINote(60))
        #expect(settings.outerIntervals == [.up(.perfectFifth)])
        #expect(settings.referencePitch == Frequency(440.0))
    }

    @Test("init supports both ascending and descending in outerIntervals")
    func initAcceptsMultipleDirections() {
        let settings = ChromaticConstructionSettings(
            lowerAnchor: MIDINote(60),
            outerIntervals: [.up(.perfectFifth), .down(.perfectFifth)],
            referencePitch: Frequency(440.0)
        )
        #expect(settings.outerIntervals.count == 2)
    }

    @Test("from(userSettings:) pulls only referencePitch from user settings")
    func fromUserSettingsPullsReferencePitchOnly() {
        let userSettings = StubUserSettings(referencePitch: Frequency(432.0))
        let settings = ChromaticConstructionSettings.from(
            userSettings,
            lowerAnchor: MIDINote(60),
            outerIntervals: [.up(.octave)]
        )
        #expect(settings.referencePitch == Frequency(432.0))
        #expect(settings.lowerAnchor == MIDINote(60))
        #expect(settings.outerIntervals == [.up(.octave)])
    }
}

/// Minimal `UserSettings` for tests that exercise only `referencePitch`.
private struct StubUserSettings: UserSettings {
    let referencePitch: Frequency

    var noteRange: NoteRange { NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)) }
    var noteDuration: NoteDuration { NoteDuration(0.75) }
    var soundSource: any SoundSourceID { StubSoundSourceID() }
    var varyLoudness: UnitInterval { UnitInterval(0.0) }
    var intervals: Set<DirectedInterval> { [.up(.perfectFifth)] }
    var tuningSystem: TuningSystem { .equalTemperament }
    var noteGap: Duration { .zero }
    var tempoBPM: TempoBPM { TempoBPM(120) }
    var velocity: MIDIVelocity { .mezzoPiano }
    var autoStartTraining: Bool { false }
}

private struct StubSoundSourceID: SoundSourceID {
    var rawValue: String { "stub" }
    var displayName: String { "" }
}

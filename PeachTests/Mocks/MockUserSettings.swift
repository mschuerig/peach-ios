import Foundation
@testable import Peach

final class MockUserSettings: UserSettings {
    var noteRange: NoteRange = NoteRange(
        lowerBound: MIDINote(SettingsKeys.defaultNoteRangeMin),
        upperBound: MIDINote(SettingsKeys.defaultNoteRangeMax)
    ) { didSet { onSettingsChanged?() } }
    var noteDuration: NoteDuration = NoteDuration(SettingsKeys.defaultNoteDuration) {
        didSet { onSettingsChanged?() }
    }
    var referencePitch: Frequency = Frequency(SettingsKeys.defaultReferencePitch) {
        didSet { onSettingsChanged?() }
    }
    var soundSource: String = SettingsKeys.defaultSoundSource {
        didSet { onSettingsChanged?() }
    }
    var varyLoudness: UnitInterval = UnitInterval(SettingsKeys.defaultVaryLoudness) {
        didSet { onSettingsChanged?() }
    }
    var intervals: Set<DirectedInterval> = [DirectedInterval.prime] {
        didSet { onSettingsChanged?() }
    }
    var tuningSystem: TuningSystem = .equalTemperament {
        didSet { onSettingsChanged?() }
    }
    var noteGap: Duration = .seconds(SettingsKeys.defaultNoteGap) {
        didSet { onSettingsChanged?() }
    }

    // MARK: - Test Control

    var onSettingsChanged: (() -> Void)?

    // MARK: - Test Helpers

    func reset() {
        noteRange = NoteRange(
            lowerBound: MIDINote(SettingsKeys.defaultNoteRangeMin),
            upperBound: MIDINote(SettingsKeys.defaultNoteRangeMax)
        )
        noteDuration = NoteDuration(SettingsKeys.defaultNoteDuration)
        referencePitch = Frequency(SettingsKeys.defaultReferencePitch)
        soundSource = SettingsKeys.defaultSoundSource
        varyLoudness = UnitInterval(SettingsKeys.defaultVaryLoudness)
        intervals = [DirectedInterval.prime]
        tuningSystem = .equalTemperament
        noteGap = .seconds(SettingsKeys.defaultNoteGap)
        onSettingsChanged = nil
    }
}

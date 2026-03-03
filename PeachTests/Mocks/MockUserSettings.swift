import Foundation
@testable import Peach

final class MockUserSettings: UserSettings {
    var noteRange: NoteRange = NoteRange(
        lowerBound: MIDINote(SettingsKeys.defaultNoteRangeMin),
        upperBound: MIDINote(SettingsKeys.defaultNoteRangeMax)
    )
    var noteDuration: NoteDuration = NoteDuration(SettingsKeys.defaultNoteDuration)
    var referencePitch: Frequency = Frequency(SettingsKeys.defaultReferencePitch)
    var soundSource: SoundSourceID = SoundSourceID(SettingsKeys.defaultSoundSource)
    var varyLoudness: UnitInterval = UnitInterval(SettingsKeys.defaultVaryLoudness)
    var intervals: Set<DirectedInterval> = [DirectedInterval.prime]
    var tuningSystem: TuningSystem = .equalTemperament
}

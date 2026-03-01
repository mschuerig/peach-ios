import Foundation
@testable import Peach

final class MockUserSettings: UserSettings {
    var noteRangeMin: MIDINote = MIDINote(SettingsKeys.defaultNoteRangeMin)
    var noteRangeMax: MIDINote = MIDINote(SettingsKeys.defaultNoteRangeMax)
    var noteDuration: NoteDuration = NoteDuration(SettingsKeys.defaultNoteDuration)
    var referencePitch: Frequency = Frequency(SettingsKeys.defaultReferencePitch)
    var soundSource: SoundSourceID = SoundSourceID(SettingsKeys.defaultSoundSource)
    var varyLoudness: UnitInterval = UnitInterval(SettingsKeys.defaultVaryLoudness)
    var intervals: Set<Interval> = [.prime]
    var tuningSystem: TuningSystem = .equalTemperament
}

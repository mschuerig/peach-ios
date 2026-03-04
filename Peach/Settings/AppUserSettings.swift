import Foundation

final class AppUserSettings: UserSettings {
    var noteRange: NoteRange {
        let lower = UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMin) as? Int ?? SettingsKeys.defaultNoteRangeMin
        let upper = UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMax) as? Int ?? SettingsKeys.defaultNoteRangeMax
        guard upper - lower >= NoteRange.minimumSpan else {
            return SettingsKeys.defaultNoteRange
        }
        return NoteRange(lowerBound: MIDINote(lower), upperBound: MIDINote(upper))
    }

    var noteDuration: NoteDuration {
        NoteDuration(UserDefaults.standard.object(forKey: SettingsKeys.noteDuration) as? Double ?? SettingsKeys.defaultNoteDuration)
    }

    var referencePitch: Frequency {
        Frequency(UserDefaults.standard.object(forKey: SettingsKeys.referencePitch) as? Double ?? SettingsKeys.defaultReferencePitch)
    }

    var soundSource: SoundSourceID {
        SoundSourceID(UserDefaults.standard.string(forKey: SettingsKeys.soundSource) ?? SettingsKeys.defaultSoundSource)
    }

    var varyLoudness: UnitInterval {
        UnitInterval(UserDefaults.standard.object(forKey: SettingsKeys.varyLoudness) as? Double ?? SettingsKeys.defaultVaryLoudness)
    }

    var intervals: Set<DirectedInterval> {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.intervals),
              let selection = IntervalSelection(rawValue: raw) else {
            return IntervalSelection.default.intervals
        }
        return selection.intervals
    }

    var tuningSystem: TuningSystem {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.tuningSystem),
              let system = TuningSystem(identifier: raw) else {
            return .equalTemperament
        }
        return system
    }
}

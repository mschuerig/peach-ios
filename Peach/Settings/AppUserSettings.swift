import Foundation

final class AppUserSettings: UserSettings {
    var noteRangeMin: MIDINote {
        MIDINote(UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMin) as? Int ?? SettingsKeys.defaultNoteRangeMin)
    }

    var noteRangeMax: MIDINote {
        MIDINote(UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMax) as? Int ?? SettingsKeys.defaultNoteRangeMax)
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

    var naturalVsMechanical: Double {
        UserDefaults.standard.object(forKey: SettingsKeys.naturalVsMechanical) as? Double ?? SettingsKeys.defaultNaturalVsMechanical
    }
}

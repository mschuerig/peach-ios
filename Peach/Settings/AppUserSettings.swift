import Foundation

final class AppUserSettings: UserSettings {
    var noteRange: NoteRange {
        guard let lower = UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMin) as? Int,
              let upper = UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMax) as? Int,
              upper - lower >= NoteRange.minimumSpan else {
            return SettingsKeys.defaultNoteRange
        }
        return NoteRange(lowerBound: MIDINote(lower), upperBound: MIDINote(upper))
    }

    var noteDuration: NoteDuration {
        guard let raw = UserDefaults.standard.object(forKey: SettingsKeys.noteDuration) as? Double else {
            return SettingsKeys.defaultNoteDuration
        }
        return NoteDuration(raw)
    }

    var referencePitch: Frequency {
        guard let raw = UserDefaults.standard.object(forKey: SettingsKeys.referencePitch) as? Double else {
            return SettingsKeys.defaultReferencePitch
        }
        return Frequency(raw)
    }

    var soundSource: any SoundSourceID {
        let raw = UserDefaults.standard.string(forKey: SettingsKeys.soundSource) ?? SettingsKeys.defaultSoundSource
        return SoundSourceTag(rawValue: raw)
    }

    var varyLoudness: UnitInterval {
        guard let raw = UserDefaults.standard.object(forKey: SettingsKeys.varyLoudness) as? Double else {
            return SettingsKeys.defaultVaryLoudness
        }
        return UnitInterval(raw)
    }

    var intervals: Set<DirectedInterval> {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.intervals),
              let selection = IntervalSelection(rawValue: raw) else {
            return IntervalSelection.default.intervals
        }
        return selection.intervals
    }

    var noteGap: Duration {
        guard let raw = UserDefaults.standard.object(forKey: SettingsKeys.noteGap) as? Double else {
            return SettingsKeys.defaultNoteGap
        }
        return .seconds(raw)
    }

    var tempoBPM: TempoBPM {
        let raw = UserDefaults.standard.integer(forKey: SettingsKeys.tempoBPM)
        guard raw > 0 else { return SettingsKeys.defaultTempoBPM }
        return min(SettingsKeys.maximumTempoBPM, max(SettingsKeys.minimumTempoBPM, TempoBPM(raw)))
    }

    var tuningSystem: TuningSystem {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.tuningSystem),
              let system = TuningSystem(identifier: raw) else {
            return SettingsKeys.defaultTuningSystem
        }
        return system
    }

    var enabledGapPositions: Set<StepPosition> {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKeys.enabledGapPositions) else {
            return SettingsKeys.defaultEnabledGapPositions
        }
        let positions = GapPositionEncoding.decode(raw)
        return positions.isEmpty ? SettingsKeys.defaultEnabledGapPositions : positions
    }
}

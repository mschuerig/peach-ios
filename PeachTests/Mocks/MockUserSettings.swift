import Foundation
@testable import Peach

final class MockUserSettings: UserSettings {
    var noteRange: NoteRange = SettingsKeys.defaultNoteRange {
        didSet { onSettingsChanged?() }
    }
    var noteDuration: NoteDuration = SettingsKeys.defaultNoteDuration {
        didSet { onSettingsChanged?() }
    }
    var referencePitch: Frequency = SettingsKeys.defaultReferencePitch {
        didSet { onSettingsChanged?() }
    }
    var soundSource: any SoundSourceID = SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource) {
        didSet { onSettingsChanged?() }
    }
    var varyLoudness: UnitInterval = SettingsKeys.defaultVaryLoudness {
        didSet { onSettingsChanged?() }
    }
    var intervals: Set<DirectedInterval> = [DirectedInterval.prime] {
        didSet { onSettingsChanged?() }
    }
    var tuningSystem: TuningSystem = SettingsKeys.defaultTuningSystem {
        didSet { onSettingsChanged?() }
    }
    var noteGap: Duration = SettingsKeys.defaultNoteGap {
        didSet { onSettingsChanged?() }
    }
    var tempoBPM: TempoBPM = SettingsKeys.defaultTempoBPM {
        didSet { onSettingsChanged?() }
    }
    var enabledGapPositions: Set<StepPosition> = SettingsKeys.defaultEnabledGapPositions {
        didSet { onSettingsChanged?() }
    }
    var velocity: MIDIVelocity = .mezzoPiano {
        didSet { onSettingsChanged?() }
    }
    var autoStartTraining: Bool = false {
        didSet { onSettingsChanged?() }
    }

    // MARK: - Test Control

    var onSettingsChanged: (() -> Void)?

    // MARK: - Test Helpers

    func reset() {
        noteRange = SettingsKeys.defaultNoteRange
        noteDuration = SettingsKeys.defaultNoteDuration
        referencePitch = SettingsKeys.defaultReferencePitch
        soundSource = SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource)
        varyLoudness = SettingsKeys.defaultVaryLoudness
        intervals = [DirectedInterval.prime]
        tuningSystem = SettingsKeys.defaultTuningSystem
        noteGap = SettingsKeys.defaultNoteGap
        tempoBPM = SettingsKeys.defaultTempoBPM
        enabledGapPositions = SettingsKeys.defaultEnabledGapPositions
        velocity = .mezzoPiano
        autoStartTraining = false
        onSettingsChanged = nil
    }
}

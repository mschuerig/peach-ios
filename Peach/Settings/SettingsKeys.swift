import Foundation

enum SettingsKeys {
    // MARK: - @AppStorage Key Names

    static let noteRangeMin = "noteRangeMin"
    static let noteRangeMax = "noteRangeMax"
    static let noteDuration = "noteDuration"
    static let referencePitch = "referencePitch"
    static let soundSource = "soundSource"
    static let varyLoudness = "varyLoudness"
    static let intervals = "intervals"
    static let tuningSystem = "tuningSystem"
    static let noteGap = "noteGap"
    static let tempoBPM = "tempoBPM"
    static let enabledGapPositions = "enabledGapPositions"
    static let autoStartTraining = "autoStartTraining"

    // MARK: - Default Values (matching TrainingSettings defaults)

    static let defaultNoteRangeMin: MIDINote = 36
    static let defaultNoteRangeMax: MIDINote = 84
    static let defaultNoteDuration: NoteDuration = 1.0
    static let defaultReferencePitch: Frequency = 440.0
    static let defaultSoundSource: String = "sf2:0:0"
    static let defaultVaryLoudness: UnitInterval = 0.0
    static let defaultTuningSystem: TuningSystem = .equalTemperament
    static let defaultNoteGap: Duration = .zero
    static let defaultTempoBPM: TempoBPM = TempoBPM(80)
    static let minimumTempoBPM: TempoBPM = TempoBPM(20)
    static let maximumTempoBPM: TempoBPM = TempoBPM(300)
    static let defaultEnabledGapPositions: Set<StepPosition> = Set(StepPosition.allCases)

    // MARK: - Note Range Constants

    static let defaultNoteRange = NoteRange(
        lowerBound: defaultNoteRangeMin,
        upperBound: defaultNoteRangeMax
    )

    static let absoluteMinNote: MIDINote = 21
    static let absoluteMaxNote: MIDINote = 108

    static func lowerBoundRange(noteRangeMax: Int) -> ClosedRange<Int> {
        absoluteMinNote.rawValue...(noteRangeMax - NoteRange.minimumSpan)
    }

    static func upperBoundRange(noteRangeMin: Int) -> ClosedRange<Int> {
        (noteRangeMin + NoteRange.minimumSpan)...absoluteMaxNote.rawValue
    }

    // MARK: - Sound Source Validation

    static func validateSoundSource(
        against provider: some SoundSourceProvider,
        userDefaults: UserDefaults = .standard
    ) {
        guard let current = userDefaults.string(forKey: soundSource),
              provider.availableSources.contains(where: { $0.rawValue == current }) else {
            userDefaults.set(defaultSoundSource, forKey: soundSource)
            return
        }
    }
}

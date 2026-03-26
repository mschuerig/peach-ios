import SwiftUI

// MARK: - Core Environment Keys

extension EnvironmentValues {
    @Entry var soundSourceProvider: any SoundSourceProvider = PreviewSoundSourceProvider()
    @Entry var progressTimeline = ProgressTimeline(profile: PerceptualProfile())
    @Entry var activeSession: (any TrainingSession)? = nil
    @Entry var perceptualProfile = PerceptualProfile()
    @Entry var dataStoreResetter: (() throws -> Void)? = nil
    @Entry var soundPreviewPlay: ((Duration) async -> Void)? = nil
    @Entry var soundPreviewStop: (() async -> Void)? = nil
    @Entry var prepareImport: ((URL) -> TrainingDataTransferService.FileReadResult)? = nil
    @Entry var executeImport: ((CSVImportParser.ImportResult, TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary)? = nil
    @Entry var trainingDataTransferService: TrainingDataTransferService = TrainingDataTransferService.preview()
    @Entry var userSettings: any UserSettings = PreviewUserSettings()
    @Entry var rhythmPlayer: (any RhythmPlayer)? = nil
    @Entry var stepSequencer: (any StepSequencer)? = nil
    @Entry var midiInput: (any MIDIInput)? = nil
    @Entry var audioSampleRate: SampleRate = .standard48000
}

// MARK: - Session Environment Keys

extension EnvironmentValues {
    @Entry var pitchDiscriminationSession: PitchDiscriminationSession = {
        let dataStore = PreviewPitchDiscriminationDataStore()
        let profile = PerceptualProfile()
        let strategy = PreviewPitchDiscriminationStrategy()
        let observers: [PitchDiscriminationObserver] = [dataStore]
        return PitchDiscriminationSession(
            notePlayer: PreviewNotePlayer(),
            strategy: strategy,
            profile: profile,
            observers: observers
        )
    }()

    @Entry var pitchMatchingSession: PitchMatchingSession = {
        PitchMatchingSession(
            notePlayer: PreviewNotePlayer(),
            profile: PerceptualProfile()
        )
    }()

    @Entry var rhythmOffsetDetectionSession: RhythmOffsetDetectionSession = {
        RhythmOffsetDetectionSession(
            rhythmPlayer: PreviewRhythmPlayer(),
            strategy: PreviewRhythmOffsetDetectionStrategy(),
            profile: PerceptualProfile(),
            sampleRate: .standard48000
        )
    }()

    @Entry var continuousRhythmMatchingSession: ContinuousRhythmMatchingSession = {
        ContinuousRhythmMatchingSession(
            stepSequencer: PreviewStepSequencer()
        )
    }()
}

// MARK: - Preview Stubs

private final class PreviewNotePlayer: NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        PreviewPlaybackHandle()
    }

    func stopAll() async throws {}
}

private final class PreviewPlaybackHandle: PlaybackHandle {
    func stop() async throws {}
    func adjustFrequency(_ frequency: Frequency) async throws {}
}

private final class PreviewPitchDiscriminationDataStore: PitchDiscriminationRecordStoring, PitchDiscriminationObserver {
    func save(_ record: PitchDiscriminationRecord) throws {}
    func fetchAllPitchDiscriminations() throws -> [PitchDiscriminationRecord] { [] }
    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {}
}

private struct PreviewSoundSourceProvider: SoundSourceProvider {
    var availableSources: [any SoundSourceID] { [] }
}

private final class PreviewPitchDiscriminationStrategy: NextPitchDiscriminationStrategy {
    func nextPitchDiscriminationTrial(
        profile: TrainingProfile,
        settings: PitchDiscriminationSettings,
        lastTrial: CompletedPitchDiscriminationTrial?,
        interval: DirectedInterval
    ) -> PitchDiscriminationTrial {
        let referenceNote = MIDINote(60)
        let targetBaseNote = referenceNote.transposed(by: interval)
        return PitchDiscriminationTrial(referenceNote: referenceNote, targetNote: DetunedMIDINote(note: targetBaseNote, offset: Cents(50.0)))
    }
}

private final class PreviewRhythmPlayer: RhythmPlayer {
    func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle {
        PreviewRhythmPlaybackHandle()
    }

    func stopAll() async throws {}
}

private final class PreviewRhythmPlaybackHandle: RhythmPlaybackHandle {
    func stop() async throws {}
}

private final class PreviewStepSequencer: StepSequencer {
    var currentStep: StepPosition?
    var currentCycle: CycleDefinition?
    var timing: SequencerTiming {
        SequencerTiming(samplePosition: 0, samplesPerStep: 0, samplesPerCycle: 0, sampleRate: .standard44100)
    }
    func start(tempo: TempoBPM, stepProvider: any StepProvider) async throws {}
    func stop() async throws {}
    func playImmediateNote(velocity: MIDIVelocity) throws {}
}

private final class PreviewRhythmOffsetDetectionStrategy: NextRhythmOffsetDetectionStrategy {
    func nextRhythmOffsetDetectionTrial(
        profile: TrainingProfile,
        settings: RhythmOffsetDetectionSettings,
        lastResult: CompletedRhythmOffsetDetectionTrial?
    ) -> RhythmOffsetDetectionTrial {
        RhythmOffsetDetectionTrial(tempo: TempoBPM(80), offset: RhythmOffset(.milliseconds(50)))
    }
}

private final class PreviewUserSettings: UserSettings {
    let noteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
    let noteDuration = NoteDuration(0.75)
    let referencePitch = Frequency(440.0)
    let soundSource: any SoundSourceID = SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource)
    let varyLoudness = UnitInterval(0.0)
    let intervals: Set<DirectedInterval> = [.up(.perfectFifth)]
    let tuningSystem: TuningSystem = .equalTemperament
    let noteGap: Duration = SettingsKeys.defaultNoteGap
    let tempoBPM: TempoBPM = SettingsKeys.defaultTempoBPM
    let enabledGapPositions: Set<StepPosition> = SettingsKeys.defaultEnabledGapPositions
}

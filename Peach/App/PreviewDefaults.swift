import SwiftData
import SwiftUI

// MARK: - Stub Types for Environment Key Defaults
//
// SwiftUI evaluates EnvironmentKey.defaultValue at app startup, so these must
// be real (non-crashing) instances. They are inert stubs: safe to construct
// but not intended for production use. PeachApp always injects real instances.

struct StubSoundSourceProvider: SoundSourceProvider {
    var availableSources: [any SoundSourceID] { [] }
}

final class StubNotePlayer: NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        StubPlaybackHandle()
    }
    func stopAll() async throws {}
}

private final class StubPlaybackHandle: PlaybackHandle {
    func stop() async throws {}
    func adjustFrequency(_ frequency: Frequency) async throws {}
}

final class StubUserSettings: UserSettings {
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
    let velocity: MIDIVelocity = SettingsKeys.defaultVelocity
    let autoStartTraining = SettingsKeys.defaultAutoStartTraining
}

final class StubPitchDiscriminationDataStore: PitchDiscriminationObserver {
    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {}
}

final class StubPitchDiscriminationStrategy: NextPitchDiscriminationStrategy {
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

final class StubRhythmPlayer: RhythmPlayer {
    func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle {
        StubRhythmPlaybackHandle()
    }
    func stopAll() async throws {}
}

private final class StubRhythmPlaybackHandle: RhythmPlaybackHandle {
    func stop() async throws {}
}

final class StubStepSequencer: StepSequencer {
    var currentStep: StepPosition?
    var currentCycle: CycleDefinition?
    var timing: SequencerTiming {
        SequencerTiming(samplePosition: 0, samplesPerStep: 0, samplesPerCycle: 0, sampleRate: .standard44100)
    }
    func start(tempo: TempoBPM, stepProvider: any StepProvider) async throws {}
    func stop() async throws {}
    func playImmediateNote(velocity: MIDIVelocity) throws {}
    func samplePosition(forHostTime hostTime: UInt64) -> Int64 { 0 }
}

final class StubTimingOffsetDetectionStrategy: NextTimingOffsetDetectionStrategy {
    func nextTimingOffsetDetectionTrial(
        profile: TrainingProfile,
        settings: TimingOffsetDetectionSettings,
        lastResult: CompletedTimingOffsetDetectionTrial?
    ) -> TimingOffsetDetectionTrial {
        TimingOffsetDetectionTrial(tempo: TempoBPM(80), offset: TimingOffset(.milliseconds(50)))
    }
}

// MARK: - Session Stub Factories

extension PitchDiscriminationSession {
    static let stub: PitchDiscriminationSession = {
        PitchDiscriminationSession(
            notePlayer: StubNotePlayer(),
            strategy: StubPitchDiscriminationStrategy(),
            profile: PerceptualProfile(),
            observers: [StubPitchDiscriminationDataStore()],
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
    }()
}

extension PitchMatchingSession {
    static let stub: PitchMatchingSession = {
        PitchMatchingSession(
            notePlayer: StubNotePlayer(),
            profile: PerceptualProfile(),
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
    }()
}

extension TimingOffsetDetectionSession {
    static let stub: TimingOffsetDetectionSession = {
        TimingOffsetDetectionSession(
            rhythmPlayer: StubRhythmPlayer(),
            strategy: StubTimingOffsetDetectionStrategy(),
            profile: PerceptualProfile(),
            sampleRate: .standard48000,
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
    }()
}

extension ContinuousRhythmMatchingSession {
    static let stub: ContinuousRhythmMatchingSession = {
        ContinuousRhythmMatchingSession(
            stepSequencer: StubStepSequencer(),
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
    }()
}

// MARK: - Coordinator Stub Factories

extension TrainingLifecycleCoordinator {
    static let stub: TrainingLifecycleCoordinator = {
        TrainingLifecycleCoordinator(
            pitchDiscriminationSession: .stub,
            pitchMatchingSession: .stub,
            timingOffsetDetectionSession: .stub,
            continuousRhythmMatchingSession: .stub,
            userSettings: StubUserSettings(),
            backgroundPolicy: IOSBackgroundPolicy()
        )
    }()
}

extension SettingsCoordinator {
    static let stub: SettingsCoordinator = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema(versionedSchema: SchemaV1.self)
        guard let container = try? ModelContainer(
            for: schema,
            migrationPlan: PeachSchemaMigrationPlan.self,
            configurations: config
        ) else {
            fatalError("Failed to create stub ModelContainer for SettingsCoordinator")
        }
        let dataStore = TrainingDataStore(modelContext: container.mainContext)
        let transferService = TrainingDataTransferService.preview()
        return SettingsCoordinator(
            dataStore: dataStore,
            pitchDiscriminationSession: .stub,
            profile: PerceptualProfile(),
            transferService: transferService,
            notePlayer: StubNotePlayer(),
            userSettings: StubUserSettings()
        )
    }()
}

// MARK: - Preview Environment Modifier

#if DEBUG
extension View {
    func previewEnvironment() -> some View {
        self
            .environment(\.soundSourceProvider, StubSoundSourceProvider())
            .environment(\.userSettings, StubUserSettings())
            .environment(\.trainingLifecycle, .stub)
            .environment(\.settingsCoordinator, .stub)
            .environment(\.pitchDiscriminationSession, .stub)
            .environment(\.pitchMatchingSession, .stub)
            .environment(\.timingOffsetDetectionSession, .stub)
            .environment(\.continuousRhythmMatchingSession, .stub)
    }
}
#endif

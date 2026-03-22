import SwiftUI
import SwiftData
import TipKit
import os

@main
struct PeachApp: App {
    @State private var modelContainer: ModelContainer
    @State private var dataStore: TrainingDataStore
    @State private var pitchDiscriminationSession: PitchDiscriminationSession
    @State private var pitchMatchingSession: PitchMatchingSession
    @State private var rhythmOffsetDetectionSession: RhythmOffsetDetectionSession
    @State private var rhythmMatchingSession: RhythmMatchingSession
    @State private var continuousRhythmMatchingSession: ContinuousRhythmMatchingSession
    @State private var profile: PerceptualProfile
    @State private var progressTimeline: ProgressTimeline
    @State private var soundFontLibrary: SoundFontLibrary
    @State private var soundFontEngine: SoundFontEngine
    @State private var transferService: TrainingDataTransferService
    @State private var notePlayer: any NotePlayer
    @State private var rhythmPlayer: any RhythmPlayer
    @State private var stepSequencer: SoundFontStepSequencer
    @State private var activeSession: (any TrainingSession)?
    @AppStorage(SettingsKeys.soundSource) private var soundSource: String = SettingsKeys.defaultSoundSource
    private let userSettings = AppUserSettings()

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        do {
            let container = try ModelContainer(
                for: PitchDiscriminationRecord.self,
                PitchMatchingRecord.self,
                RhythmOffsetDetectionRecord.self,
                RhythmMatchingRecord.self
            )
            _modelContainer = State(wrappedValue: container)

            let dataStore = TrainingDataStore(modelContext: container.mainContext)
            _dataStore = State(wrappedValue: dataStore)

            let sf2URL = Bundle.main.url(forResource: "Samples", withExtension: "sf2")!
            let soundFontLibrary = SoundFontLibrary(sf2URL: sf2URL, defaultPreset: SettingsKeys.defaultSoundSource)
            _soundFontLibrary = State(wrappedValue: soundFontLibrary)
            SettingsKeys.validateSoundSource(against: soundFontLibrary)

            let soundFontEngine = try SoundFontEngine(sf2URL: sf2URL)
            _soundFontEngine = State(wrappedValue: soundFontEngine)

            let preset = soundFontLibrary.resolve(userSettings.soundSource)
            let notePlayer: any NotePlayer = SoundFontPlayer(
                engine: soundFontEngine,
                preset: preset,
                stopPropagationDelay: .zero
            )
            _notePlayer = State(wrappedValue: notePlayer)

            try soundFontEngine.createChannel(SoundFontEngine.ChannelID(1))
            let percussionPreset = soundFontLibrary.percussionPresets.first
                ?? SF2Preset(name: "", program: 0, bank: SF2Preset.percussionBank)
            let percussionChannel = SoundFontEngine.ChannelID(1)
            let rhythmPlayer: any RhythmPlayer = SoundFontPlayer(
                engine: soundFontEngine,
                preset: percussionPreset,
                channel: percussionChannel
            )
            _rhythmPlayer = State(wrappedValue: rhythmPlayer)

            let profile = try Self.loadPerceptualProfile(dataStore: dataStore)
            _profile = State(wrappedValue: profile)

            let progressTimeline = ProgressTimeline(profile: profile)
            _progressTimeline = State(wrappedValue: progressTimeline)

            _transferService = State(wrappedValue: TrainingDataTransferService(
                dataStore: dataStore,
                onDataChanged: { [dataStore, profile] in
                    profile.replaceAll { builder in
                        try? MetricPointMapper.feedAllRecords(from: dataStore, into: builder)
                    }
                }
            ))

            let strategy = KazezNoteStrategy()

            _pitchDiscriminationSession = State(wrappedValue: Self.createPitchDiscriminationSession(
                notePlayer: notePlayer,
                strategy: strategy,
                profile: profile,
                dataStore: dataStore
            ))

            _pitchMatchingSession = State(wrappedValue: Self.createPitchMatchingSession(
                notePlayer: notePlayer,
                profile: profile,
                dataStore: dataStore
            ))

            _rhythmOffsetDetectionSession = State(wrappedValue: Self.createRhythmOffsetDetectionSession(
                rhythmPlayer: rhythmPlayer,
                profile: profile,
                dataStore: dataStore,
                sampleRate: soundFontEngine.sampleRate
            ))

            _rhythmMatchingSession = State(wrappedValue: Self.createRhythmMatchingSession(
                rhythmPlayer: rhythmPlayer,
                profile: profile,
                dataStore: dataStore,
                sampleRate: soundFontEngine.sampleRate
            ))

            let soundFontStepSequencer = SoundFontStepSequencer(
                engine: soundFontEngine,
                preset: percussionPreset,
                channel: percussionChannel
            )
            _stepSequencer = State(wrappedValue: soundFontStepSequencer)

            _continuousRhythmMatchingSession = State(wrappedValue: Self.createContinuousRhythmMatchingSession(
                stepSequencer: soundFontStepSequencer,
                profile: profile,
                dataStore: dataStore
            ))
            try? Tips.configure()
        } catch {
            fatalError("Failed to initialize app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.pitchDiscriminationSession, pitchDiscriminationSession)
                .environment(\.pitchMatchingSession, pitchMatchingSession)
                .environment(\.activeSession, activeSession)
                .environment(\.perceptualProfile, profile)
                .environment(\.progressTimeline, progressTimeline)
                .environment(\.soundSourceProvider, soundFontLibrary)
                .environment(\.userSettings, userSettings)
                .environment(\.soundPreviewPlay, { [notePlayer] (duration: Duration) in
                    let frequency = TuningSystem.equalTemperament.frequency(
                        for: MIDINote(69),
                        referencePitch: userSettings.referencePitch
                    )
                    try? await notePlayer.play(
                        frequency: frequency,
                        duration: duration,
                        velocity: MIDIVelocity(63),
                        amplitudeDB: AmplitudeDB(0)
                    )
                })
                .environment(\.soundPreviewStop, { [notePlayer] in
                    try? await notePlayer.stopAll()
                })
                .environment(\.dataStoreResetter, { [dataStore, pitchDiscriminationSession, profile, transferService] in
                    try dataStore.deleteAll()
                    try pitchDiscriminationSession.resetTrainingData()
                    profile.resetAll()
                    transferService.refreshExport()
                })
                .environment(\.prepareImport, { [transferService] url in
                    transferService.readFileForImport(url: url)
                })
                .environment(\.executeImport, { [transferService] parseResult, mode in
                    try transferService.performImport(parseResult: parseResult, mode: mode)
                })
                .environment(\.trainingDataTransferService, transferService)
                .environment(\.rhythmPlayer, rhythmPlayer)
                .environment(\.stepSequencer, stepSequencer)
                .environment(\.audioSampleRate, soundFontEngine.sampleRate)
                .environment(\.rhythmOffsetDetectionSession, rhythmOffsetDetectionSession)
                .environment(\.rhythmMatchingSession, rhythmMatchingSession)
                .environment(\.continuousRhythmMatchingSession, continuousRhythmMatchingSession)
                .modelContainer(modelContainer)
                .onChange(of: soundSource) { _, newSource in
                    let preset = soundFontLibrary.resolve(SoundSourceTag(rawValue: newSource))
                    let newPlayer = SoundFontPlayer(
                        engine: soundFontEngine,
                        preset: preset,
                        stopPropagationDelay: .zero
                    )
                    notePlayer = newPlayer

                    let strategy = KazezNoteStrategy()
                    pitchDiscriminationSession = Self.createPitchDiscriminationSession(
                        notePlayer: newPlayer,
                        strategy: strategy,
                        profile: profile,
                        dataStore: dataStore
                    )
                    pitchMatchingSession = Self.createPitchMatchingSession(
                        notePlayer: newPlayer,
                        profile: profile,
                        dataStore: dataStore
                    )
                }
                .onChange(of: pitchDiscriminationSession.isIdle) { _, isIdle in
                    if !isIdle {
                        if activeSession !== pitchDiscriminationSession {
                            activeSession?.stop()
                        }
                        activeSession = pitchDiscriminationSession
                    } else if activeSession === pitchDiscriminationSession {
                        activeSession = nil
                    }
                }
                .onChange(of: pitchMatchingSession.isIdle) { _, isIdle in
                    if !isIdle {
                        if activeSession !== pitchMatchingSession {
                            activeSession?.stop()
                        }
                        activeSession = pitchMatchingSession
                    } else if activeSession === pitchMatchingSession {
                        activeSession = nil
                    }
                }
                .onChange(of: rhythmOffsetDetectionSession.isIdle) { _, isIdle in
                    if !isIdle {
                        if activeSession !== rhythmOffsetDetectionSession {
                            activeSession?.stop()
                        }
                        activeSession = rhythmOffsetDetectionSession
                    } else if activeSession === rhythmOffsetDetectionSession {
                        activeSession = nil
                    }
                }
                .onChange(of: rhythmMatchingSession.isIdle) { _, isIdle in
                    if !isIdle {
                        if activeSession !== rhythmMatchingSession {
                            activeSession?.stop()
                        }
                        activeSession = rhythmMatchingSession
                    } else if activeSession === rhythmMatchingSession {
                        activeSession = nil
                    }
                }
                .onChange(of: continuousRhythmMatchingSession.isIdle) { _, isIdle in
                    if !isIdle {
                        if activeSession !== continuousRhythmMatchingSession {
                            activeSession?.stop()
                        }
                        activeSession = continuousRhythmMatchingSession
                    } else if activeSession === continuousRhythmMatchingSession {
                        activeSession = nil
                    }
                }
        }
    }

    // MARK: - Init Helpers

    private static func loadPerceptualProfile(dataStore: TrainingDataStore) throws -> PerceptualProfile {
        let (profile, elapsed) = try withTiming {
            try PerceptualProfile { builder in
                try MetricPointMapper.feedAllRecords(from: dataStore, into: builder)
            }
        }
        logger.info("Profile loaded in \(elapsed)ms")
        return profile
    }

    private static func createPitchDiscriminationSession(
        notePlayer: NotePlayer,
        strategy: NextPitchDiscriminationStrategy,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore
    ) -> PitchDiscriminationSession {
        let hapticManager = HapticFeedbackManager()
        let observers: [PitchDiscriminationObserver] = [dataStore, profile, hapticManager]
        return PitchDiscriminationSession(
            notePlayer: notePlayer,
            strategy: strategy,
            profile: profile,
            observers: observers
        )
    }

    private static func createRhythmOffsetDetectionSession(
        rhythmPlayer: RhythmPlayer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        sampleRate: SampleRate
    ) -> RhythmOffsetDetectionSession {
        let hapticManager = HapticFeedbackManager()
        let observers: [RhythmOffsetDetectionObserver] = [dataStore, profile, hapticManager]
        return RhythmOffsetDetectionSession(
            rhythmPlayer: rhythmPlayer,
            strategy: AdaptiveRhythmOffsetDetectionStrategy(),
            profile: profile,
            observers: observers,
            sampleRate: sampleRate
        )
    }

    private static func createRhythmMatchingSession(
        rhythmPlayer: RhythmPlayer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        sampleRate: SampleRate
    ) -> RhythmMatchingSession {
        let observers: [RhythmMatchingObserver] = [dataStore, profile]
        return RhythmMatchingSession(
            rhythmPlayer: rhythmPlayer,
            observers: observers,
            sampleRate: sampleRate
        )
    }

    private static func createContinuousRhythmMatchingSession(
        stepSequencer: StepSequencer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore
    ) -> ContinuousRhythmMatchingSession {
        let observers: [ContinuousRhythmMatchingObserver] = []
        return ContinuousRhythmMatchingSession(
            stepSequencer: stepSequencer,
            observers: observers
        )
    }

    private static func createPitchMatchingSession(
        notePlayer: NotePlayer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore
    ) -> PitchMatchingSession {
        PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            observers: [dataStore, profile],
            backgroundNotificationName: UIApplication.didEnterBackgroundNotification,
            foregroundNotificationName: UIApplication.willEnterForegroundNotification
        )
    }
}

// MARK: - Timing

private func withTiming<T>(_ body: () throws -> T) rethrows -> (result: T, milliseconds: Double) {
    let clock = ContinuousClock()
    let start = clock.now
    let result = try body()
    let elapsed = Double((clock.now - start).components.attoseconds) / 1e15
    return (result, elapsed)
}

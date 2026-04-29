import MIDIKitIO
import SwiftUI
import SwiftData
import TipKit
import os

@main
struct PeachApp: App {
    private static let backgroundNotificationName: Notification.Name? = PlatformNotifications.background

    private static func makeAudioInterruptionObserver() -> AudioInterruptionObserving {
        #if os(iOS)
        IOSAudioInterruptionObserver()
        #elseif os(macOS)
        NoOpAudioInterruptionObserver()
        #else
        #error("Unsupported platform")
        #endif
    }

    @State private var modelContainer: ModelContainer
    @State private var dataStore: TrainingDataStore
    @State private var pitchDiscriminationSession: PitchDiscriminationSession
    @State private var pitchMatchingSession: PitchMatchingSession
    @State private var timingOffsetDetectionSession: TimingOffsetDetectionSession
    @State private var continuousRhythmMatchingSession: ContinuousRhythmMatchingSession
    @State private var profile: PerceptualProfile
    @State private var progressTimeline: ProgressTimeline
    @State private var soundFontLibrary: SoundFontLibrary
    @State private var soundFontEngine: SoundFontEngine
    @State private var transferService: TrainingDataTransferService
    @State private var notePlayer: any NotePlayer
    @State private var rhythmPlayer: any RhythmPlayer
    @State private var stepSequencer: SoundFontStepSequencer
    @State private var midiAdapter: MIDIKitAdapter?
    @State private var activeSession: (any TrainingSession)?
    @State private var trainingLifecycle: TrainingLifecycleCoordinator
    @State private var settingsCoordinator: SettingsCoordinator
    @AppStorage(SettingsKeys.soundSource) private var soundSource: String = SettingsKeys.defaultSoundSource
    private let userSettings = AppUserSettings()
    private let crmUserSettings = AppContinuousRhythmMatchingUserSettings()

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        TrainingDisciplineRegistry.bootstrap(disciplines: DisciplineBootstrap.allDisciplines)
        CSVHistoryRegistry.bootstrap(histories: DisciplineBootstrap.allCSVHistories)

        #if os(macOS)
        configureSingleWindowApp()
        #endif

        do {
            let (container, dataStore) = try Self.setupDataStore()
            _modelContainer = State(wrappedValue: container)
            _dataStore = State(wrappedValue: dataStore)

            let (library, engine) = try Self.setupSoundFontInfrastructure()
            _soundFontLibrary = State(wrappedValue: library)
            _soundFontEngine = State(wrappedValue: engine)

            let audio = try Self.setupPlayers(engine: engine, library: library, userSettings: userSettings)
            _notePlayer = State(wrappedValue: audio.notePlayer)
            _rhythmPlayer = State(wrappedValue: audio.rhythmPlayer)
            _stepSequencer = State(wrappedValue: audio.stepSequencer)

            let (profile, progressTimeline) = try Self.setupProfile(dataStore: dataStore)
            _profile = State(wrappedValue: profile)
            _progressTimeline = State(wrappedValue: progressTimeline)

            let transferService = Self.createTransferService(dataStore: dataStore, profile: profile)
            _transferService = State(wrappedValue: transferService)

            let sessions = Self.createAllSessions(
                notePlayer: audio.notePlayer,
                rhythmPlayer: audio.rhythmPlayer,
                stepSequencer: audio.stepSequencer,
                sampleRate: engine.sampleRate,
                profile: profile,
                dataStore: dataStore
            )
            _pitchDiscriminationSession = State(wrappedValue: sessions.pitchDiscrimination)
            _pitchMatchingSession = State(wrappedValue: sessions.pitchMatching)
            _timingOffsetDetectionSession = State(wrappedValue: sessions.timingOffsetDetection)
            _continuousRhythmMatchingSession = State(wrappedValue: sessions.continuousRhythmMatching)
            _midiAdapter = State(wrappedValue: sessions.midiAdapter)

            let coordinators = Self.buildCoordinators(
                pitchDiscriminationSession: sessions.pitchDiscrimination,
                pitchMatchingSession: sessions.pitchMatching,
                timingOffsetDetectionSession: sessions.timingOffsetDetection,
                continuousRhythmMatchingSession: sessions.continuousRhythmMatching,
                dataStore: dataStore,
                profile: profile,
                transferService: transferService,
                notePlayer: audio.notePlayer,
                userSettings: userSettings,
                crmUserSettings: crmUserSettings
            )
            _trainingLifecycle = State(wrappedValue: coordinators.lifecycle)
            _settingsCoordinator = State(wrappedValue: coordinators.settings)

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
                .environment(\.timingOffsetDetectionSession, timingOffsetDetectionSession)
                .environment(\.continuousRhythmMatchingSession, continuousRhythmMatchingSession)
                .environment(\.activeSession, activeSession)
                .environment(\.perceptualProfile, profile)
                .environment(\.progressTimeline, progressTimeline)
                .environment(\.soundSourceProvider, soundFontLibrary)
                .environment(\.userSettings, userSettings)
                .environment(\.settingsCoordinator, settingsCoordinator)
                .environment(\.trainingLifecycle, trainingLifecycle)
                .environment(\.rhythmPlayer, rhythmPlayer)
                .environment(\.stepSequencer, stepSequencer)
                .environment(\.audioSampleRate, soundFontEngine.sampleRate)
                .environment(\.midiInput, midiAdapter)
                .modelContainer(modelContainer)
                .onChange(of: soundSource) { _, newSource in
                    handleSoundSourceChanged(newSource)
                }
                .onChange(of: pitchDiscriminationSession.isIdle) { _, isIdle in
                    trackActiveSession(pitchDiscriminationSession, isIdle: isIdle)
                }
                .onChange(of: pitchMatchingSession.isIdle) { _, isIdle in
                    trackActiveSession(pitchMatchingSession, isIdle: isIdle)
                }
                .onChange(of: timingOffsetDetectionSession.isIdle) { _, isIdle in
                    trackActiveSession(timingOffsetDetectionSession, isIdle: isIdle)
                }
                .onChange(of: continuousRhythmMatchingSession.isIdle) { _, isIdle in
                    trackActiveSession(continuousRhythmMatchingSession, isIdle: isIdle)
                }
        }
        #if os(macOS)
        .defaultSize(width: 500, height: 700)
        .commands {
            PeachCommands()
        }
        #endif

        #if os(macOS)
        Window("Settings", id: "settings") {
            NavigationStack {
                SettingsScreen()
            }
            .environment(\.soundSourceProvider, soundFontLibrary)
            .environment(\.settingsCoordinator, settingsCoordinator)
            .modelContainer(modelContainer)
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)
        #endif
    }

    // MARK: - Active Session Tracking

    private func trackActiveSession(_ session: some TrainingSession, isIdle: Bool) {
        if !isIdle {
            if activeSession !== session {
                activeSession?.stop()
            }
            activeSession = session
        } else if activeSession === session {
            activeSession = nil
        }
        trainingLifecycle.activeSession = activeSession
    }

    // MARK: - Sound Source Change

    private func handleSoundSourceChanged(_ newSource: String) {
        let preset = soundFontLibrary.resolve(SoundSourceTag(rawValue: newSource))
        let newNotePlayer = SoundFontPlayer(
            engine: soundFontEngine,
            preset: preset,
            channel: MIDIChannel(0),
            fadeOutDuration: Self.determineFadeOutDuration(for: preset)
        )
        notePlayer = newNotePlayer

        let strategy = KazezNoteStrategy()
        pitchDiscriminationSession = Self.createPitchDiscriminationSession(
            notePlayer: newNotePlayer,
            strategy: strategy,
            profile: profile,
            dataStore: dataStore,
            hapticFeedback: Self.makeHapticFeedbackManager()
        )
        pitchMatchingSession = Self.createPitchMatchingSession(
            notePlayer: newNotePlayer,
            profile: profile,
            dataStore: dataStore,
            midiInput: midiAdapter
        )
        rebuildCoordinators()
    }

    private func rebuildCoordinators() {
        let coordinators = Self.buildCoordinators(
            pitchDiscriminationSession: pitchDiscriminationSession,
            pitchMatchingSession: pitchMatchingSession,
            timingOffsetDetectionSession: timingOffsetDetectionSession,
            continuousRhythmMatchingSession: continuousRhythmMatchingSession,
            dataStore: dataStore,
            profile: profile,
            transferService: transferService,
            notePlayer: notePlayer,
            userSettings: userSettings,
            crmUserSettings: crmUserSettings
        )
        trainingLifecycle = coordinators.lifecycle
        settingsCoordinator = coordinators.settings
    }

    // MARK: - Data Store Setup

    /// Builds the model container, recovering from a schema-incompatible on-disk store by
    /// wiping it and recreating from scratch.
    ///
    /// The single supported migration path between incompatible schema versions is CSV
    /// export/import; pre-77.4 stores at SwiftData schema version (1, 0, 0) cannot be
    /// migrated automatically because the entity set itself changed. If the on-disk store
    /// is incompatible, this method deletes the store files and recreates an empty
    /// container so the app can launch into an empty state rather than crashing.
    private static func setupDataStore() throws -> (ModelContainer, TrainingDataStore) {
        let schema = Schema(versionedSchema: SchemaV1.self)
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PeachSchemaMigrationPlan.self
            )
            return (container, TrainingDataStore(modelContext: container.mainContext))
        } catch {
            logger.error("ModelContainer init failed: \(error.localizedDescription, privacy: .public). Wiping incompatible store and retrying.")
            try wipeDefaultStoreFiles()
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PeachSchemaMigrationPlan.self
            )
            return (container, TrainingDataStore(modelContext: container.mainContext))
        }
    }

    private static func wipeDefaultStoreFiles() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let candidates = ["default.store", "default.store-shm", "default.store-wal"]
        for name in candidates {
            let url = appSupport.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Audio Setup

    private static func setupSoundFontInfrastructure() throws -> (SoundFontLibrary, SoundFontEngine) {
        guard let sf2URL = Bundle.main.url(forResource: "Samples", withExtension: "sf2") else {
            fatalError("Required resource Samples.sf2 not found in bundle")
        }
        let library = SoundFontLibrary(sf2URL: sf2URL, defaultPreset: SettingsKeys.defaultSoundSource)
        SettingsKeys.validateSoundSource(against: library)

        #if os(iOS)
        let audioSessionConfigurator: AudioSessionConfiguring = IOSAudioSessionConfigurator()
        #elseif os(macOS)
        let audioSessionConfigurator: AudioSessionConfiguring = MacOSAudioSessionConfigurator()
        #else
        #error("Unsupported platform")
        #endif

        let engine = try SoundFontEngine(sf2URL: sf2URL, audioSessionConfigurator: audioSessionConfigurator)
        return (library, engine)
    }

    private static func setupPlayers(
        engine: SoundFontEngine,
        library: SoundFontLibrary,
        userSettings: any UserSettings
    ) throws -> (notePlayer: any NotePlayer, rhythmPlayer: any RhythmPlayer, stepSequencer: SoundFontStepSequencer) {
        let preset = library.resolve(userSettings.soundSource)
        let notePlayer: any NotePlayer = SoundFontPlayer(
            engine: engine,
            preset: preset,
            channel: MIDIChannel(0),
            fadeOutDuration: Self.determineFadeOutDuration(for: preset)
        )

        try engine.createChannel(MIDIChannel(1))
        let percussionPreset = library.percussionPresets.first
            ?? SF2Preset(name: "", program: 0, bank: SF2Preset.percussionBank)
        let percussionChannel = MIDIChannel(1)
        let rhythmPlayer: any RhythmPlayer = SoundFontPlayer(
            engine: engine,
            preset: percussionPreset,
            channel: percussionChannel,
            fadeOutDuration: .zero
        )

        let stepSequencer = SoundFontStepSequencer(
            engine: engine,
            preset: percussionPreset,
            channel: percussionChannel
        )

        return (notePlayer, rhythmPlayer, stepSequencer)
    }

    // MARK: - Fade-Out Duration

    /// Returns the appropriate fade-out duration for a given preset.
    /// Most presets have natural release envelopes and need no fade-out, but synthetic
    /// waveforms (e.g. Sine Wave) click on abrupt stop and benefit from a short fade.
    static func determineFadeOutDuration(for preset: SF2Preset) -> Duration {
        if preset.bank == 8 && preset.program == 80 {
            return .milliseconds(25)
        }
        return .zero
    }

    // MARK: - Profile Setup

    private static func setupProfile(dataStore: TrainingDataStore) throws -> (PerceptualProfile, ProgressTimeline) {
        let (profile, elapsed) = try withTiming {
            try PerceptualProfile { builder in
                try TrainingDisciplineRegistry.shared.feedAllRecords(from: dataStore, into: builder)
            }
        }
        logger.info("Profile loaded in \(elapsed)ms")
        let progressTimeline = ProgressTimeline(profile: profile)
        return (profile, progressTimeline)
    }

    private static func createTransferService(
        dataStore: TrainingDataStore,
        profile: PerceptualProfile
    ) -> TrainingDataTransferService {
        TrainingDataTransferService(
            dataStore: dataStore,
            onDataChanged: { [dataStore, profile] in
                profile.replaceAll { builder in
                    try? TrainingDisciplineRegistry.shared.feedAllRecords(from: dataStore, into: builder)
                }
            }
        )
    }

    // MARK: - Session Creation

    private static func makeHapticFeedbackManager() -> some HapticFeedback & PitchDiscriminationObserver & TimingOffsetDetectionObserver {
        #if os(iOS)
        HapticFeedbackManager()
        #elseif os(macOS)
        NoOpHapticFeedbackManager()
        #else
        #error("Unsupported platform")
        #endif
    }

    private static func createAllSessions(
        notePlayer: any NotePlayer,
        rhythmPlayer: any RhythmPlayer,
        stepSequencer: SoundFontStepSequencer,
        sampleRate: SampleRate,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore
    ) -> (
        pitchDiscrimination: PitchDiscriminationSession,
        pitchMatching: PitchMatchingSession,
        timingOffsetDetection: TimingOffsetDetectionSession,
        continuousRhythmMatching: ContinuousRhythmMatchingSession,
        midiAdapter: MIDIKitAdapter
    ) {
        let midiAdapter = MIDIKitAdapter()
        let hapticManager = makeHapticFeedbackManager()

        let pdSession = createPitchDiscriminationSession(
            notePlayer: notePlayer,
            strategy: KazezNoteStrategy(),
            profile: profile,
            dataStore: dataStore,
            hapticFeedback: hapticManager
        )

        let pmSession = createPitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            dataStore: dataStore,
            midiInput: midiAdapter
        )

        let todSession = createTimingOffsetDetectionSession(
            rhythmPlayer: rhythmPlayer,
            profile: profile,
            dataStore: dataStore,
            sampleRate: sampleRate,
            hapticFeedback: hapticManager
        )

        let crmSession = createContinuousRhythmMatchingSession(
            stepSequencer: stepSequencer,
            profile: profile,
            dataStore: dataStore,
            midiInput: midiAdapter
        )

        return (pdSession, pmSession, todSession, crmSession, midiAdapter)
    }

    private static func createPitchDiscriminationSession(
        notePlayer: NotePlayer,
        strategy: NextPitchDiscriminationStrategy,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        hapticFeedback: some PitchDiscriminationObserver
    ) -> PitchDiscriminationSession {
        let profileAdapter = PitchDiscriminationProfileAdapter(profile: profile)
        let storeAdapter = PitchDiscriminationStoreAdapter(store: dataStore)
        let observers: [PitchDiscriminationObserver] = [storeAdapter, profileAdapter, hapticFeedback]
        return PitchDiscriminationSession(
            notePlayer: notePlayer,
            strategy: strategy,
            profile: profile,
            observers: observers,
            audioInterruptionObserver: makeAudioInterruptionObserver(),
            backgroundNotificationName: backgroundNotificationName
        )
    }

    private static func createTimingOffsetDetectionSession(
        rhythmPlayer: RhythmPlayer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        sampleRate: SampleRate,
        hapticFeedback: some TimingOffsetDetectionObserver
    ) -> TimingOffsetDetectionSession {
        let profileAdapter = TimingOffsetDetectionProfileAdapter(profile: profile)
        let storeAdapter = TimingOffsetDetectionStoreAdapter(store: dataStore)
        let observers: [TimingOffsetDetectionObserver] = [storeAdapter, profileAdapter, hapticFeedback]
        return TimingOffsetDetectionSession(
            rhythmPlayer: rhythmPlayer,
            strategy: AdaptiveTimingOffsetDetectionStrategy(),
            profile: profile,
            observers: observers,
            sampleRate: sampleRate,
            audioInterruptionObserver: makeAudioInterruptionObserver(),
            backgroundNotificationName: backgroundNotificationName
        )
    }

    private static func createContinuousRhythmMatchingSession(
        stepSequencer: StepSequencer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        midiInput: (any MIDIInput)?
    ) -> ContinuousRhythmMatchingSession {
        let profileAdapter = ContinuousRhythmMatchingProfileAdapter(profile: profile)
        let storeAdapter = ContinuousRhythmMatchingStoreAdapter(store: dataStore)
        let observers: [ContinuousRhythmMatchingObserver] = [storeAdapter, profileAdapter]
        return ContinuousRhythmMatchingSession(
            stepSequencer: stepSequencer,
            observers: observers,
            midiInput: midiInput,
            audioInterruptionObserver: makeAudioInterruptionObserver(),
            backgroundNotificationName: backgroundNotificationName
        )
    }

    private static func createPitchMatchingSession(
        notePlayer: NotePlayer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        midiInput: (any MIDIInput)?
    ) -> PitchMatchingSession {
        let profileAdapter = PitchMatchingProfileAdapter(profile: profile)
        let storeAdapter = PitchMatchingStoreAdapter(store: dataStore)
        return PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            observers: [storeAdapter, profileAdapter],
            midiInput: midiInput,
            audioInterruptionObserver: makeAudioInterruptionObserver(),
            backgroundNotificationName: backgroundNotificationName
        )
    }

    // MARK: - Coordinator Construction

    private static func makeBackgroundPolicy() -> BackgroundPolicy {
        #if os(iOS)
        IOSBackgroundPolicy()
        #elseif os(macOS)
        MacOSBackgroundPolicy()
        #else
        #error("Unsupported platform")
        #endif
    }

    private static func buildCoordinators(
        pitchDiscriminationSession: PitchDiscriminationSession,
        pitchMatchingSession: PitchMatchingSession,
        timingOffsetDetectionSession: TimingOffsetDetectionSession,
        continuousRhythmMatchingSession: ContinuousRhythmMatchingSession,
        dataStore: TrainingDataStore,
        profile: PerceptualProfile,
        transferService: TrainingDataTransferService,
        notePlayer: any NotePlayer,
        userSettings: any UserSettings,
        crmUserSettings: any ContinuousRhythmMatchingUserSettings
    ) -> (lifecycle: TrainingLifecycleCoordinator, settings: SettingsCoordinator) {
        let lifecycleRegistry = TrainingLifecycleRegistry { builder in
            pitchDiscriminationSession.contribute(to: builder, userSettings: userSettings)
            pitchMatchingSession.contribute(to: builder, userSettings: userSettings)
            timingOffsetDetectionSession.contribute(to: builder, userSettings: userSettings)
            continuousRhythmMatchingSession.contribute(
                to: builder,
                userSettings: userSettings,
                crmUserSettings: crmUserSettings
            )
        }
        let lifecycle = TrainingLifecycleCoordinator(
            registry: lifecycleRegistry,
            backgroundPolicy: makeBackgroundPolicy(),
            initialAutoStartSetting: userSettings.autoStartTraining
        )
        let settings = SettingsCoordinator(
            dataStore: dataStore,
            pitchDiscriminationSession: pitchDiscriminationSession,
            profile: profile,
            transferService: transferService,
            notePlayer: notePlayer,
            userSettings: userSettings
        )
        return (lifecycle, settings)
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

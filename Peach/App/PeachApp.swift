import MIDIKitIO
import SwiftUI
import SwiftData
import TipKit
import os

@main
struct PeachApp: App {
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
    #if PEACH_RESEARCH
    @State private var chromaticConstructionSession: ChromaticConstructionSession
    #endif
    @State private var profile: PerceptualProfile
    @State private var progressTimeline: ProgressTimeline
    @State private var soundFontLibrary: SoundFontLibrary
    @State private var soundFontEngine: SoundFontEngine
    @State private var transferService: TrainingDataTransferService
    @State private var notePlayer: any NotePlayer
    @State private var beatSequencer: SoundFontBeatSequencer
    @State private var midiAdapter: MIDIKitAdapter?
    @State private var activeSession: (any TrainingSession)?
    @State private var trainingLifecycle: TrainingLifecycleCoordinator
    @State private var settingsCoordinator: SettingsCoordinator
    @State private var audioInfrastructureMonitor: AppAudioInfrastructureMonitor
    @AppStorage(SettingsKeys.soundSource) private var soundSource: String = SettingsKeys.defaultSoundSource
    private let userSettings = AppUserSettings()
    private let crmUserSettings = AppContinuousRhythmMatchingUserSettings()
    private let todUserSettings = AppTimingOffsetDetectionUserSettings()

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
            _beatSequencer = State(wrappedValue: audio.beatSequencer)

            let (profile, progressTimeline) = try Self.setupProfile(dataStore: dataStore)
            _profile = State(wrappedValue: profile)
            _progressTimeline = State(wrappedValue: progressTimeline)

            let transferService = Self.createTransferService(dataStore: dataStore, profile: profile)
            _transferService = State(wrappedValue: transferService)

            let sessions = Self.createAllSessions(
                notePlayer: audio.notePlayer,
                beatSequencer: audio.beatSequencer,
                profile: profile,
                dataStore: dataStore
            )
            _pitchDiscriminationSession = State(wrappedValue: sessions.pitchDiscrimination)
            _pitchMatchingSession = State(wrappedValue: sessions.pitchMatching)
            _timingOffsetDetectionSession = State(wrappedValue: sessions.timingOffsetDetection)
            _continuousRhythmMatchingSession = State(wrappedValue: sessions.continuousRhythmMatching)
            _midiAdapter = State(wrappedValue: sessions.midiAdapter)

            #if PEACH_RESEARCH
            let ccSession = Self.createChromaticConstructionSession(notePlayer: audio.notePlayer)
            _chromaticConstructionSession = State(wrappedValue: ccSession)
            #endif

            let coordinators = Self.buildCoordinators(
                pitchDiscriminationSession: sessions.pitchDiscrimination,
                pitchMatchingSession: sessions.pitchMatching,
                timingOffsetDetectionSession: sessions.timingOffsetDetection,
                continuousRhythmMatchingSession: sessions.continuousRhythmMatching,
                chromaticConstructionSession: {
                    #if PEACH_RESEARCH
                    return ccSession
                    #else
                    return nil
                    #endif
                }(),
                dataStore: dataStore,
                profile: profile,
                transferService: transferService,
                notePlayer: audio.notePlayer,
                soundFontEngine: engine,
                userSettings: userSettings,
                crmUserSettings: crmUserSettings,
                todUserSettings: todUserSettings
            )
            _trainingLifecycle = State(wrappedValue: coordinators.lifecycle)
            _settingsCoordinator = State(wrappedValue: coordinators.settings)

            // The app-scoped audio observer routes the three iOS audio-lifecycle
            // notifications to coordinator methods. Tokens are retained on the
            // monitor for the duration of the app process.
            _audioInfrastructureMonitor = State(wrappedValue: AppAudioInfrastructureMonitor(
                observer: Self.makeAudioInterruptionObserver(),
                coordinator: coordinators.lifecycle
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
                .environment(\.timingOffsetDetectionSession, timingOffsetDetectionSession)
                .environment(\.continuousRhythmMatchingSession, continuousRhythmMatchingSession)
                #if PEACH_RESEARCH
                .environment(\.chromaticConstructionSession, chromaticConstructionSession)
                #endif
                .environment(\.activeSession, activeSession)
                .environment(\.perceptualProfile, profile)
                .environment(\.progressTimeline, progressTimeline)
                .environment(\.soundSourceProvider, soundFontLibrary)
                .environment(\.userSettings, userSettings)
                .environment(\.settingsCoordinator, settingsCoordinator)
                .environment(\.trainingLifecycle, trainingLifecycle)
                .environment(\.beatSequencer, beatSequencer)
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
                #if PEACH_RESEARCH
                .onChange(of: chromaticConstructionSession.isIdle) { _, isIdle in
                    trackActiveSession(chromaticConstructionSession, isIdle: isIdle)
                }
                #endif
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
        // Stop every non-idle session before `rebuildCoordinators()` replaces
        // `trainingLifecycle` — otherwise a paused TOD/CRM would survive with no
        // coordinator holding its `pausedDestination`, unrecoverable until
        // toggled manually.
        var sessionsToStop: [any TrainingSession] = [
            pitchDiscriminationSession,
            pitchMatchingSession,
            timingOffsetDetectionSession,
            continuousRhythmMatchingSession,
        ]
        #if PEACH_RESEARCH
        sessionsToStop.append(chromaticConstructionSession)
        #endif
        for session in sessionsToStop where !session.isIdle {
            session.stop()
        }

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
        #if PEACH_RESEARCH
        chromaticConstructionSession = Self.createChromaticConstructionSession(notePlayer: newNotePlayer)
        #endif
        rebuildCoordinators()
    }

    private func rebuildCoordinators() {
        let coordinators = Self.buildCoordinators(
            pitchDiscriminationSession: pitchDiscriminationSession,
            pitchMatchingSession: pitchMatchingSession,
            timingOffsetDetectionSession: timingOffsetDetectionSession,
            continuousRhythmMatchingSession: continuousRhythmMatchingSession,
            chromaticConstructionSession: {
                #if PEACH_RESEARCH
                return chromaticConstructionSession
                #else
                return nil
                #endif
            }(),
            dataStore: dataStore,
            profile: profile,
            transferService: transferService,
            notePlayer: notePlayer,
            soundFontEngine: soundFontEngine,
            userSettings: userSettings,
            crmUserSettings: crmUserSettings,
            todUserSettings: todUserSettings
        )
        trainingLifecycle = coordinators.lifecycle
        settingsCoordinator = coordinators.settings
        // The prior monitor's `[weak coordinator]` closures point at the
        // now-replaced coordinator instance. Recreate the monitor so the
        // centralized observer routes to the live coordinator. Replacing the
        // `@State` wrapper drops the old monitor; its `isolated deinit` removes
        // its tokens.
        audioInfrastructureMonitor = AppAudioInfrastructureMonitor(
            observer: Self.makeAudioInterruptionObserver(),
            coordinator: coordinators.lifecycle
        )
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
    ///
    /// Recoverable conditions outside schema incompatibility — disk-full, file-permission,
    /// encrypted-store unlock failure, corrupted shm/wal — propagate unchanged. Wiping
    /// those would silently destroy user data the failure didn't actually invalidate.
    private static func setupDataStore() throws -> (ModelContainer, TrainingDataStore) {
        let schema = Schema(versionedSchema: SchemaV1.self)
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PeachSchemaMigrationPlan.self
            )
            return (container, TrainingDataStore(modelContext: container.mainContext))
        } catch {
            let nserror = error as NSError
            guard PeachSchemaCompatibility.shouldWipeStore(after: error) else {
                logger.error("ModelContainer init failed with non-recoverable error (\(nserror.domain, privacy: .public) #\(nserror.code, privacy: .public)): \(error.localizedDescription, privacy: .public). Rethrowing without wiping.")
                throw error
            }
            // The classifier matches SwiftDataError's "Container" + "Migration" groupings
            // plus the Core Data hash-mismatch code — broader than literal schema mismatch.
            logger.error("ModelContainer init failed with a schema-or-container-load error (\(nserror.domain, privacy: .public) #\(nserror.code, privacy: .public)): \(error.localizedDescription, privacy: .public). Wiping store and retrying.")
            do {
                try wipeDefaultStoreFiles()
            } catch let wipeError {
                logger.error("wipeDefaultStoreFiles failed after schema-or-container-load error: \(wipeError.localizedDescription, privacy: .public). Rethrowing the original error.")
                throw error
            }
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
    ) throws -> (notePlayer: any NotePlayer, beatSequencer: SoundFontBeatSequencer) {
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

        let beatSequencer = SoundFontBeatSequencer(
            engine: engine,
            preset: percussionPreset,
            channel: percussionChannel
        )

        return (notePlayer, beatSequencer)
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
        beatSequencer: SoundFontBeatSequencer,
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
            beatSequencer: beatSequencer,
            profile: profile,
            dataStore: dataStore,
            hapticFeedback: hapticManager
        )

        let crmSession = createContinuousRhythmMatchingSession(
            beatSequencer: beatSequencer,
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
            observers: observers
        )
    }

    private static func createTimingOffsetDetectionSession(
        beatSequencer: any BeatSequencer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        hapticFeedback: some TimingOffsetDetectionObserver
    ) -> TimingOffsetDetectionSession {
        let profileAdapter = TimingOffsetDetectionProfileAdapter(profile: profile)
        let storeAdapter = TimingOffsetDetectionStoreAdapter(store: dataStore)
        let observers: [TimingOffsetDetectionObserver] = [storeAdapter, profileAdapter, hapticFeedback]
        return TimingOffsetDetectionSession(
            beatSequencer: beatSequencer,
            strategy: AdaptiveTimingOffsetDetectionStrategy(),
            profile: profile,
            observers: observers
        )
    }

    private static func createContinuousRhythmMatchingSession(
        beatSequencer: BeatSequencer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        midiInput: (any MIDIInput)?
    ) -> ContinuousRhythmMatchingSession {
        let profileAdapter = ContinuousRhythmMatchingProfileAdapter(profile: profile)
        let storeAdapter = ContinuousRhythmMatchingStoreAdapter(store: dataStore)
        let observers: [ContinuousRhythmMatchingObserver] = [storeAdapter, profileAdapter]
        return ContinuousRhythmMatchingSession(
            beatSequencer: beatSequencer,
            observers: observers,
            midiInput: midiInput
        )
    }

    #if PEACH_RESEARCH
    private static func createChromaticConstructionSession(
        notePlayer: any NotePlayer
    ) -> ChromaticConstructionSession {
        ChromaticConstructionSession(
            notePlayer: notePlayer,
            strategy: MonotonicPath()
        )
    }
    #endif

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
            midiInput: midiInput
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
        chromaticConstructionSession: ChromaticConstructionSession?,
        dataStore: TrainingDataStore,
        profile: PerceptualProfile,
        transferService: TrainingDataTransferService,
        notePlayer: any NotePlayer,
        soundFontEngine: SoundFontEngine,
        userSettings: any UserSettings,
        crmUserSettings: any ContinuousRhythmMatchingUserSettings,
        todUserSettings: any TimingOffsetDetectionUserSettings
    ) -> (lifecycle: TrainingLifecycleCoordinator, settings: SettingsCoordinator) {
        let lifecycleRegistry = TrainingLifecycleRegistry { builder in
            pitchDiscriminationSession.contribute(to: builder, userSettings: userSettings)
            pitchMatchingSession.contribute(to: builder, userSettings: userSettings)
            timingOffsetDetectionSession.contribute(
                to: builder,
                userSettings: userSettings,
                todUserSettings: todUserSettings
            )
            continuousRhythmMatchingSession.contribute(
                to: builder,
                userSettings: userSettings,
                crmUserSettings: crmUserSettings
            )
            #if PEACH_RESEARCH
            chromaticConstructionSession?.contribute(to: builder, userSettings: userSettings)
            #endif
        }
        let lifecycle = TrainingLifecycleCoordinator(
            registry: lifecycleRegistry,
            backgroundPolicy: makeBackgroundPolicy(),
            initialAutoStartSetting: userSettings.autoStartTraining,
            mediaInfrastructureRebuild: { [soundFontEngine] in
                try await soundFontEngine.rebuildAfterMediaReset()
            }
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

import MIDIKitIO
import SwiftUI
import SwiftData
import TipKit
import os

@main
struct PeachApp: App {
    #if os(iOS)
    private static let backgroundNotificationName: Notification.Name? = UIApplication.didEnterBackgroundNotification
    private static let foregroundNotificationName: Notification.Name? = UIApplication.willEnterForegroundNotification
    #else
    private static let backgroundNotificationName: Notification.Name? = nil
    private static let foregroundNotificationName: Notification.Name? = nil
    #endif

    @State private var modelContainer: ModelContainer
    @State private var dataStore: TrainingDataStore
    @State private var pitchDiscriminationSession: PitchDiscriminationSession
    @State private var pitchMatchingSession: PitchMatchingSession
    @State private var rhythmOffsetDetectionSession: RhythmOffsetDetectionSession
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

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        do {
            let container = try ModelContainer(
                for: PitchDiscriminationRecord.self,
                PitchMatchingRecord.self,
                RhythmOffsetDetectionRecord.self,
                ContinuousRhythmMatchingRecord.self
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

            let transferService = TrainingDataTransferService(
                dataStore: dataStore,
                onDataChanged: { [dataStore, profile] in
                    profile.replaceAll { builder in
                        try? TrainingDisciplineRegistry.shared.feedAllRecords(from: dataStore, into: builder)
                    }
                }
            )
            _transferService = State(wrappedValue: transferService)

            let strategy = KazezNoteStrategy()

            let pdSession = Self.createPitchDiscriminationSession(
                notePlayer: notePlayer,
                strategy: strategy,
                profile: profile,
                dataStore: dataStore
            )
            _pitchDiscriminationSession = State(wrappedValue: pdSession)

            let midiAdapter = MIDIKitAdapter()
            _midiAdapter = State(wrappedValue: midiAdapter)

            let pmSession = Self.createPitchMatchingSession(
                notePlayer: notePlayer,
                profile: profile,
                dataStore: dataStore,
                midiInput: midiAdapter
            )
            _pitchMatchingSession = State(wrappedValue: pmSession)

            let rodSession = Self.createRhythmOffsetDetectionSession(
                rhythmPlayer: rhythmPlayer,
                profile: profile,
                dataStore: dataStore,
                sampleRate: soundFontEngine.sampleRate
            )
            _rhythmOffsetDetectionSession = State(wrappedValue: rodSession)

            let soundFontStepSequencer = SoundFontStepSequencer(
                engine: soundFontEngine,
                preset: percussionPreset,
                channel: percussionChannel
            )
            _stepSequencer = State(wrappedValue: soundFontStepSequencer)

            let crmSession = Self.createContinuousRhythmMatchingSession(
                stepSequencer: soundFontStepSequencer,
                profile: profile,
                dataStore: dataStore,
                midiInput: midiAdapter
            )
            _continuousRhythmMatchingSession = State(wrappedValue: crmSession)

            _trainingLifecycle = State(wrappedValue: TrainingLifecycleCoordinator(
                pitchDiscriminationSession: pdSession,
                pitchMatchingSession: pmSession,
                rhythmOffsetDetectionSession: rodSession,
                continuousRhythmMatchingSession: crmSession,
                userSettings: userSettings
            ))

            _settingsCoordinator = State(wrappedValue: SettingsCoordinator(
                dataStore: dataStore,
                pitchDiscriminationSession: pdSession,
                profile: profile,
                transferService: transferService,
                notePlayer: notePlayer,
                userSettings: userSettings
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
                .environment(\.rhythmOffsetDetectionSession, rhythmOffsetDetectionSession)
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
                .onChange(of: rhythmOffsetDetectionSession.isIdle) { _, isIdle in
                    trackActiveSession(rhythmOffsetDetectionSession, isIdle: isIdle)
                }
                .onChange(of: continuousRhythmMatchingSession.isIdle) { _, isIdle in
                    trackActiveSession(continuousRhythmMatchingSession, isIdle: isIdle)
                }
        }
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
            stopPropagationDelay: .zero
        )
        notePlayer = newNotePlayer

        let strategy = KazezNoteStrategy()
        pitchDiscriminationSession = Self.createPitchDiscriminationSession(
            notePlayer: newNotePlayer,
            strategy: strategy,
            profile: profile,
            dataStore: dataStore
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
        trainingLifecycle = TrainingLifecycleCoordinator(
            pitchDiscriminationSession: pitchDiscriminationSession,
            pitchMatchingSession: pitchMatchingSession,
            rhythmOffsetDetectionSession: rhythmOffsetDetectionSession,
            continuousRhythmMatchingSession: continuousRhythmMatchingSession,
            userSettings: userSettings
        )
        settingsCoordinator = SettingsCoordinator(
            dataStore: dataStore,
            pitchDiscriminationSession: pitchDiscriminationSession,
            profile: profile,
            transferService: transferService,
            notePlayer: notePlayer,
            userSettings: userSettings
        )
    }

    // MARK: - Init Helpers

    private static func loadPerceptualProfile(dataStore: TrainingDataStore) throws -> PerceptualProfile {
        let (profile, elapsed) = try withTiming {
            try PerceptualProfile { builder in
                try TrainingDisciplineRegistry.shared.feedAllRecords(from: dataStore, into: builder)
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
        #if os(iOS)
        let hapticManager = HapticFeedbackManager()
        #endif
        let profileAdapter = PitchDiscriminationProfileAdapter(profile: profile)
        let storeAdapter = PitchDiscriminationStoreAdapter(store: dataStore)
        #if os(iOS)
        let observers: [PitchDiscriminationObserver] = [storeAdapter, profileAdapter, hapticManager]
        #else
        let observers: [PitchDiscriminationObserver] = [storeAdapter, profileAdapter]
        #endif
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
        #if os(iOS)
        let hapticManager = HapticFeedbackManager()
        #endif
        let profileAdapter = RhythmOffsetDetectionProfileAdapter(profile: profile)
        let storeAdapter = RhythmOffsetDetectionStoreAdapter(store: dataStore)
        #if os(iOS)
        let observers: [RhythmOffsetDetectionObserver] = [storeAdapter, profileAdapter, hapticManager]
        #else
        let observers: [RhythmOffsetDetectionObserver] = [storeAdapter, profileAdapter]
        #endif
        return RhythmOffsetDetectionSession(
            rhythmPlayer: rhythmPlayer,
            strategy: AdaptiveRhythmOffsetDetectionStrategy(),
            profile: profile,
            observers: observers,
            sampleRate: sampleRate
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
            midiInput: midiInput
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
            backgroundNotificationName: PeachApp.backgroundNotificationName,
            foregroundNotificationName: PeachApp.foregroundNotificationName
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

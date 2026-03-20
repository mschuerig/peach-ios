import SwiftUI
import SwiftData
import TipKit
import os

@main
struct PeachApp: App {
    @State private var modelContainer: ModelContainer
    @State private var dataStore: TrainingDataStore
    @State private var pitchComparisonSession: PitchComparisonSession
    @State private var pitchMatchingSession: PitchMatchingSession
    @State private var profile: PerceptualProfile
    @State private var progressTimeline: ProgressTimeline
    @State private var soundFontLibrary: SoundFontLibrary
    @State private var soundFontEngine: SoundFontEngine
    @State private var transferService: TrainingDataTransferService
    @State private var notePlayer: any NotePlayer
    @State private var rhythmPlayer: any RhythmPlayer
    @State private var activeSession: (any TrainingSession)?
    @AppStorage(SettingsKeys.soundSource) private var soundSource: String = SettingsKeys.defaultSoundSource

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        do {
            let container = try ModelContainer(for: PitchComparisonRecord.self, PitchMatchingRecord.self)
            _modelContainer = State(wrappedValue: container)

            let dataStore = TrainingDataStore(modelContext: container.mainContext)
            _dataStore = State(wrappedValue: dataStore)

            let sf2URL = Bundle.main.url(forResource: "Samples", withExtension: "sf2")!
            let soundFontLibrary = SoundFontLibrary(sf2URL: sf2URL, defaultPreset: SettingsKeys.defaultSoundSource)
            _soundFontLibrary = State(wrappedValue: soundFontLibrary)
            SettingsKeys.validateSoundSource(against: soundFontLibrary)

            let soundFontEngine = try SoundFontEngine(sf2URL: sf2URL)
            _soundFontEngine = State(wrappedValue: soundFontEngine)

            let preset = soundFontLibrary.resolve(SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource))
            let notePlayer: any NotePlayer = SoundFontPlayer(
                engine: soundFontEngine,
                preset: preset,
                stopPropagationDelay: .zero
            )
            _notePlayer = State(wrappedValue: notePlayer)

            try soundFontEngine.createChannel(SoundFontEngine.ChannelID(1))
            let percussionPreset = soundFontLibrary.percussionPresets.first
                ?? SF2Preset(name: "", program: 0, bank: SF2Preset.percussionBank)
            let rhythmPlayer: any RhythmPlayer = SoundFontPlayer(
                engine: soundFontEngine,
                preset: percussionPreset,
                channel: SoundFontEngine.ChannelID(1)
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

            _pitchComparisonSession = State(wrappedValue: Self.createPitchComparisonSession(
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
            try? Tips.configure()
        } catch {
            fatalError("Failed to initialize app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.pitchComparisonSession, pitchComparisonSession)
                .environment(\.pitchMatchingSession, pitchMatchingSession)
                .environment(\.activeSession, activeSession)
                .environment(\.perceptualProfile, profile)
                .environment(\.progressTimeline, progressTimeline)
                .environment(\.soundSourceProvider, soundFontLibrary)
                .environment(\.userSettings, AppUserSettings())
                .environment(\.soundPreviewPlay, { [notePlayer] (duration: Duration) in
                    let frequency = TuningSystem.equalTemperament.frequency(
                        for: MIDINote(69),
                        referencePitch: AppUserSettings().referencePitch
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
                .environment(\.dataStoreResetter, { [dataStore, pitchComparisonSession, profile, transferService] in
                    try dataStore.deleteAll()
                    try pitchComparisonSession.resetTrainingData()
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
                .environment(\.audioSampleRate, soundFontEngine.sampleRate)
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
                    pitchComparisonSession = Self.createPitchComparisonSession(
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
                .onChange(of: pitchComparisonSession.isIdle) { _, isIdle in
                    if !isIdle {
                        if activeSession !== pitchComparisonSession {
                            activeSession?.stop()
                        }
                        activeSession = pitchComparisonSession
                    } else if activeSession === pitchComparisonSession {
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

    private static func createPitchComparisonSession(
        notePlayer: NotePlayer,
        strategy: NextPitchComparisonStrategy,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore
    ) -> PitchComparisonSession {
        let hapticManager = HapticFeedbackManager()
        let observers: [PitchComparisonObserver] = [dataStore, profile, hapticManager]
        return PitchComparisonSession(
            notePlayer: notePlayer,
            strategy: strategy,
            profile: profile,
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

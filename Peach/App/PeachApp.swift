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
    @State private var transferService: TrainingDataTransferService
    @State private var notePlayer: any NotePlayer
    @State private var activeSession: (any TrainingSession)?
    @State private var userSettings: any UserSettings

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

            let userSettings: any UserSettings = AppUserSettings()
            _userSettings = State(wrappedValue: userSettings)
            let notePlayer: any NotePlayer = try SoundFontNotePlayer(
                library: soundFontLibrary,
                userSettings: userSettings,
                stopPropagationDelay: .zero
            )
            _notePlayer = State(wrappedValue: notePlayer)

            let existingRecords = try dataStore.fetchAllPitchComparisons()
            let pitchMatchingRecords = try dataStore.fetchAllPitchMatchings()

            let profile = Self.loadPerceptualProfile(
                pitchComparisonRecords: existingRecords,
                pitchMatchingRecords: pitchMatchingRecords
            )
            _profile = State(wrappedValue: profile)

            let progressTimeline = ProgressTimeline(
                pitchComparisonRecords: existingRecords,
                pitchMatchingRecords: pitchMatchingRecords
            )
            _progressTimeline = State(wrappedValue: progressTimeline)

            _transferService = State(wrappedValue: TrainingDataTransferService(
                dataStore: dataStore,
                onDataChanged: { [dataStore, profile, progressTimeline] in
                    let comparisons = (try? dataStore.fetchAllPitchComparisons()) ?? []
                    let pitchMatchings = (try? dataStore.fetchAllPitchMatchings()) ?? []
                    profile.resetAll()
                    for record in comparisons {
                        profile.update(note: MIDINote(record.referenceNote), centOffset: Cents(abs(record.centOffset)), isCorrect: record.isCorrect)
                    }
                    for record in pitchMatchings {
                        profile.updateMatching(note: MIDINote(record.referenceNote), centError: Cents(record.userCentError))
                    }
                    progressTimeline.rebuild(pitchComparisonRecords: comparisons, pitchMatchingRecords: pitchMatchings)
                }
            ))

            let strategy = KazezNoteStrategy()

            _pitchComparisonSession = State(wrappedValue: Self.createPitchComparisonSession(
                notePlayer: notePlayer,
                strategy: strategy,
                profile: profile,
                dataStore: dataStore,
                progressTimeline: progressTimeline
            ))

            _pitchMatchingSession = State(wrappedValue: Self.createPitchMatchingSession(
                notePlayer: notePlayer,
                profile: profile,
                dataStore: dataStore,
                progressTimeline: progressTimeline
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
                .environment(\.userSettings, userSettings)
                .environment(\.soundPreviewPlay, { [notePlayer, userSettings] (duration: Duration) in
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
                .modelContainer(modelContainer)
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

    private static func loadPerceptualProfile(
        pitchComparisonRecords: [PitchComparisonRecord],
        pitchMatchingRecords: [PitchMatchingRecord]
    ) -> PerceptualProfile {
        let profile = PerceptualProfile()
        let startTime = CFAbsoluteTimeGetCurrent()
        for record in pitchComparisonRecords {
            profile.update(
                note: MIDINote(record.referenceNote),
                centOffset: Cents(abs(record.centOffset)),
                isCorrect: record.isCorrect
            )
        }
        for record in pitchMatchingRecords {
            profile.updateMatching(note: MIDINote(record.referenceNote), centError: Cents(record.userCentError))
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("Profile loaded from \(pitchComparisonRecords.count) comparison + \(pitchMatchingRecords.count) matching records in \(elapsed, format: .fixed(precision: 1))ms")
        return profile
    }

    private static func createPitchComparisonSession(
        notePlayer: NotePlayer,
        strategy: NextPitchComparisonStrategy,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        progressTimeline: ProgressTimeline
    ) -> PitchComparisonSession {
        let hapticManager = HapticFeedbackManager()
        let observers: [PitchComparisonObserver] = [dataStore, profile, hapticManager, progressTimeline]
        return PitchComparisonSession(
            notePlayer: notePlayer,
            strategy: strategy,
            profile: profile,
            resettables: [progressTimeline],
            observers: observers
        )
    }

    private static func createPitchMatchingSession(
        notePlayer: NotePlayer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        progressTimeline: ProgressTimeline
    ) -> PitchMatchingSession {
        PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            observers: [dataStore, profile, progressTimeline],
            backgroundNotificationName: UIApplication.didEnterBackgroundNotification,
            foregroundNotificationName: UIApplication.willEnterForegroundNotification
        )
    }
}

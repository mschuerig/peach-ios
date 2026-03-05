import SwiftUI
import SwiftData
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
    @State private var activeSession: (any TrainingSession)?

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        do {
            let container = try ModelContainer(for: PitchComparisonRecord.self, PitchMatchingRecord.self)
            _modelContainer = State(wrappedValue: container)

            let dataStore = TrainingDataStore(modelContext: container.mainContext)
            _dataStore = State(wrappedValue: dataStore)

            let soundFontLibrary = SoundFontLibrary()
            _soundFontLibrary = State(wrappedValue: soundFontLibrary)
            SettingsKeys.validateSoundSource(against: soundFontLibrary)

            let userSettings = AppUserSettings()
            let notePlayer = try SoundFontNotePlayer(userSettings: userSettings, stopPropagationDelay: .zero)

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
                onDataChanged: { [profile, progressTimeline] comparisons, pitchMatchings in
                    profile.reset()
                    profile.resetMatching()
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
                userSettings: userSettings,
                dataStore: dataStore,
                progressTimeline: progressTimeline
            ))

            _pitchMatchingSession = State(wrappedValue: Self.createPitchMatchingSession(
                notePlayer: notePlayer,
                profile: profile,
                userSettings: userSettings,
                dataStore: dataStore,
                progressTimeline: progressTimeline
            ))
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
                .environment(\.dataStoreResetter, { [dataStore, pitchComparisonSession, profile] in
                    try dataStore.deleteAll()
                    try pitchComparisonSession.resetTrainingData()
                    profile.resetMatching()
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
        userSettings: UserSettings,
        dataStore: TrainingDataStore,
        progressTimeline: ProgressTimeline
    ) -> PitchComparisonSession {
        let hapticManager = HapticFeedbackManager()
        let observers: [PitchComparisonObserver] = [dataStore, profile, hapticManager, progressTimeline]
        return PitchComparisonSession(
            notePlayer: notePlayer,
            strategy: strategy,
            profile: profile,
            userSettings: userSettings,
            resettables: [progressTimeline],
            observers: observers
        )
    }

    private static func createPitchMatchingSession(
        notePlayer: NotePlayer,
        profile: PerceptualProfile,
        userSettings: UserSettings,
        dataStore: TrainingDataStore,
        progressTimeline: ProgressTimeline
    ) -> PitchMatchingSession {
        PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            observers: [dataStore, profile, progressTimeline],
            userSettings: userSettings,
            backgroundNotificationName: UIApplication.didEnterBackgroundNotification,
            foregroundNotificationName: UIApplication.willEnterForegroundNotification
        )
    }
}

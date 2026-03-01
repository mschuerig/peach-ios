import SwiftUI
import SwiftData
import os

@main
struct PeachApp: App {
    @State private var modelContainer: ModelContainer
    @State private var dataStore: TrainingDataStore
    @State private var comparisonSession: ComparisonSession
    @State private var pitchMatchingSession: PitchMatchingSession
    @State private var profile: PerceptualProfile
    @State private var trendAnalyzer: TrendAnalyzer
    @State private var thresholdTimeline: ThresholdTimeline
    @State private var soundFontLibrary: SoundFontLibrary
    @State private var activeSession: (any TrainingSession)?

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        do {
            let container = try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self)
            _modelContainer = State(wrappedValue: container)

            let dataStore = TrainingDataStore(modelContext: container.mainContext)
            _dataStore = State(wrappedValue: dataStore)

            let soundFontLibrary = SoundFontLibrary()
            _soundFontLibrary = State(wrappedValue: soundFontLibrary)

            let userSettings = AppUserSettings()
            let notePlayer = try SoundFontNotePlayer(userSettings: userSettings, stopPropagationDelay: .zero)

            let existingRecords = try dataStore.fetchAllComparisons()
            let pitchMatchingRecords = try dataStore.fetchAllPitchMatchings()

            let profile = Self.loadPerceptualProfile(
                comparisonRecords: existingRecords,
                pitchMatchingRecords: pitchMatchingRecords
            )
            _profile = State(wrappedValue: profile)

            let trendAnalyzer = TrendAnalyzer(records: existingRecords)
            _trendAnalyzer = State(wrappedValue: trendAnalyzer)

            let thresholdTimeline = ThresholdTimeline(records: existingRecords)
            _thresholdTimeline = State(wrappedValue: thresholdTimeline)

            let strategy = KazezNoteStrategy()

            _comparisonSession = State(wrappedValue: Self.createComparisonSession(
                notePlayer: notePlayer,
                strategy: strategy,
                profile: profile,
                userSettings: userSettings,
                dataStore: dataStore,
                trendAnalyzer: trendAnalyzer,
                thresholdTimeline: thresholdTimeline
            ))

            _pitchMatchingSession = State(wrappedValue: Self.createPitchMatchingSession(
                notePlayer: notePlayer,
                profile: profile,
                userSettings: userSettings,
                dataStore: dataStore
            ))
        } catch {
            fatalError("Failed to initialize app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.comparisonSession, comparisonSession)
                .environment(\.pitchMatchingSession, pitchMatchingSession)
                .environment(\.activeSession, activeSession)
                .environment(\.perceptualProfile, profile)
                .environment(\.trendAnalyzer, trendAnalyzer)
                .environment(\.thresholdTimeline, thresholdTimeline)
                .environment(\.soundFontLibrary, soundFontLibrary)
                .environment(\.soundSourceProvider, soundFontLibrary)
                .environment(\.dataStoreResetter, { [dataStore, comparisonSession, profile] in
                    try dataStore.deleteAll()
                    try comparisonSession.resetTrainingData()
                    profile.resetMatching()
                })
                .modelContainer(modelContainer)
                .onChange(of: comparisonSession.isIdle) { _, isIdle in
                    if !isIdle {
                        if activeSession !== comparisonSession {
                            activeSession?.stop()
                        }
                        activeSession = comparisonSession
                    } else if activeSession === comparisonSession {
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
        comparisonRecords: [ComparisonRecord],
        pitchMatchingRecords: [PitchMatchingRecord]
    ) -> PerceptualProfile {
        let profile = PerceptualProfile()
        let startTime = CFAbsoluteTimeGetCurrent()
        for record in comparisonRecords {
            profile.update(
                note: MIDINote(record.referenceNote),
                centOffset: abs(record.centOffset),
                isCorrect: record.isCorrect
            )
        }
        for record in pitchMatchingRecords {
            profile.updateMatching(note: MIDINote(record.referenceNote), centError: record.userCentError)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("Profile loaded from \(comparisonRecords.count) comparison + \(pitchMatchingRecords.count) matching records in \(elapsed, format: .fixed(precision: 1))ms")
        return profile
    }

    private static func createComparisonSession(
        notePlayer: NotePlayer,
        strategy: NextComparisonStrategy,
        profile: PerceptualProfile,
        userSettings: UserSettings,
        dataStore: TrainingDataStore,
        trendAnalyzer: TrendAnalyzer,
        thresholdTimeline: ThresholdTimeline
    ) -> ComparisonSession {
        let hapticManager = HapticFeedbackManager()
        let observers: [ComparisonObserver] = [dataStore, profile, hapticManager, trendAnalyzer, thresholdTimeline]
        return ComparisonSession(
            notePlayer: notePlayer,
            strategy: strategy,
            profile: profile,
            userSettings: userSettings,
            resettables: [trendAnalyzer, thresholdTimeline],
            observers: observers
        )
    }

    private static func createPitchMatchingSession(
        notePlayer: NotePlayer,
        profile: PerceptualProfile,
        userSettings: UserSettings,
        dataStore: TrainingDataStore
    ) -> PitchMatchingSession {
        PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            observers: [dataStore, profile],
            userSettings: userSettings,
            backgroundNotificationName: UIApplication.didEnterBackgroundNotification,
            foregroundNotificationName: UIApplication.willEnterForegroundNotification
        )
    }
}

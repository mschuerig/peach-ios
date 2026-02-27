import SwiftUI
import SwiftData
import os

@main
struct PeachApp: App {
    @State private var modelContainer: ModelContainer
    @State private var comparisonSession: ComparisonSession
    @State private var pitchMatchingSession: PitchMatchingSession
    @State private var profile: PerceptualProfile
    @State private var trendAnalyzer: TrendAnalyzer
    @State private var thresholdTimeline: ThresholdTimeline
    @State private var soundFontLibrary: SoundFontLibrary

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        do {
            let container = try Self.createModelContainer()
            _modelContainer = State(wrappedValue: container)

            let dataStore = TrainingDataStore(modelContext: container.mainContext)

            let soundFontLibrary = SoundFontLibrary()
            _soundFontLibrary = State(wrappedValue: soundFontLibrary)

            let userSettings = AppUserSettings()
            let notePlayer = try SoundFontNotePlayer(userSettings: userSettings)

            let profile = try Self.loadPerceptualProfile(from: dataStore)
            _profile = State(wrappedValue: profile)

            let existingRecords = try dataStore.fetchAllComparisons()

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
                dataStore: dataStore,
                userSettings: userSettings
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
                .environment(\.perceptualProfile, profile)
                .environment(\.trendAnalyzer, trendAnalyzer)
                .environment(\.thresholdTimeline, thresholdTimeline)
                .environment(\.soundFontLibrary, soundFontLibrary)
                .modelContainer(modelContainer)
        }
    }

    // MARK: - Init Helpers

    private static func createModelContainer() throws -> ModelContainer {
        try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self)
    }

    private static func loadPerceptualProfile(from dataStore: TrainingDataStore) throws -> PerceptualProfile {
        let profile = PerceptualProfile()
        let startTime = CFAbsoluteTimeGetCurrent()
        let existingRecords = try dataStore.fetchAllComparisons()
        for record in existingRecords {
            profile.update(
                note: MIDINote(record.note1),
                centOffset: abs(record.note2CentOffset),
                isCorrect: record.isCorrect
            )
        }
        let pitchMatchingRecords = try dataStore.fetchAllPitchMatchings()
        for record in pitchMatchingRecords {
            profile.updateMatching(note: MIDINote(record.referenceNote), centError: record.userCentError)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("Profile loaded from \(existingRecords.count) comparison + \(pitchMatchingRecords.count) matching records in \(elapsed, format: .fixed(precision: 1))ms")
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
            trendAnalyzer: trendAnalyzer,
            thresholdTimeline: thresholdTimeline,
            observers: observers
        )
    }

    private static func createPitchMatchingSession(
        notePlayer: NotePlayer,
        profile: PerceptualProfile,
        dataStore: TrainingDataStore,
        userSettings: UserSettings
    ) -> PitchMatchingSession {
        PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            observers: [dataStore, profile],
            userSettings: userSettings
        )
    }
}

import SwiftUI
import SwiftData
import os

@main
struct PeachApp: App {
    @State private var modelContainer: ModelContainer
    @State private var trainingSession: TrainingSession
    @State private var profile: PerceptualProfile
    @State private var trendAnalyzer: TrendAnalyzer
    @State private var thresholdTimeline: ThresholdTimeline
    @State private var soundFontLibrary: SoundFontLibrary

    private static let logger = Logger(subsystem: "com.peach.app", category: "AppStartup")

    init() {
        // Create model container
        do {
            let container = try ModelContainer(for: ComparisonRecord.self)
            _modelContainer = State(wrappedValue: container)

            // Create dependencies
            let dataStore = TrainingDataStore(modelContext: container.mainContext)

            // Create SoundFontLibrary — discovers SF2 presets for Settings UI (Story 8.2)
            let soundFontLibrary = SoundFontLibrary()
            _soundFontLibrary = State(wrappedValue: soundFontLibrary)

            // Create SoundFontNotePlayer — sole NotePlayer implementation (Story 8.3)
            let notePlayer = try SoundFontNotePlayer()

            // Create and populate perceptual profile from existing data (Story 4.1, 5.1)
            let profile = PerceptualProfile()
            _profile = State(wrappedValue: profile)
            let startTime = CFAbsoluteTimeGetCurrent()
            let existingRecords = try dataStore.fetchAll()
            for record in existingRecords {
                profile.update(
                    note: record.note1,
                    centOffset: abs(record.note2CentOffset),
                    isCorrect: record.isCorrect
                )
            }
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            Self.logger.info("Profile loaded from \(existingRecords.count) records in \(elapsed, format: .fixed(precision: 1))ms")

            // Create trend analyzer from existing records (Story 5.2)
            let trendAnalyzer = TrendAnalyzer(records: existingRecords)
            _trendAnalyzer = State(wrappedValue: trendAnalyzer)

            // Create threshold timeline from existing records (Story 9.2)
            let thresholdTimeline = ThresholdTimeline(records: existingRecords)
            _thresholdTimeline = State(wrappedValue: thresholdTimeline)

            // KazezNoteStrategy: continuous difficulty chain with random note selection (Story 9.1)
            let strategy = KazezNoteStrategy()

            // Create training session with observer pattern (Story 4.1) and adaptive strategy (Story 4.3)
            // Observers: dataStore (persistence), profile (analytics), hapticManager (feedback), thresholdTimeline (visualization)
            let hapticManager = HapticFeedbackManager()
            let observers: [ComparisonObserver] = [dataStore, profile, hapticManager, trendAnalyzer, thresholdTimeline]
            _trainingSession = State(wrappedValue: TrainingSession(
                notePlayer: notePlayer,
                strategy: strategy,
                profile: profile,
                trendAnalyzer: trendAnalyzer,
                thresholdTimeline: thresholdTimeline,
                observers: observers
            ))
        } catch {
            fatalError("Failed to initialize app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.trainingSession, trainingSession)
                .environment(\.perceptualProfile, profile)
                .environment(\.trendAnalyzer, trendAnalyzer)
                .environment(\.thresholdTimeline, thresholdTimeline)
                .environment(\.soundFontLibrary, soundFontLibrary)
                .modelContainer(modelContainer)
        }
    }
}

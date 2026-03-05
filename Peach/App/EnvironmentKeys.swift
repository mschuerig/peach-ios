import SwiftUI

// MARK: - Core Environment Keys

extension EnvironmentValues {
    @Entry var soundSourceProvider: any SoundSourceProvider = SoundFontLibrary()
    @Entry var progressTimeline = ProgressTimeline()
    @Entry var activeSession: (any TrainingSession)? = nil
    @Entry var perceptualProfile = PerceptualProfile()
    @Entry var dataStoreResetter: (() throws -> Void)? = nil
    @Entry var trainingDataTransferService: TrainingDataTransferService = TrainingDataTransferService.preview()
}

// MARK: - Session Environment Keys

extension EnvironmentValues {
    @Entry var comparisonSession: ComparisonSession = {
        let dataStore = PreviewDataStore()
        let profile = PerceptualProfile()
        let strategy = PreviewComparisonStrategy()
        let observers: [ComparisonObserver] = [dataStore, profile]
        return ComparisonSession(
            notePlayer: PreviewNotePlayer(),
            strategy: strategy,
            profile: profile,
            userSettings: PreviewUserSettings(),
            observers: observers
        )
    }()

    @Entry var pitchMatchingSession: PitchMatchingSession = {
        PitchMatchingSession(
            notePlayer: PreviewNotePlayer(),
            profile: PerceptualProfile(),
            observers: [],
            userSettings: PreviewUserSettings()
        )
    }()
}

// MARK: - Preview Stubs

private final class PreviewNotePlayer: NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        PreviewPlaybackHandle()
    }

    func stopAll() async throws {}
}

private final class PreviewPlaybackHandle: PlaybackHandle {
    func stop() async throws {}
    func adjustFrequency(_ frequency: Frequency) async throws {}
}

private final class PreviewDataStore: ComparisonRecordStoring, ComparisonObserver {
    func save(_ record: ComparisonRecord) throws {}
    func fetchAllComparisons() throws -> [ComparisonRecord] { [] }
    func comparisonCompleted(_ completed: CompletedComparison) {}
}

private final class PreviewComparisonStrategy: NextComparisonStrategy {
    func nextComparison(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?,
        interval: DirectedInterval
    ) -> Comparison {
        let referenceNote = MIDINote(60)
        let targetBaseNote = referenceNote.transposed(by: interval)
        return Comparison(referenceNote: referenceNote, targetNote: DetunedMIDINote(note: targetBaseNote, offset: Cents(50.0)))
    }
}

private final class PreviewUserSettings: UserSettings {
    let noteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
    let noteDuration = NoteDuration(0.75)
    let referencePitch = Frequency(440.0)
    let soundSource = SoundSourceID("sf2:8:80")
    let varyLoudness = UnitInterval(0.0)
    let intervals: Set<DirectedInterval> = [.up(.perfectFifth)]
    let tuningSystem: TuningSystem = .equalTemperament
}

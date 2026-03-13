import SwiftUI

// MARK: - Core Environment Keys

extension EnvironmentValues {
    @Entry var soundSourceProvider: any SoundSourceProvider = SoundFontLibrary()
    @Entry var progressTimeline = ProgressTimeline()
    @Entry var activeSession: (any TrainingSession)? = nil
    @Entry var perceptualProfile = PerceptualProfile()
    @Entry var dataStoreResetter: (() throws -> Void)? = nil
    @Entry var soundPreviewPlay: ((Duration) async -> Void)? = nil
    @Entry var soundPreviewStop: (() async -> Void)? = nil
    @Entry var refreshExport: (() -> Bool)? = nil
    @Entry var prepareImport: ((URL) -> TrainingDataTransferService.FileReadResult)? = nil
    @Entry var executeImport: ((CSVImportParser.ImportResult, TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary)? = nil
    @Entry var trainingDataTransferService: TrainingDataTransferService = TrainingDataTransferService.preview()
    @Entry var userSettings: any UserSettings = PreviewUserSettings()
}

// MARK: - Session Environment Keys

extension EnvironmentValues {
    @Entry var pitchComparisonSession: PitchComparisonSession = {
        let dataStore = PreviewPitchComparisonDataStore()
        let profile = PerceptualProfile()
        let strategy = PreviewPitchComparisonStrategy()
        let observers: [PitchComparisonObserver] = [dataStore, profile]
        return PitchComparisonSession(
            notePlayer: PreviewNotePlayer(),
            strategy: strategy,
            profile: profile,
            observers: observers
        )
    }()

    @Entry var pitchMatchingSession: PitchMatchingSession = {
        PitchMatchingSession(
            notePlayer: PreviewNotePlayer(),
            profile: PerceptualProfile()
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

private final class PreviewPitchComparisonDataStore: PitchComparisonRecordStoring, PitchComparisonObserver {
    func save(_ record: PitchComparisonRecord) throws {}
    func fetchAllPitchComparisons() throws -> [PitchComparisonRecord] { [] }
    func pitchComparisonCompleted(_ completed: CompletedPitchComparison) {}
}

private final class PreviewPitchComparisonStrategy: NextPitchComparisonStrategy {
    func nextPitchComparison(
        profile: PitchComparisonProfile,
        settings: PitchComparisonTrainingSettings,
        lastPitchComparison: CompletedPitchComparison?,
        interval: DirectedInterval
    ) -> PitchComparison {
        let referenceNote = MIDINote(60)
        let targetBaseNote = referenceNote.transposed(by: interval)
        return PitchComparison(referenceNote: referenceNote, targetNote: DetunedMIDINote(note: targetBaseNote, offset: Cents(50.0)))
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

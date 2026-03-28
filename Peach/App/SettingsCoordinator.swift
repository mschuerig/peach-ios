import Foundation

final class SettingsCoordinator {
    private let dataStore: TrainingDataStore
    private let pitchDiscriminationSession: PitchDiscriminationSession
    private let profile: PerceptualProfile
    private let transferService: TrainingDataTransferService
    private let notePlayer: any NotePlayer
    private let userSettings: any UserSettings

    init(
        dataStore: TrainingDataStore,
        pitchDiscriminationSession: PitchDiscriminationSession,
        profile: PerceptualProfile,
        transferService: TrainingDataTransferService,
        notePlayer: any NotePlayer,
        userSettings: any UserSettings
    ) {
        self.dataStore = dataStore
        self.pitchDiscriminationSession = pitchDiscriminationSession
        self.profile = profile
        self.transferService = transferService
        self.notePlayer = notePlayer
        self.userSettings = userSettings
    }

    func resetAllData() throws {
        try dataStore.deleteAll()
        try pitchDiscriminationSession.resetTrainingData()
        profile.resetAll()
        transferService.refreshExport()
    }

    /// A4 (MIDI 69) — the standard tuning reference note.
    private static let previewNote: MIDINote = 69
    /// MIDI velocity 63 — mezzo-piano, a comfortable preview loudness.
    private static let previewVelocity: MIDIVelocity = 63
    /// 0 dB — unity gain, no additional amplitude boost or cut.
    private static let previewAmplitude = AmplitudeDB(0)

    func playSoundPreview(duration: Duration) async {
        let frequency = TuningSystem.equalTemperament.frequency(
            for: Self.previewNote,
            referencePitch: userSettings.referencePitch
        )
        try? await notePlayer.play(
            frequency: frequency,
            duration: duration,
            velocity: Self.previewVelocity,
            amplitudeDB: Self.previewAmplitude
        )
    }

    func stopSoundPreview() async {
        try? await notePlayer.stopAll()
    }

    func refreshExport() {
        transferService.refreshExport()
    }

    var exportFileURL: URL? {
        transferService.exportFileURL
    }

    func formatImportSummary(_ summary: TrainingDataImporter.ImportSummary) -> String {
        transferService.formatImportSummary(summary)
    }

    func prepareImport(url: URL) -> TrainingDataTransferService.FileReadResult {
        transferService.readFileForImport(url: url)
    }

    func executeImport(parseResult: CSVImportParser.ImportResult, mode: TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary {
        try transferService.performImport(parseResult: parseResult, mode: mode)
    }
}

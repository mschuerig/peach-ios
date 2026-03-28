import Foundation

final class SettingsCoordinator {
    let dataStore: TrainingDataStore?
    let pitchDiscriminationSession: PitchDiscriminationSession?
    let profile: PerceptualProfile?
    let transferService: TrainingDataTransferService?
    let notePlayer: (any NotePlayer)?
    let userSettings: (any UserSettings)?

    init(
        dataStore: TrainingDataStore? = nil,
        pitchDiscriminationSession: PitchDiscriminationSession? = nil,
        profile: PerceptualProfile? = nil,
        transferService: TrainingDataTransferService? = nil,
        notePlayer: (any NotePlayer)? = nil,
        userSettings: (any UserSettings)? = nil
    ) {
        self.dataStore = dataStore
        self.pitchDiscriminationSession = pitchDiscriminationSession
        self.profile = profile
        self.transferService = transferService
        self.notePlayer = notePlayer
        self.userSettings = userSettings
    }

    func resetAllData() throws {
        try dataStore?.deleteAll()
        try pitchDiscriminationSession?.resetTrainingData()
        profile?.resetAll()
        transferService?.refreshExport()
    }

    func playSoundPreview(duration: Duration) async {
        guard let notePlayer, let userSettings else { return }
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
    }

    func stopSoundPreview() async {
        try? await notePlayer?.stopAll()
    }

    func prepareImport(url: URL) -> TrainingDataTransferService.FileReadResult? {
        transferService?.readFileForImport(url: url)
    }

    func executeImport(parseResult: CSVImportParser.ImportResult, mode: TrainingDataImporter.ImportMode) throws -> TrainingDataImporter.ImportSummary? {
        try transferService?.performImport(parseResult: parseResult, mode: mode)
    }
}

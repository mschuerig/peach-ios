import Foundation
import Testing
@testable import Peach

@Suite("SettingsCoordinator")
struct SettingsCoordinatorTests {

    @Test("resetAllData is safe when no dependencies are set")
    func resetAllDataSafeWithoutDependencies() throws {
        let coordinator = SettingsCoordinator()

        try coordinator.resetAllData()
    }

    @Test("playSoundPreview is safe when no dependencies are set")
    func playSoundPreviewSafeWithoutDependencies() async {
        let coordinator = SettingsCoordinator()

        await coordinator.playSoundPreview(duration: .seconds(2))
    }

    @Test("stopSoundPreview is safe when no dependencies are set")
    func stopSoundPreviewSafeWithoutDependencies() async {
        let coordinator = SettingsCoordinator()

        await coordinator.stopSoundPreview()
    }

    @Test("prepareImport returns nil when no transfer service is set")
    func prepareImportReturnsNilWithoutService() {
        let coordinator = SettingsCoordinator()

        let result = coordinator.prepareImport(url: URL(filePath: "/test.csv"))

        #expect(result == nil)
    }

    @Test("executeImport returns nil when no transfer service is set")
    func executeImportReturnsNilWithoutService() throws {
        let coordinator = SettingsCoordinator()

        let parseResult = CSVImportParser.ImportResult(records: [:], errors: [])
        let result = try coordinator.executeImport(parseResult: parseResult, mode: .replace)

        #expect(result == nil)
    }

    @Test("playSoundPreview plays note at reference pitch A4")
    func playSoundPreviewPlaysAtReferencePitch() async {
        let mockPlayer = MockNotePlayer()
        let coordinator = SettingsCoordinator(
            notePlayer: mockPlayer,
            userSettings: TestUserSettings()
        )

        await coordinator.playSoundPreview(duration: .seconds(2))

        #expect(mockPlayer.playCallCount == 1)
        #expect(mockPlayer.lastFrequency == 440.0)
    }

    @Test("stopSoundPreview calls stopAll on note player")
    func stopSoundPreviewCallsStopAll() async {
        let mockPlayer = MockNotePlayer()
        let coordinator = SettingsCoordinator(notePlayer: mockPlayer)

        await coordinator.stopSoundPreview()

        #expect(mockPlayer.stopAllCallCount == 1)
    }
}

private struct TestUserSettings: UserSettings {
    let noteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
    let noteDuration = NoteDuration(0.75)
    let referencePitch = Frequency(440.0)
    let soundSource: any SoundSourceID = SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource)
    let varyLoudness = UnitInterval(0.0)
    let intervals: Set<DirectedInterval> = [.up(.perfectFifth)]
    let tuningSystem: TuningSystem = .equalTemperament
    let noteGap: Duration = SettingsKeys.defaultNoteGap
    let tempoBPM: TempoBPM = SettingsKeys.defaultTempoBPM
    let enabledGapPositions: Set<StepPosition> = SettingsKeys.defaultEnabledGapPositions
}

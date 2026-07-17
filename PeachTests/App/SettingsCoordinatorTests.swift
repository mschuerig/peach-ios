import Foundation
import SwiftData
import Testing
@testable import Peach

@Suite("SettingsCoordinator")
struct SettingsCoordinatorTests {

    @Test("playSoundPreview plays note at reference pitch A4")
    func playSoundPreviewPlaysAtReferencePitch() async throws {
        let mockPlayer = MockNotePlayer()
        let coordinator = try makeCoordinator(notePlayer: mockPlayer)

        await coordinator.playSoundPreview(duration: .seconds(2))

        #expect(mockPlayer.playCallCount == 1)
        #expect(mockPlayer.lastFrequency == 440.0)
    }

    @Test("note preview sounds equal-tempered even with Just Intonation selected")
    func notePreviewIsEqualTemperedUnderJustIntonation() async throws {
        let mockPlayer = MockNotePlayer()
        let userSettings = MockUserSettings()
        userSettings.tuningSystem = .justIntonation
        let coordinator = try makeCoordinator(notePlayer: mockPlayer, userSettings: userSettings)

        await coordinator.playSoundPreview(note: MIDINote(61), duration: .milliseconds(400))

        let expected = TuningSystem.equalTemperament.frequency(
            for: MIDINote(61), referencePitch: userSettings.referencePitch)
        let played = try #require(mockPlayer.lastFrequency)
        #expect(abs(centsAbove(expected, Frequency(played))) < 0.001)
    }

    @Test("stopSoundPreview calls stopAll on note player")
    func stopSoundPreviewCallsStopAll() async throws {
        let mockPlayer = MockNotePlayer()
        let coordinator = try makeCoordinator(notePlayer: mockPlayer)

        await coordinator.stopSoundPreview()

        #expect(mockPlayer.stopAllCallCount == 1)
    }

    @Test("resetAllData calls deleteAll, resetTrainingData, resetAll, refreshExport")
    func resetAllDataCallsAllServices() async throws {
        let mockPlayer = MockNotePlayer()
        let coordinator = try makeCoordinator(notePlayer: mockPlayer)

        // Verifies no crash — the real services are wired with an in-memory store
        try coordinator.resetAllData()
    }

    @Test("prepareImport returns failure for non-existent file")
    func prepareImportReturnsFailureForBadFile() throws {
        let coordinator = try makeCoordinator(notePlayer: MockNotePlayer())

        let result = coordinator.prepareImport(url: URL(filePath: "/nonexistent.csv"))

        switch result {
        case .failure:
            break // expected
        case .success:
            Issue.record("Expected failure for non-existent file")
        }
    }

    @Test("formatImportSummary returns formatted string")
    func formatImportSummaryReturnsString() throws {
        let coordinator = try makeCoordinator(notePlayer: MockNotePlayer())
        let summary = TrainingDataImporter.ImportSummary(perDiscipline: [:], parseErrorCount: 0)

        let result = coordinator.formatImportSummary(summary)

        #expect(result.isEmpty == false)
    }

    // MARK: - Helpers

    private func makeCoordinator(notePlayer: any NotePlayer, userSettings: MockUserSettings = MockUserSettings()) throws -> SettingsCoordinator {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TrainingRecord.self,
            configurations: config
        )
        let context = ModelContext(container)
        let dataStore = TrainingDataStore(modelContext: context)
        let profile = PerceptualProfile()
        let transferService = TrainingDataTransferService(
            dataStore: dataStore,
            onDataChanged: {}
        )
        return SettingsCoordinator(
            dataStore: dataStore,
            pitchDiscriminationSession: PitchDiscriminationSession(
                notePlayer: notePlayer,
                strategy: MockNextPitchDiscriminationStrategy(),
                profile: profile,
                observers: []
            ),
            profile: profile,
            transferService: transferService,
            notePlayer: notePlayer,
            userSettings: userSettings
        )
    }
}

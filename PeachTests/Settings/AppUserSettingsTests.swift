import Testing
import Foundation
@testable import Peach

@Suite("AppUserSettings", .serialized)
struct AppUserSettingsTests {

    private static let suiteName = "com.peach.tests.AppUserSettingsTests"

    private func makeSettings() -> AppUserSettings {
        let testDefaults = UserDefaults(suiteName: Self.suiteName)!
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        let settings = AppUserSettings()
        settings.defaults = testDefaults
        return settings
    }

    // MARK: - Default Values (AC #3.2)

    @Test("noteRange returns default when no UserDefaults value set")
    func noteRangeDefault() async {
        let settings = makeSettings()
        #expect(settings.noteRange == SettingsKeys.defaultNoteRange)
    }

    @Test("noteDuration returns default when no UserDefaults value set")
    func noteDurationDefault() async {
        let settings = makeSettings()
        #expect(settings.noteDuration == SettingsKeys.defaultNoteDuration)
    }

    @Test("referencePitch returns default when no UserDefaults value set")
    func referencePitchDefault() async {
        let settings = makeSettings()
        #expect(settings.referencePitch == SettingsKeys.defaultReferencePitch)
    }

    @Test("soundSource returns default when no UserDefaults value set")
    func soundSourceDefault() async {
        let settings = makeSettings()
        #expect(settings.soundSource.rawValue == SettingsKeys.defaultSoundSource)
    }

    @Test("varyLoudness returns default when no UserDefaults value set")
    func varyLoudnessDefault() async {
        let settings = makeSettings()
        #expect(settings.varyLoudness == SettingsKeys.defaultVaryLoudness)
    }

    @Test("intervals returns default when no UserDefaults value set")
    func intervalsDefault() async {
        let settings = makeSettings()
        #expect(settings.intervals == SettingsKeys.defaultIntervalSelection.intervals)
    }

    @Test("tuningSystem returns default when no UserDefaults value set")
    func tuningSystemDefault() async {
        let settings = makeSettings()
        #expect(settings.tuningSystem == SettingsKeys.defaultTuningSystem)
    }

    @Test("noteGap returns default when no UserDefaults value set")
    func noteGapDefault() async {
        let settings = makeSettings()
        #expect(settings.noteGap == SettingsKeys.defaultNoteGap)
    }

    @Test("tempoBPM returns default when no UserDefaults value set")
    func tempoBPMDefault() async {
        let settings = makeSettings()
        #expect(settings.tempoBPM == SettingsKeys.defaultTempoBPM)
    }

    @Test("enabledGapPositions returns default when no UserDefaults value set")
    func enabledGapPositionsDefault() async {
        let settings = makeSettings()
        #expect(settings.enabledGapPositions == SettingsKeys.defaultEnabledGapPositions)
    }

    @Test("autoStartTraining returns default when no UserDefaults value set")
    func autoStartTrainingDefault() async {
        let settings = makeSettings()
        #expect(settings.autoStartTraining == SettingsKeys.defaultAutoStartTraining)
    }

    // MARK: - Validation / Clamping (AC #3.3)

    @Test("noteRange returns default when span is less than minimum")
    func noteRangeTooSmall() async {
        let settings = makeSettings()
        settings.defaults.set(60, forKey: SettingsKeys.noteRangeMin)
        settings.defaults.set(65, forKey: SettingsKeys.noteRangeMax)

        #expect(settings.noteRange == SettingsKeys.defaultNoteRange)
    }

    @Test("tempoBPM clamps above maximum to maximum")
    func tempoBPMClampedAboveMax() async {
        let settings = makeSettings()
        settings.defaults.set(999, forKey: SettingsKeys.tempoBPM)

        #expect(settings.tempoBPM == SettingsKeys.maximumTempoBPM)
    }

    @Test("tempoBPM clamps below minimum to minimum")
    func tempoBPMClampedBelowMin() async {
        let settings = makeSettings()
        settings.defaults.set(5, forKey: SettingsKeys.tempoBPM)

        #expect(settings.tempoBPM == SettingsKeys.minimumTempoBPM)
    }

    @Test("tempoBPM returns default for zero value")
    func tempoBPMZero() async {
        let settings = makeSettings()
        settings.defaults.set(0, forKey: SettingsKeys.tempoBPM)

        #expect(settings.tempoBPM == SettingsKeys.defaultTempoBPM)
    }

    @Test("tuningSystem returns default for invalid identifier")
    func tuningSystemInvalid() async {
        let settings = makeSettings()
        settings.defaults.set("nonexistentTuning", forKey: SettingsKeys.tuningSystem)

        #expect(settings.tuningSystem == SettingsKeys.defaultTuningSystem)
    }

    @Test("intervals returns default for invalid raw value")
    func intervalsInvalid() async {
        let settings = makeSettings()
        settings.defaults.set(";;;garbage;;;", forKey: SettingsKeys.intervals)

        #expect(settings.intervals == SettingsKeys.defaultIntervalSelection.intervals)
    }
}

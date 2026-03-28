import Testing
import Foundation
@testable import Peach

@Suite("AppUserSettings")
struct AppUserSettingsTests {

    private let settings = AppUserSettings()

    private func setAndCleanup(_ key: String, value: Any) -> () -> Void {
        let hadValue = UserDefaults.standard.object(forKey: key) != nil
        let oldValue = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(value, forKey: key)
        return {
            if hadValue {
                UserDefaults.standard.set(oldValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    private func removeAndCleanup(_ keys: [String]) -> () -> Void {
        let saved = keys.map { (key: $0, value: UserDefaults.standard.object(forKey: $0)) }
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return {
            for entry in saved {
                if let value = entry.value {
                    UserDefaults.standard.set(value, forKey: entry.key)
                } else {
                    UserDefaults.standard.removeObject(forKey: entry.key)
                }
            }
        }
    }

    // MARK: - Default Values (AC #3.2)

    @Test("noteRange returns default when no UserDefaults value set")
    func noteRangeDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.noteRangeMin, SettingsKeys.noteRangeMax])
        defer { cleanup() }

        #expect(settings.noteRange == SettingsKeys.defaultNoteRange)
    }

    @Test("noteDuration returns default when no UserDefaults value set")
    func noteDurationDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.noteDuration])
        defer { cleanup() }

        #expect(settings.noteDuration == SettingsKeys.defaultNoteDuration)
    }

    @Test("referencePitch returns default when no UserDefaults value set")
    func referencePitchDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.referencePitch])
        defer { cleanup() }

        #expect(settings.referencePitch == SettingsKeys.defaultReferencePitch)
    }

    @Test("soundSource returns default when no UserDefaults value set")
    func soundSourceDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.soundSource])
        defer { cleanup() }

        #expect(settings.soundSource.rawValue == SettingsKeys.defaultSoundSource)
    }

    @Test("varyLoudness returns default when no UserDefaults value set")
    func varyLoudnessDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.varyLoudness])
        defer { cleanup() }

        #expect(settings.varyLoudness == SettingsKeys.defaultVaryLoudness)
    }

    @Test("intervals returns default when no UserDefaults value set")
    func intervalsDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.intervals])
        defer { cleanup() }

        #expect(settings.intervals == IntervalSelection.default.intervals)
    }

    @Test("tuningSystem returns default when no UserDefaults value set")
    func tuningSystemDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.tuningSystem])
        defer { cleanup() }

        #expect(settings.tuningSystem == SettingsKeys.defaultTuningSystem)
    }

    @Test("noteGap returns default when no UserDefaults value set")
    func noteGapDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.noteGap])
        defer { cleanup() }

        #expect(settings.noteGap == SettingsKeys.defaultNoteGap)
    }

    @Test("tempoBPM returns default when no UserDefaults value set")
    func tempoBPMDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.tempoBPM])
        defer { cleanup() }

        #expect(settings.tempoBPM == SettingsKeys.defaultTempoBPM)
    }

    @Test("enabledGapPositions returns default when no UserDefaults value set")
    func enabledGapPositionsDefault() async {
        let cleanup = removeAndCleanup([SettingsKeys.enabledGapPositions])
        defer { cleanup() }

        #expect(settings.enabledGapPositions == SettingsKeys.defaultEnabledGapPositions)
    }

    // MARK: - Validation / Clamping (AC #3.3)

    @Test("noteRange returns default when span is less than minimum")
    func noteRangeTooSmall() async {
        let cleanup1 = setAndCleanup(SettingsKeys.noteRangeMin, value: 60)
        let cleanup2 = setAndCleanup(SettingsKeys.noteRangeMax, value: 65)
        defer { cleanup1(); cleanup2() }

        #expect(settings.noteRange == SettingsKeys.defaultNoteRange)
    }

    @Test("tempoBPM clamps above maximum to maximum")
    func tempoBPMClampedAboveMax() async {
        let cleanup = setAndCleanup(SettingsKeys.tempoBPM, value: 999)
        defer { cleanup() }

        #expect(settings.tempoBPM == SettingsKeys.maximumTempoBPM)
    }

    @Test("tempoBPM clamps below minimum to minimum")
    func tempoBPMClampedBelowMin() async {
        let cleanup = setAndCleanup(SettingsKeys.tempoBPM, value: 5)
        defer { cleanup() }

        #expect(settings.tempoBPM == SettingsKeys.minimumTempoBPM)
    }

    @Test("tempoBPM returns default for zero value")
    func tempoBPMZero() async {
        let cleanup = setAndCleanup(SettingsKeys.tempoBPM, value: 0)
        defer { cleanup() }

        #expect(settings.tempoBPM == SettingsKeys.defaultTempoBPM)
    }

    @Test("tuningSystem returns default for invalid identifier")
    func tuningSystemInvalid() async {
        let cleanup = setAndCleanup(SettingsKeys.tuningSystem, value: "nonexistentTuning")
        defer { cleanup() }

        #expect(settings.tuningSystem == SettingsKeys.defaultTuningSystem)
    }

    @Test("intervals returns default for invalid raw value")
    func intervalsInvalid() async {
        let cleanup = setAndCleanup(SettingsKeys.intervals, value: ";;;garbage;;;")
        defer { cleanup() }

        #expect(settings.intervals == IntervalSelection.default.intervals)
    }
}

import Testing
import Foundation
@testable import Peach

@Suite("AppTimingOffsetDetectionUserSettings Tests")
struct AppTimingOffsetDetectionUserSettingsTests {

    private static func makeSuite() -> UserDefaults {
        let suiteName = "AppTimingOffsetDetectionUserSettingsTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        return suite
    }

    // MARK: - maxRepetitions

    @Test("maxRepetitions returns the default when no value is stored")
    func missingKeyReturnsDefault() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()

        #expect(port.maxRepetitions == TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions)
    }

    @Test("maxRepetitions returns the default when the stored value is below 1")
    func belowOneReturnsDefault() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set(0, forKey: TimingOffsetDetectionSettingsKeys.maxRepetitions)

        #expect(port.maxRepetitions == TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions)

        port.defaults.set(-3, forKey: TimingOffsetDetectionSettingsKeys.maxRepetitions)

        #expect(port.maxRepetitions == TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions)
    }

    @Test("maxRepetitions returns the stored value when >= 1")
    func validValueIsReturned() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set(7, forKey: TimingOffsetDetectionSettingsKeys.maxRepetitions)

        #expect(port.maxRepetitions == 7)
    }

    // MARK: - selectedPattern

    @Test("selectedPattern returns the catalog default when no id is stored")
    func selectedPatternMissingKeyReturnsDefault() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()

        #expect(port.selectedPattern == TimingOffsetDetectionPatternCatalog.defaultPattern)
        #expect(port.selectedPattern.id == "pattern_01")
    }

    @Test("selectedPattern returns the registered pattern for a known stored id")
    func selectedPatternKnownIdReturnsPattern() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set("pattern_01", forKey: TimingOffsetDetectionSettingsKeys.selectedPatternId)

        #expect(port.selectedPattern == TimingOffsetDetectionPattern.pattern01)
    }

    @Test("selectedPattern falls back to the catalog default for an unknown stored id")
    func selectedPatternUnknownIdFallsBackToDefault() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set("pattern_xxxx", forKey: TimingOffsetDetectionSettingsKeys.selectedPatternId)

        #expect(port.selectedPattern == TimingOffsetDetectionPatternCatalog.defaultPattern)
    }

    /// Locks the Story 84.2 migration contract: a stored id from the retired
    /// `pattern_<bitmask>` convention (the only post-Epic-82 values Michael's
    /// dev device could carry into the swap) resolves to `pattern_01` via
    /// Epic 82.5's unknown-id fallback. No migration shim, no UserDefaults
    /// rewrite — just the fallback path doing its job.
    @Test(
        "selectedPattern falls back to pattern_01 for the five retired bitmask ids",
        arguments: ["pattern_1111", "pattern_1011", "pattern_1101", "pattern_1010", "pattern_1001"]
    )
    func selectedPatternRetiredBitmaskIdFallsBackToPattern01(retiredId: String) {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set(retiredId, forKey: TimingOffsetDetectionSettingsKeys.selectedPatternId)

        #expect(port.selectedPattern == TimingOffsetDetectionPattern.pattern01)
    }

    // MARK: - offsetNotePosition (pattern-aware)

    @Test("offsetNotePosition returns the active pattern's default when no value is stored")
    func offsetNotePositionMissingKeyReturnsPatternDefault() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()

        #expect(port.offsetNotePosition == TimingOffsetDetectionPattern.pattern01.defaultOffsetNotePosition)
    }

    @Test(
        "offsetNotePosition clamps stored values not in the active pattern's pickable set to the pattern default",
        arguments: [0, -1, 5, 99, 1]
    )
    func offsetNotePositionNonPickableClampedToPatternDefault(stored: Int) {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set(stored, forKey: TimingOffsetDetectionSettingsKeys.offsetNotePosition)

        #expect(port.offsetNotePosition == TimingOffsetDetectionPattern.pattern01.defaultOffsetNotePosition)
    }

    @Test(
        "offsetNotePosition returns the stored value when it is pickable for the active pattern",
        arguments: [2, 3, 4]
    )
    func offsetNotePositionPickableValueIsReturned(stored: Int) {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set(stored, forKey: TimingOffsetDetectionSettingsKeys.offsetNotePosition)

        #expect(port.offsetNotePosition == OffsetNotePosition(stored))
    }

    @Test("offsetNotePosition resolves the active pattern first — unknown id and corrupt position both fall back to the default pattern's default position")
    func offsetNotePositionUsesActivePatternForClamp() {
        let port = AppTimingOffsetDetectionUserSettings()
        port.defaults = Self.makeSuite()
        port.defaults.set("pattern_xxxx", forKey: TimingOffsetDetectionSettingsKeys.selectedPatternId)
        port.defaults.set(1, forKey: TimingOffsetDetectionSettingsKeys.offsetNotePosition)

        #expect(port.offsetNotePosition == TimingOffsetDetectionPattern.pattern01.defaultOffsetNotePosition)
    }
}

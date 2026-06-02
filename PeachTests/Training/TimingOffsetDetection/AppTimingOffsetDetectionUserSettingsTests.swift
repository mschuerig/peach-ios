import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
@Suite("AppTimingOffsetDetectionUserSettings Tests")
struct AppTimingOffsetDetectionUserSettingsTests {

    private static func makeSuite() -> UserDefaults {
        let suiteName = "AppTimingOffsetDetectionUserSettingsTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        return suite
    }

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
}
#endif

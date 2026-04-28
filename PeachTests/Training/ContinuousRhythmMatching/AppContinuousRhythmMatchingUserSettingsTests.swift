import Foundation
import Testing
@testable import Peach

@Suite("AppContinuousRhythmMatchingUserSettings", .serialized)
struct AppContinuousRhythmMatchingUserSettingsTests {

    private static let suiteName = "com.peach.tests.AppContinuousRhythmMatchingUserSettingsTests"

    private func makeSettings() -> AppContinuousRhythmMatchingUserSettings {
        let testDefaults = UserDefaults(suiteName: Self.suiteName)!
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        let settings = AppContinuousRhythmMatchingUserSettings()
        settings.defaults = testDefaults
        return settings
    }

    @Test("returns default when no UserDefaults value set")
    func defaultWhenAbsent() async {
        let settings = makeSettings()
        #expect(settings.enabledGapPositions == ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions)
    }

    @Test("reads legacy-format encoded string preserved from pre-77.6 builds")
    func roundTripsLegacyString() async {
        let settings = makeSettings()
        settings.defaults.set("0,2", forKey: ContinuousRhythmMatchingSettingsKeys.enabledGapPositions)

        #expect(settings.enabledGapPositions == [.first, .third])
    }

    @Test("returns default when stored string decodes to empty set")
    func defaultWhenStoredStringInvalid() async {
        let settings = makeSettings()
        settings.defaults.set("garbage", forKey: ContinuousRhythmMatchingSettingsKeys.enabledGapPositions)

        #expect(settings.enabledGapPositions == ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions)
    }
}

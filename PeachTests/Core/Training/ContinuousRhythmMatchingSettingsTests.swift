import Foundation
import Testing
@testable import Peach

@Suite("ContinuousRhythmMatchingSettings")
struct ContinuousRhythmMatchingSettingsTests {

    @Test("default values use tempo 80 and fourth position")
    func defaultValues() async {
        let settings = ContinuousRhythmMatchingSettings()
        #expect(settings.tempo == TempoBPM(80))
        #expect(settings.enabledGapPositions == [.fourth])
    }

    @Test("custom values are stored correctly")
    func customValues() async {
        let settings = ContinuousRhythmMatchingSettings(
            tempo: TempoBPM(120),
            enabledGapPositions: [.second, .third]
        )
        #expect(settings.tempo == TempoBPM(120))
        #expect(settings.enabledGapPositions == [.second, .third])
    }

    @Test("from user settings uses tempo from user settings")
    func fromUserSettings() async {
        let userSettings = MockUserSettings()
        let settings = ContinuousRhythmMatchingSettings.from(userSettings)
        #expect(settings.tempo == userSettings.tempoBPM)
    }

    @Test("conforms to Sendable")
    func conformsToSendable() async {
        let settings = ContinuousRhythmMatchingSettings()
        let sendable: any Sendable = settings
        #expect(sendable is ContinuousRhythmMatchingSettings)
    }
}

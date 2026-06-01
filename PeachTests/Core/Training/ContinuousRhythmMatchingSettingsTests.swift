import Foundation
import Testing
@testable import Peach

#if PEACH_RESEARCH
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

    @Test("from() reads tempo from shared settings and gap positions from feature port")
    func fromComposesSharedAndFeatureSettings() async {
        let userSettings = MockUserSettings()
        userSettings.tempoBPM = TempoBPM(100)
        let crmUserSettings = MockContinuousRhythmMatchingUserSettings()
        crmUserSettings.enabledGapPositions = [.first, .third]

        let settings = ContinuousRhythmMatchingSettings.from(userSettings, crmUserSettings: crmUserSettings)

        #expect(settings.tempo == TempoBPM(100))
        #expect(settings.enabledGapPositions == [.first, .third])
    }

    @Test("from() uses feature port's default gap positions when not customized")
    func fromUsesFeaturePortDefaultGapPositions() async {
        let userSettings = MockUserSettings()
        let crmUserSettings = MockContinuousRhythmMatchingUserSettings()
        let settings = ContinuousRhythmMatchingSettings.from(userSettings, crmUserSettings: crmUserSettings)
        #expect(settings.enabledGapPositions == Set(BeatPosition.allCases))
    }

    @Test("accepts any non-empty set of gap positions")
    func acceptsNonEmptySet() async {
        let settings = ContinuousRhythmMatchingSettings(enabledGapPositions: [.second])
        #expect(settings.enabledGapPositions.count == 1)
    }

    @Test("conforms to Sendable")
    func conformsToSendable() async {
        let settings = ContinuousRhythmMatchingSettings()
        let sendable: any Sendable = settings
        #expect(sendable is ContinuousRhythmMatchingSettings)
    }
}
#endif

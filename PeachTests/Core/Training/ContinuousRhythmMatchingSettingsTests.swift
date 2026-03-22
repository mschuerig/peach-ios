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

    @Test("from user settings reads tempo and gap positions")
    func fromUserSettingsReadsGapPositions() async {
        let userSettings = MockUserSettings()
        userSettings.tempoBPM = TempoBPM(100)
        userSettings.enabledGapPositions = [.first, .third]

        let settings = ContinuousRhythmMatchingSettings.from(userSettings)

        #expect(settings.tempo == TempoBPM(100))
        #expect(settings.enabledGapPositions == [.first, .third])
    }

    @Test("from user settings uses default gap positions when all enabled")
    func fromUserSettingsDefaultGapPositions() async {
        let userSettings = MockUserSettings()
        let settings = ContinuousRhythmMatchingSettings.from(userSettings)
        #expect(settings.enabledGapPositions == Set(StepPosition.allCases))
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

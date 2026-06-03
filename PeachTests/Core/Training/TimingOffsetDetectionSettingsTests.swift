import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionSettings Tests")
struct TimingOffsetDetectionSettingsTests {

    @Test("default values use 80 BPM, 400ms feedback, 20% max offset, 1% min offset, the feature-default maxRepetitions, and the feature-default offsetNotePosition")
    func defaultValues() {
        let settings = TimingOffsetDetectionSettings()
        #expect(settings.tempo == TempoBPM(80))
        #expect(settings.feedbackDuration == .milliseconds(400))
        #expect(settings.maxOffsetPercentage == 20.0)
        #expect(settings.minOffsetPercentage == 1.0)
        #expect(settings.maxRepetitions == TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions)
        #expect(settings.offsetNotePosition == TimingOffsetDetectionSettingsKeys.defaultOffsetNotePosition)
    }

    @Test("from(userSettings, todUserSettings:) maps tempoBPM correctly")
    func fromUserSettings() {
        let mockSettings = MockUserSettings()
        mockSettings.tempoBPM = TempoBPM(120)
        let todUserSettings = MockTimingOffsetDetectionUserSettings()

        let settings = TimingOffsetDetectionSettings.from(mockSettings, todUserSettings: todUserSettings)

        #expect(settings.tempo == TempoBPM(120))
    }

    @Test("from(userSettings, todUserSettings:) keeps other parameters at defaults")
    func fromUserSettingsKeepsDefaults() {
        let mockSettings = MockUserSettings()
        mockSettings.tempoBPM = TempoBPM(100)
        let todUserSettings = MockTimingOffsetDetectionUserSettings()

        let settings = TimingOffsetDetectionSettings.from(mockSettings, todUserSettings: todUserSettings)

        #expect(settings.feedbackDuration == .milliseconds(400))
        #expect(settings.maxOffsetPercentage == 20.0)
        #expect(settings.minOffsetPercentage == 1.0)
    }

    @Test("from(userSettings, todUserSettings:) reads maxRepetitions from the feature-local port")
    func fromUserSettingsReadsMaxRepetitions() {
        let mockSettings = MockUserSettings()
        let todUserSettings = MockTimingOffsetDetectionUserSettings()
        todUserSettings.maxRepetitions = 5

        let settings = TimingOffsetDetectionSettings.from(mockSettings, todUserSettings: todUserSettings)

        #expect(settings.maxRepetitions == 5)
    }

    @Test(
        "from(userSettings, todUserSettings:) reads offsetNotePosition from the feature-local port",
        arguments: [1, 2, 3, 4]
    )
    func fromUserSettingsReadsOffsetNotePosition(position: Int) {
        let mockSettings = MockUserSettings()
        let todUserSettings = MockTimingOffsetDetectionUserSettings()
        todUserSettings.offsetNotePosition = position

        let settings = TimingOffsetDetectionSettings.from(mockSettings, todUserSettings: todUserSettings)

        #expect(settings.offsetNotePosition == position)
    }
}
#endif

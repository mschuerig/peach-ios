import Testing
import Foundation
@testable import Peach

@Suite("RhythmOffsetDetectionSettings Tests")
struct RhythmOffsetDetectionSettingsTests {

    @Test("default values use 80 BPM, 400ms feedback, 20% max offset, 1% min offset")
    func defaultValues() {
        let settings = RhythmOffsetDetectionSettings()
        #expect(settings.tempo == TempoBPM(80))
        #expect(settings.feedbackDuration == .milliseconds(400))
        #expect(settings.maxOffsetPercentage == 20.0)
        #expect(settings.minOffsetPercentage == 1.0)
    }

    @Test("from(userSettings) maps tempoBPM correctly")
    func fromUserSettings() {
        let mockSettings = MockUserSettings()
        mockSettings.tempoBPM = TempoBPM(120)

        let settings = RhythmOffsetDetectionSettings.from(mockSettings)

        #expect(settings.tempo == TempoBPM(120))
    }

    @Test("from(userSettings) keeps other parameters at defaults")
    func fromUserSettingsKeepsDefaults() {
        let mockSettings = MockUserSettings()
        mockSettings.tempoBPM = TempoBPM(100)

        let settings = RhythmOffsetDetectionSettings.from(mockSettings)

        #expect(settings.feedbackDuration == .milliseconds(400))
        #expect(settings.maxOffsetPercentage == 20.0)
        #expect(settings.minOffsetPercentage == 1.0)
    }
}

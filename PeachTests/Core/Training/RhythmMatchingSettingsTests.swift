import Testing
import Foundation
@testable import Peach

@Suite("RhythmMatchingSettings Tests")
struct RhythmMatchingSettingsTests {

    @Test("default values use 80 BPM and 400ms feedback")
    func defaultValues() {
        let settings = RhythmMatchingSettings()
        #expect(settings.tempo == TempoBPM(80))
        #expect(settings.feedbackDuration == .milliseconds(400))
    }

    @Test("custom values are stored correctly")
    func customValues() {
        let settings = RhythmMatchingSettings(
            tempo: TempoBPM(120),
            feedbackDuration: .milliseconds(300)
        )
        #expect(settings.tempo == TempoBPM(120))
        #expect(settings.feedbackDuration == .milliseconds(300))
    }

    @Test("conforms to Sendable")
    func isSendable() {
        let settings = RhythmMatchingSettings()
        let _: any Sendable = settings
    }
}

import Testing
@testable import Peach

@Suite("TimingOffsetDetectionFeedbackView Tests")
struct TimingOffsetDetectionFeedbackViewTests {

    @Test("accessibility label for correct answer speaks milliseconds")
    func accessibilityLabelCorrect() async {
        let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: true, offsetMs: 12.0)
        #expect(label.contains(TimingOffsetFormatter.spoken(12.0)))
        #expect(label.contains(String(localized: "Correct")))
    }

    @Test("accessibility label for incorrect answer speaks milliseconds")
    func accessibilityLabelIncorrect() async {
        let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: false, offsetMs: 38.0)
        #expect(label.contains(TimingOffsetFormatter.spoken(38.0)))
        #expect(label.contains(String(localized: "Incorrect")))
    }

    // Story 83.6: this label announced "Incorrect, 20 percent" before the fix —
    // the only surface in the app that reported timing in a unit story 83.2
    // rejected, and the one a VoiceOver user heard after every single trial.
    @Test("accessibility label never announces percent")
    func accessibilityLabelNeverAnnouncesPercent() async {
        for correct in [true, false] {
            let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: correct, offsetMs: 20.0)
            #expect(label.contains("%") == false)
            #expect(label.localizedCaseInsensitiveContains(String(localized: "percent")) == false)
        }
    }

    @Test("correct and incorrect labels are distinct")
    func accessibilityLabelsDistinct() async {
        let correct = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: true, offsetMs: 4.0)
        let incorrect = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: false, offsetMs: 4.0)
        #expect(correct != incorrect, "Correct and incorrect labels must be distinct for VoiceOver")
    }
}

import Testing
@testable import Peach

@Suite("TimingOffsetDetectionFeedbackView Tests")
struct TimingOffsetDetectionFeedbackViewTests {

    @Test("percentageText formats with no decimal places")
    func percentageTextFormatting() async {
        #expect(TimingOffsetDetectionFeedbackView.percentageText(4.0) == "4%")
        #expect(TimingOffsetDetectionFeedbackView.percentageText(12.6) == "13%")
        #expect(TimingOffsetDetectionFeedbackView.percentageText(0.7) == "1%")
    }

    @Test("accessibility label for correct answer is non-empty and contains percentage")
    func accessibilityLabelCorrect() async {
        let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: true, offsetPercentage: 4)
        #expect(!label.isEmpty)
        #expect(label.contains("4"))
    }

    @Test("accessibility label for incorrect answer is non-empty and contains percentage")
    func accessibilityLabelIncorrect() async {
        let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: false, offsetPercentage: 12)
        #expect(!label.isEmpty)
        #expect(label.contains("12"))
    }

    @Test("correct and incorrect labels are distinct")
    func accessibilityLabelsDistinct() async {
        let correct = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: true, offsetPercentage: 4)
        let incorrect = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: false, offsetPercentage: 4)
        #expect(correct != incorrect, "Correct and incorrect labels must be distinct for VoiceOver")
    }
}

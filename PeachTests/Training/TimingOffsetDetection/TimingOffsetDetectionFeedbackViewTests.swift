import Testing
@testable import Peach

@Suite("TimingOffsetDetectionFeedbackView Tests")
struct TimingOffsetDetectionFeedbackViewTests {

    @Test("accessibility label for correct answer speaks the spelled-out unit")
    func accessibilityLabelCorrect() async {
        let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: true, offsetMs: 12.0, unitLabel: "SPELLED")
        #expect(label.contains(MetricValueFormatter.format(12.0)))
        #expect(label.hasSuffix(" SPELLED"))
        #expect(label.contains(String(localized: "Correct")))
    }

    @Test("accessibility label for incorrect answer speaks the spelled-out unit")
    func accessibilityLabelIncorrect() async {
        let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: false, offsetMs: 38.0, unitLabel: "SPELLED")
        #expect(label.contains(MetricValueFormatter.format(38.0)))
        #expect(label.hasSuffix(" SPELLED"))
        #expect(label.contains(String(localized: "Incorrect")))
    }

    // Story 83.6: this label announced "Incorrect, 20 percent" before the fix --
    // the only surface in the app reporting timing in a unit story 83.2
    // rejected, and the one a VoiceOver user heard after every single trial.
    // The catalog entries for "percent" / "Prozent" were deleted with this fix,
    // so the guard names both languages literally rather than resolving a key
    // that no longer exists.
    @Test("accessibility label never announces percent")
    func accessibilityLabelNeverAnnouncesPercent() async {
        for correct in [true, false] {
            let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: correct, offsetMs: 20.0, unitLabel: "SPELLED")
            #expect(label.contains("%") == false)
            #expect(label.localizedCaseInsensitiveContains("percent") == false)
            #expect(label.localizedCaseInsensitiveContains("prozent") == false)
        }
    }

    @Test("correct and incorrect labels are distinct")
    func accessibilityLabelsDistinct() async {
        let correct = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: true, offsetMs: 4.0, unitLabel: "SPELLED")
        let incorrect = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: false, offsetMs: 4.0, unitLabel: "SPELLED")
        #expect(correct != incorrect, "Correct and incorrect labels must be distinct for VoiceOver")
    }

    // The pill renders the compact symbol while VoiceOver hears the spelled-out
    // label; wiring both to the same config field would regress story 83.5.
    @Test("the spoken label uses the discipline's spelled-out unit, not its symbol")
    func spokenLabelUsesSpelledOutUnit() async {
        let config = TrainingDisciplineID.timingOffsetDetection.config
        let label = TimingOffsetDetectionFeedbackView.accessibilityLabel(isCorrect: true, offsetMs: 12.0, unitLabel: config.unitLabel)
        #expect(label.hasSuffix(config.unitLabel))
        #expect(label.hasSuffix(config.unitSymbol) == false)
    }
}

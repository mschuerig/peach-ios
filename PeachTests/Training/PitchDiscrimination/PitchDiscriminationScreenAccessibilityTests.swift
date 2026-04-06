import Testing
import SwiftUI
@testable import Peach

/// Tests for PitchDiscriminationScreen accessibility features (Story 7.2)
@Suite("PitchDiscriminationScreen Accessibility Tests")
struct PitchDiscriminationScreenAccessibilityTests {

    // MARK: - Reduce Motion (AC: #6)

    @Test("Feedback animation returns nil when reduce motion is enabled")
    func feedbackAnimationNilWhenReduceMotion() async throws {
        let animation = PitchDiscriminationScreen.feedbackAnimation(reduceMotion: true)
        #expect(animation == nil)
    }

    @Test("Feedback animation returns easeInOut when reduce motion is disabled")
    func feedbackAnimationPresentWhenNoReduceMotion() async throws {
        let animation = PitchDiscriminationScreen.feedbackAnimation(reduceMotion: false)
        #expect(animation == .easeInOut(duration: 0.2))
    }

    // MARK: - PitchDiscriminationFeedbackIndicator Accessibility Labels (AC: #2)

    @Test("PitchDiscriminationFeedbackIndicator correct state returns non-empty label")
    func feedbackIndicatorCorrectLabel() async throws {
        let label = PitchDiscriminationFeedbackIndicator.accessibilityLabel(isCorrect: true)
        #expect(!label.isEmpty)
    }

    @Test("PitchDiscriminationFeedbackIndicator incorrect state returns non-empty label")
    func feedbackIndicatorIncorrectLabel() async throws {
        let label = PitchDiscriminationFeedbackIndicator.accessibilityLabel(isCorrect: false)
        #expect(!label.isEmpty)
    }

    @Test("PitchDiscriminationFeedbackIndicator correct and incorrect labels are distinct")
    func feedbackIndicatorLabelsDistinct() async throws {
        let correctLabel = PitchDiscriminationFeedbackIndicator.accessibilityLabel(isCorrect: true)
        let incorrectLabel = PitchDiscriminationFeedbackIndicator.accessibilityLabel(isCorrect: false)
        #expect(correctLabel != incorrectLabel,
                "Correct and incorrect labels must be distinct for VoiceOver clarity")
    }

    // MARK: - Training Screen Button Accessibility Labels (AC: #1)

    @Test("Higher and Lower localization keys produce non-empty distinct strings")
    func higherLowerLocalizationKeysDistinct() async throws {
        // Note: PitchDiscriminationScreen applies these as .accessibilityLabel("Higher") / .accessibilityLabel("Lower")
        // which use LocalizedStringKey — not directly testable in unit tests.
        // This verifies the underlying localization keys are valid and distinct.
        let higher = String(localized: "Higher")
        let lower = String(localized: "Lower")
        #expect(!higher.isEmpty)
        #expect(!lower.isEmpty)
        #expect(higher != lower,
                "Higher and Lower labels must be distinct for VoiceOver navigation")
    }
}

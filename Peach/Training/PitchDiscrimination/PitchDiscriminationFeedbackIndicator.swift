import SwiftUI

/// Visual feedback indicator showing correct/incorrect answer result
///
/// Displays a checkmark (green) for correct answers or X (red) for incorrect answers.
/// Positioned in the top-right corner of the training screen.
///
/// # Accessibility
/// - Provides VoiceOver labels ("Correct" or "Incorrect")
/// - Reduce Motion: The parent view (PitchDiscriminationScreen) conditionally applies animation — when Reduce Motion is enabled, the opacity transition is instant (no animation)
struct PitchDiscriminationFeedbackIndicator: View {
    /// Whether the answer was correct (nil = no feedback to show)
    let isCorrect: Bool?

    var body: some View {
        if let isCorrect {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isCorrect ? .green : .red)
                .accessibilityLabel(Self.accessibilityLabel(isCorrect: isCorrect))
                .accessibilityRemoveTraits(.isImage)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .hidden()
        }
    }

    /// Returns the VoiceOver accessibility label for the feedback state
    static func accessibilityLabel(isCorrect: Bool) -> String {
        isCorrect ? String(localized: "Correct") : String(localized: "Incorrect")
    }
}

// MARK: - Previews

#Preview("Correct") {
    PitchDiscriminationFeedbackIndicator(isCorrect: true)
        .padding()
}

#Preview("Incorrect") {
    PitchDiscriminationFeedbackIndicator(isCorrect: false)
        .padding()
}

#Preview("No Feedback") {
    PitchDiscriminationFeedbackIndicator(isCorrect: nil)
        .padding()
}

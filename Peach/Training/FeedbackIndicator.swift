import SwiftUI

/// Visual feedback indicator showing correct/incorrect answer result
///
/// Displays a thumbs up (green) for correct answers or thumbs down (red) for incorrect answers.
/// Designed to be visible in peripheral vision without obstructing the training buttons.
///
/// # Accessibility
/// - Provides VoiceOver labels ("Correct" or "Incorrect")
/// - Reduce Motion: The parent view (TrainingScreen) conditionally applies animation — when Reduce Motion is enabled, the opacity transition is instant (no animation)
/// - Large icon size (100pt) for visibility
///
/// # Usage
/// ```swift
/// .overlay {
///     if trainingSession.showFeedback {
///         FeedbackIndicator(isCorrect: trainingSession.isLastAnswerCorrect)
///             .transition(.opacity)
///     }
/// }
/// ```
struct FeedbackIndicator: View {
    /// Whether the answer was correct (nil = no feedback to show)
    let isCorrect: Bool?

    /// Default icon size for regular (non-compact) layouts
    static let defaultIconSize: CGFloat = 100

    /// Icon size — defaults to 100pt, reduced in compact layouts
    var iconSize: CGFloat = defaultIconSize

    var body: some View {
        if let isCorrect {
            Image(systemName: isCorrect ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(isCorrect ? .green : .red)
                .accessibilityLabel(Self.accessibilityLabel(isCorrect: isCorrect))
                .accessibilityRemoveTraits(.isImage)
        }
    }

    /// Returns the VoiceOver accessibility label for the feedback state
    static func accessibilityLabel(isCorrect: Bool) -> String {
        isCorrect ? String(localized: "Correct") : String(localized: "Incorrect")
    }
}

// MARK: - Previews

#Preview("Correct") {
    FeedbackIndicator(isCorrect: true)
        .padding()
}

#Preview("Incorrect") {
    FeedbackIndicator(isCorrect: false)
        .padding()
}

#Preview("No Feedback") {
    FeedbackIndicator(isCorrect: nil)
        .padding()
}

#if os(iOS)
import UIKit

/// Manages haptic feedback for training interactions
///
/// Provides tactile feedback for incorrect answers, enabling eyes-closed training.
/// Follows the sensory hierarchy principle: ears > fingers > eyes.
///
/// # Haptic Pattern
/// - **Incorrect answer**: Single medium-intensity haptic tick
/// - **Correct answer**: NO haptic (silence = confirmation)
///
/// # Testing Note
/// Haptics don't work in iOS Simulator - must test on real device.
final class HapticFeedbackManager: HapticFeedback, PitchDiscriminationObserver {
    /// UIKit haptic generator
    private let generator: UIImpactFeedbackGenerator

    /// Creates a haptic feedback manager
    ///
    /// Prepares the generator during initialization to minimize latency when feedback is triggered.
    init() {
        self.generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
    }

    /// Plays haptic feedback for incorrect answer
    ///
    /// Triggers a noticeable haptic pattern for eyes-closed training.
    /// Uses heavy-intensity impact for better tactile feedback.
    func playIncorrectFeedback() {
        generator.impactOccurred()
        // Brief second impact for more noticeable feedback
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            generator.impactOccurred()
        }
        // Prepare for next potential haptic to reduce latency
        generator.prepare()
    }

    // MARK: - PitchDiscriminationObserver

    /// Called when a comparison is completed - triggers haptic feedback if incorrect
    ///
    /// - Parameter completed: The completed comparison with result
    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
        if !completed.isCorrect {
            playIncorrectFeedback()
        }
    }
}

// MARK: - RhythmOffsetDetectionObserver

extension HapticFeedbackManager: RhythmOffsetDetectionObserver {
    func rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial) {
        if !result.isCorrect {
            playIncorrectFeedback()
        }
    }
}
#endif

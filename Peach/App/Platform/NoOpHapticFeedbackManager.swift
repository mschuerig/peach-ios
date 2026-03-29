/// No-op haptic feedback for macOS where taptic engine feedback is not appropriate
///
/// Mac hardware lacks the training-style haptic feedback that iOS provides.
/// All methods silently no-op. See story 66.4 Dev Notes for rationale.
final class NoOpHapticFeedbackManager: HapticFeedback, PitchDiscriminationObserver, RhythmOffsetDetectionObserver {
    func playIncorrectFeedback() {}
    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {}
    func rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial) {}
}

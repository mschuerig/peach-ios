/// Protocol for haptic feedback service (enables testing with mocks)
protocol HapticFeedback {
    /// Plays haptic feedback for incorrect answer
    func playIncorrectFeedback()
}

protocol TrainingSession: AnyObject {
    var isIdle: Bool { get }
    func stop()
    /// Suspends the session while preserving in-trial state so a subsequent
    /// `resume()` can pick up where the user left off. Cancels in-flight Tasks
    /// and stops audio. **Does not** clear `currentTrial` / `lastResult` /
    /// session-best accumulators / settings. No-op from `.idle` or when
    /// already paused. After `pause()`, `isIdle` stays `false`.
    func pause()
    /// Re-engages a paused session. Re-plays the trial setup (reference for
    /// pitch sessions; sequencer for tempo-driven sessions) using the
    /// preserved `currentTrial`. No-op when not paused. Implementations
    /// must serialize the resume work behind any in-flight stop spawned by
    /// the preceding `pause()` to avoid start-before-stop audio races.
    func resume()
}

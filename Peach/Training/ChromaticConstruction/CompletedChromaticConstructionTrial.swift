import Foundation

/// Snapshot of a chromatic-construction trial after every interior position
/// has been placed. Provides the error metrics the discipline scores on.
///
/// Mirrors `CompletedPitchDiscriminationTrial`: the trial value type is
/// captured immutably; `timestamp` records when the trial completed; error
/// computations are deterministic functions of the wrapped trial.
struct CompletedChromaticConstructionTrial: Hashable, Sendable {
    let trial: ChromaticConstructionTrial
    let timestamp: Date

    init(trial: ChromaticConstructionTrial, timestamp: Date) {
        self.trial = trial
        self.timestamp = timestamp
    }

    /// Absolute cent error at 1-based position `k`: distance between the
    /// user-placed offset and the path's target offset.
    func absoluteErrorCents(at k: Int) -> Cents {
        let target = trial.path.targetOffsetCents(at: k)
        let placed = trial.placed[k - 1].offset
        return Cents((placed - target).magnitude)
    }

    /// Error of step `k` relative to its predecessor: distance between the
    /// realized step (placed[k] − placed[k-1], or placed[1] − 0 for k = 1)
    /// and the expected one-semitone step (signed by `path.steps[k - 1]`).
    func relativeErrorCents(at k: Int) -> Cents {
        let prior: Cents = k == 1 ? Cents(0) : trial.placed[k - 2].offset
        let curr: Cents = trial.placed[k - 1].offset
        let realizedStep = curr - prior
        let expectedStep: Cents = trial.path.steps[k - 1] == .up ? Cents.perSemitone : -Cents.perSemitone
        return Cents((realizedStep - expectedStep).magnitude)
    }
}

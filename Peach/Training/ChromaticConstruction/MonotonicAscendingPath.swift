import Foundation

/// Produces a uniformly ascending path of `outerCents / targetStep` `.up`
/// steps. Caller is responsible for selecting this strategy when the walk
/// direction is ascending (positive `outerCents`).
struct MonotonicAscendingPath: NextPathStrategy {
    func path(forOuterCents outerCents: Cents, targetStep: Cents, rng: inout some RandomNumberGenerator) -> ChromaticPath {
        precondition(outerCents > Cents(0.0), "MonotonicAscendingPath requires positive outerCents, got \(outerCents.rawValue)")
        precondition(targetStep > Cents(0.0), "targetStep must be positive, got \(targetStep.rawValue)")
        let quotient = outerCents / targetStep
        let stepCount = Int(quotient.rounded())
        precondition(
            abs(quotient - Double(stepCount)) < 1e-9,
            "outerCents (\(outerCents.rawValue)) must be an integer multiple of targetStep (\(targetStep.rawValue))"
        )
        return Array(repeating: Direction.up, count: stepCount)
    }
}

import Foundation

/// Produces a uniformly descending path of `|outerCents| / targetStep`
/// `.down` steps. Caller is responsible for selecting this strategy when the
/// walk direction is descending (negative `outerCents`).
struct MonotonicDescendingPath: NextPathStrategy {
    func path(forOuterCents outerCents: Cents, targetStep: Cents, rng: inout some RandomNumberGenerator) -> ChromaticPath {
        precondition(outerCents < Cents(0.0), "MonotonicDescendingPath requires negative outerCents, got \(outerCents.rawValue)")
        precondition(targetStep > Cents(0.0), "targetStep must be positive, got \(targetStep.rawValue)")
        let quotient = outerCents.magnitude / targetStep.magnitude
        let stepCount = Int(quotient.rounded())
        precondition(
            abs(quotient - Double(stepCount)) < 1e-9,
            "|outerCents| (\(outerCents.magnitude)) must be an integer multiple of targetStep (\(targetStep.rawValue))"
        )
        return Array(repeating: Direction.down, count: stepCount)
    }
}

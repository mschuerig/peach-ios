import Foundation

/// Generates a `Path` for a chromatic-construction trial given the outer span
/// and target cent step. The `rng` parameter is consumed by future meandering
/// strategies; monotonic conformances ignore it. Per Adam's consultation
/// (2026-06-12), RNG-injection symmetry with `ChromaticConstructionSettings.from(...)`
/// avoids signature churn when meandering ships.
///
/// Conformances must produce a `Path` satisfying the invariant documented at
/// `Path`'s typealias site:
/// `path.reduce(0) { $0 + ($1 == .up ? +1 : -1) } * targetStepCents == outerCents`.
protocol NextPathStrategy: Sendable {
    func path(forOuterCents outerCents: Cents, targetStep: Cents, rng: inout some RandomNumberGenerator) -> ChromaticPath
}

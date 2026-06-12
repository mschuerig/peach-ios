import Foundation

/// A sequence of directed steps defining a chromatic-construction ladder's
/// shape. Each element is one `targetStepCents` step in the indicated
/// `Direction`.
///
/// **Invariant** every `NextPathStrategy` conformance must honor:
/// `path.reduce(0) { $0 + ($1 == .up ? +1 : -1) } * targetStepCents == outerCents`
///
/// i.e., the path's net signed step count, multiplied by `targetStepCents`,
/// equals the outer span between anchors. Monotonic paths satisfy this
/// trivially; future meandering strategies must construct paths that close
/// back to the declared net span.
///
/// Named `ChromaticPath` (not `Path`) to avoid colliding with `SwiftUI.Path`,
/// which is the shape-rendering type. See Spec Change Log entry for 2026-06-12.
typealias ChromaticPath = [Direction]

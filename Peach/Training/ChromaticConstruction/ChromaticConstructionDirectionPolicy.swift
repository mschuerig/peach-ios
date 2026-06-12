import Foundation

/// Walk-direction policy for a chromatic-construction trial. `.mix` selects
/// `.ascending` or `.descending` per-trial via the session's injected RNG.
enum ChromaticConstructionDirectionPolicy: Hashable, Sendable, CaseIterable {
    case ascending
    case descending
    case mix
}

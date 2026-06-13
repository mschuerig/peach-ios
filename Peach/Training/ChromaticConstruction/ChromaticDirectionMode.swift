import Foundation

/// View-local control over which walk directions a Chromatic Construction
/// trial may draw from. Resolves to a `Set<DirectedInterval>` consumed by
/// ``ChromaticConstructionSettings.outerIntervals``; the session picks one
/// element per trial via `randomElement()`.
enum ChromaticDirectionMode: CaseIterable, Hashable, Sendable {
    case ascending
    case descending
    case mix

    func outerIntervals(for interval: Interval) -> Set<DirectedInterval> {
        switch self {
        case .ascending: [.up(interval)]
        case .descending: [.down(interval)]
        case .mix: [.up(interval), .down(interval)]
        }
    }
}

import Foundation

/// The direction of a rhythm offset relative to the beat.
///
/// Derived from the sign of a `TimingOffset`'s duration — negative is early,
/// positive or zero is late (on-the-beat).
enum TimingDirection: Hashable, Sendable, Codable, CaseIterable {
    case early
    case late
}

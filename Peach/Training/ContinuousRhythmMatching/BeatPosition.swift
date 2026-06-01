import Foundation

/// Position within a 4-subdivision beat. Discipline-local to
/// ContinuousRhythmMatching — the sequencer port speaks in terms of
/// `Beat`/`Subdivision` and never references this enum.
enum BeatPosition: Int, CaseIterable, Hashable, Sendable {
    case first = 0
    case second = 1
    case third = 2
    case fourth = 3
}

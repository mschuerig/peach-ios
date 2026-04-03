import Foundation

// WALKTHROUGH: Naming inconsistency — UI says "Compare Timing" but types use "Rhythm*".
// Consider renaming to TimingOffset/TimingDirection for consistency with user-facing language.
/// A signed duration representing the timing offset from the beat.
///
/// Negative values mean the hit was early; positive or zero means late
/// (zero is treated as on-the-beat). Direction is derived from sign (FR99).
struct RhythmOffset: Hashable, Sendable, Codable {
    /// Signed duration — negative means early, positive means late.
    let duration: Duration

    nonisolated init(_ duration: Duration) {
        self.duration = duration
    }

    /// The direction of this offset relative to the beat.
    var direction: RhythmDirection {
        duration < .zero ? .early : .late
    }

    /// Absolute offset in milliseconds, ignoring direction.
    var absoluteMilliseconds: Double {
        let absDuration = duration < .zero ? .zero - duration : duration
        return absDuration.timeInterval * 1000.0
    }

    /// Offset as percentage of one sixteenth note at the given tempo (FR87).
    func percentageOfSixteenthNote(at tempo: TempoBPM) -> Double {
        let absDuration = duration < .zero ? .zero - duration : duration
        return (absDuration / tempo.sixteenthNoteDuration) * 100.0
    }
}

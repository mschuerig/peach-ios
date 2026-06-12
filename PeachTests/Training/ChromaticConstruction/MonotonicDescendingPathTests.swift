import Testing
import Foundation
@testable import Peach

@Suite("MonotonicDescendingPath Tests")
struct MonotonicDescendingPathTests {

    // MARK: - Representative outer intervals (100-cent target step)

    @Test("-200 cents → 2 down steps")
    func twoSemitones() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicDescendingPath().path(
            forOuterCents: Cents(-200.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(path == [.down, .down])
    }

    @Test("-700 cents (P5) → 7 down steps")
    func perfectFifth() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicDescendingPath().path(
            forOuterCents: Cents(-700.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(path == Array(repeating: Direction.down, count: 7))
    }

    @Test("-1200 cents (octave) → 12 down steps")
    func octave() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicDescendingPath().path(
            forOuterCents: Cents(-1200.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(path == Array(repeating: Direction.down, count: 12))
    }

    // MARK: - Q3 consultation (b): non-100 target step (mirror of ascending)

    @Test("-900 cents / 300 cents target (minor third × 3 descending) → 3 down steps")
    func threeMinorThirds() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicDescendingPath().path(
            forOuterCents: Cents(-900.0),
            targetStep: Cents(300.0),
            rng: &rng
        )
        #expect(path == [.down, .down, .down])
    }

    // MARK: - RNG ignored

    @Test("RNG state is unchanged after a monotonic call")
    func rngIgnored() async {
        var rng = SeededRNG(seed: 42)
        let snapshotBefore = rng.state
        _ = MonotonicDescendingPath().path(
            forOuterCents: Cents(-700.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(rng.state == snapshotBefore)
    }
}

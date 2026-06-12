import Testing
import Foundation
@testable import Peach

@Suite("MonotonicAscendingPath Tests")
struct MonotonicAscendingPathTests {

    // MARK: - Representative outer intervals (100-cent target step)

    @Test("200 cents → 2 up steps")
    func twoSemitones() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicAscendingPath().path(
            forOuterCents: Cents(200.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(path == [.up, .up])
    }

    @Test("700 cents (P5) → 7 up steps")
    func perfectFifth() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicAscendingPath().path(
            forOuterCents: Cents(700.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(path == Array(repeating: Direction.up, count: 7))
    }

    @Test("1200 cents (octave) → 12 up steps")
    func octave() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicAscendingPath().path(
            forOuterCents: Cents(1200.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(path == Array(repeating: Direction.up, count: 12))
    }

    // MARK: - Q3 consultation (b): non-100 target step

    @Test("900 cents / 300 cents target (minor third × 3) → 3 up steps")
    func threeMinorThirds() async {
        var rng = SystemRandomNumberGenerator()
        let path = MonotonicAscendingPath().path(
            forOuterCents: Cents(900.0),
            targetStep: Cents(300.0),
            rng: &rng
        )
        #expect(path == [.up, .up, .up])
    }

    // MARK: - RNG ignored (monotonic conformance is deterministic)

    @Test("RNG state is unchanged after a monotonic call")
    func rngIgnored() async {
        var rng = SeededRNG(seed: 42)
        let snapshotBefore = rng.state
        _ = MonotonicAscendingPath().path(
            forOuterCents: Cents(700.0),
            targetStep: Cents(100.0),
            rng: &rng
        )
        #expect(rng.state == snapshotBefore)
    }
}

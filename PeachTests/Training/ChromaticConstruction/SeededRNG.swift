import Foundation

/// Deterministic RNG for test seeding. Linear congruential generator using the
/// glibc parameters — produces reproducible sequences and exposes `state` so
/// tests can assert whether a callee consumed any random bits.
struct SeededRNG: RandomNumberGenerator {
    private(set) var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 1 // ensure non-zero so the multiplicative recurrence advances
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

import Testing
import Foundation
@testable import Peach

@Suite("DetunedDirectedInterval Tests")
struct DetunedDirectedIntervalTests {

    // MARK: - Construction

    @Test("stores interval and offset")
    func storesIntervalAndOffset() async {
        let detuned = DetunedDirectedInterval(interval: .up(.majorThird), offset: Cents(25))
        #expect(detuned.interval == .up(.majorThird))
        #expect(detuned.offset == Cents(25))
    }

    @Test("stores negative cent offset")
    func storesNegativeOffset() async {
        let detuned = DetunedDirectedInterval(interval: .down(.perfectFifth), offset: Cents(-30.5))
        #expect(detuned.interval == .down(.perfectFifth))
        #expect(detuned.offset == Cents(-30.5))
    }

    // MARK: - Convenience Init

    @Test("convenience init sets offset to zero")
    func convenienceInitZeroOffset() async {
        let detuned = DetunedDirectedInterval(.up(.perfectFifth))
        #expect(detuned.interval == .up(.perfectFifth))
        #expect(detuned.offset == Cents(0))
    }

    // MARK: - Hashable

    @Test("can be used as Set element")
    func hashableSetElement() async {
        let a = DetunedDirectedInterval(interval: .up(.majorThird), offset: Cents(0))
        let b = DetunedDirectedInterval(interval: .up(.majorThird), offset: Cents(0))
        let c = DetunedDirectedInterval(interval: .up(.majorThird), offset: Cents(25))
        let set: Set<DetunedDirectedInterval> = [a, b, c]
        #expect(set.count == 2)
    }

    @Test("different intervals are distinct")
    func differentIntervalsAreDistinct() async {
        let up = DetunedDirectedInterval(interval: .up(.perfectFifth), offset: Cents(0))
        let down = DetunedDirectedInterval(interval: .down(.perfectFifth), offset: Cents(0))
        #expect(up != down)
    }

    // MARK: - Sendable

    @Test("can be sent across concurrency boundaries")
    func sendableAcrossBoundary() async {
        let detuned = DetunedDirectedInterval(interval: .up(.minorSecond), offset: Cents(50))
        let result = await Task.detached { detuned }.value
        #expect(result == detuned)
    }
}

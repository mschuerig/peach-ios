import Testing
@testable import Peach

@Suite("MIDIVelocity Tests")
struct MIDIVelocityTests {

    // MARK: - Valid Construction

    @Test("Creates valid velocity at boundaries")
    func validBoundaries() {
        let low = MIDIVelocity(1)
        let high = MIDIVelocity(127)
        let mid = MIDIVelocity(63)

        #expect(low.rawValue == 1)
        #expect(high.rawValue == 127)
        #expect(mid.rawValue == 63)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates MIDIVelocity")
    func integerLiteral() {
        let velocity: MIDIVelocity = 63
        #expect(velocity.rawValue == 63)
    }

    // MARK: - Hashable

    @Test("Equal velocities have same hash")
    func hashable() {
        let set: Set<MIDIVelocity> = [MIDIVelocity(63), MIDIVelocity(63), MIDIVelocity(100)]
        #expect(set.count == 2)
    }
}

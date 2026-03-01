import Testing
import Foundation
@testable import Peach

@Suite("DirectedInterval Tests")
struct DirectedIntervalTests {

    // MARK: - Construction

    @Test("stores interval and direction")
    func construction() async {
        let di = DirectedInterval(interval: .perfectFifth, direction: .up)
        #expect(di.interval == .perfectFifth)
        #expect(di.direction == .up)
    }

    // MARK: - Static Factories

    @Test("prime factory creates prime with up direction")
    func primeFactory() async {
        #expect(DirectedInterval.prime.interval == .prime)
        #expect(DirectedInterval.prime.direction == .up)
    }

    @Test("up factory creates interval with up direction")
    func upFactory() async {
        let di = DirectedInterval.up(.perfectFifth)
        #expect(di.interval == .perfectFifth)
        #expect(di.direction == .up)
    }

    @Test("down factory creates interval with down direction")
    func downFactory() async {
        let di = DirectedInterval.down(.majorThird)
        #expect(di.interval == .majorThird)
        #expect(di.direction == .down)
    }

    @Test("down factory with prime normalizes to canonical prime")
    func downFactoryPrimeNormalization() async {
        let di = DirectedInterval.down(.prime)
        #expect(di == DirectedInterval.prime)
        #expect(di.direction == .up)
    }

    // MARK: - Display Name

    @Test("prime displayName is just Prime regardless of direction")
    func primeDisplayName() async {
        #expect(DirectedInterval.prime.displayName == String(localized: "Prime"))
    }

    @Test("up interval displayName composes interval name and direction")
    func upDisplayName() async {
        let di = DirectedInterval.up(.perfectFifth)
        let expected = "\(Interval.perfectFifth.name) \(Direction.up.displayName)"
        #expect(di.displayName == expected)
    }

    @Test("down interval displayName composes interval name and direction")
    func downDisplayName() async {
        let di = DirectedInterval.down(.majorThird)
        let expected = "\(Interval.majorThird.name) \(Direction.down.displayName)"
        #expect(di.displayName == expected)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() async throws {
        let cases: [DirectedInterval] = [.prime, .up(.perfectFifth), .down(.majorThird)]
        for original in cases {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(DirectedInterval.self, from: data)
            #expect(decoded == original)
        }
    }

    // MARK: - Hashable

    @Test("can be used in a Set")
    func hashableInSet() async {
        let set: Set<DirectedInterval> = [.prime, .prime, .up(.perfectFifth), .down(.perfectFifth)]
        #expect(set.count == 3)
    }

    // MARK: - Comparable

    @Test("compares by interval first")
    func comparableByInterval() async {
        #expect(DirectedInterval.up(.minorSecond) < DirectedInterval.up(.perfectFifth))
    }

    @Test("compares by direction when intervals are equal")
    func comparableByDirection() async {
        #expect(DirectedInterval.up(.perfectFifth) < DirectedInterval.down(.perfectFifth))
    }

    // MARK: - Between

    @Test("between with higher target returns up direction")
    func betweenUpDirection() async throws {
        let di = try DirectedInterval.between(MIDINote(60), MIDINote(67))
        #expect(di == .up(.perfectFifth))
    }

    @Test("between with lower target returns down direction")
    func betweenDownDirection() async throws {
        let di = try DirectedInterval.between(MIDINote(67), MIDINote(60))
        #expect(di == .down(.perfectFifth))
    }

    @Test("between same note returns prime")
    func betweenSameNote() async throws {
        let di = try DirectedInterval.between(MIDINote(60), MIDINote(60))
        #expect(di == .prime)
    }

    @Test("between throws for distance exceeding octave")
    func betweenThrowsForLargeDistance() async {
        #expect(throws: AudioError.self) {
            try DirectedInterval.between(MIDINote(60), MIDINote(80))
        }
    }

    // MARK: - MIDINote Transposition

    @Test("transposing up adds semitones")
    func transposeUp() async {
        let note = MIDINote(60).transposed(by: .up(.perfectFifth))
        #expect(note == MIDINote(67))
    }

    @Test("transposing down subtracts semitones")
    func transposeDown() async {
        let note = MIDINote(67).transposed(by: .down(.perfectFifth))
        #expect(note == MIDINote(60))
    }

    @Test("transposing by prime returns same note")
    func transposePrime() async {
        let note = MIDINote(60).transposed(by: .prime)
        #expect(note == MIDINote(60))
    }
}

import Testing
import Foundation
@testable import Peach

@Suite("MIDINote Tests")
struct MIDINoteTests {

    // MARK: - Valid Construction

    @Test("Creates valid MIDINote at boundaries")
    func validBoundaries() async {
        let low = MIDINote(0)
        let high = MIDINote(127)
        let mid = MIDINote(60)

        #expect(low.rawValue == 0)
        #expect(high.rawValue == 127)
        #expect(mid.rawValue == 60)
    }

    @Test("ExpressibleByIntegerLiteral creates MIDINote")
    func integerLiteral() async {
        let note: MIDINote = 60
        #expect(note.rawValue == 60)
    }

    // MARK: - Name

    @Test("Middle C is C4")
    func middleCName() async {
        #expect(MIDINote(60).name == "C4")
    }

    @Test("A4 is note 69")
    func a4Name() async {
        #expect(MIDINote(69).name == "A4")
    }

    @Test("Note 0 is C-1")
    func lowestNoteName() async {
        #expect(MIDINote(0).name == "C-1")
    }

    // MARK: - Frequency

    @Test("A4 frequency is 440 Hz at default reference pitch")
    func a4Frequency() async throws {
        let freq = try MIDINote(69).frequency()
        #expect(abs(freq.rawValue - 440.0) < 0.01)
    }

    @Test("Frequency respects custom reference pitch")
    func customReferencePitch() async throws {
        let freq = try MIDINote(69).frequency(referencePitch: 432.0)
        #expect(abs(freq.rawValue - 432.0) < 0.01)
    }

    // MARK: - Random

    @Test("Random note is within specified range")
    func randomInRange() async {
        for _ in 0..<100 {
            let note = MIDINote.random(in: MIDINote(48)...MIDINote(72))
            #expect(note >= 48)
            #expect(note <= 72)
        }
    }

    // MARK: - Comparable

    @Test("Lower MIDI note is less than higher")
    func comparable() async {
        #expect(MIDINote(59) < MIDINote(60))
        #expect(MIDINote(60) == MIDINote(60))
        #expect(MIDINote(61) > MIDINote(60))
    }

    // MARK: - Hashable

    @Test("Equal notes have same hash")
    func hashable() async {
        let set: Set<MIDINote> = [60, 60, 61]
        #expect(set.count == 2)
    }

    // MARK: - Codable

    @Test("Round-trips through JSON encoding")
    func codable() async throws {
        let note = MIDINote(60)
        let data = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(MIDINote.self, from: data)
        #expect(decoded == note)
    }
}

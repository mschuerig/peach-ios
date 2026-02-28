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

    // MARK: - Frequency (via TuningSystem bridge)

    @Test("A4 frequency is 440 Hz via TuningSystem bridge")
    func a4Frequency() async {
        let freq = TuningSystem.equalTemperament.frequency(for: MIDINote(69), referencePitch: .concert440)
        #expect(abs(freq.rawValue - 440.0) < 0.01)
    }

    @Test("Frequency respects custom reference pitch via TuningSystem bridge")
    func customReferencePitch() async {
        let freq = TuningSystem.equalTemperament.frequency(for: MIDINote(69), referencePitch: Frequency(432.0))
        #expect(abs(freq.rawValue - 432.0) < 0.01)
    }

    @Test("MIDI 0 frequency is approximately 8.18 Hz")
    func midi0Frequency() async {
        let freq = TuningSystem.equalTemperament.frequency(for: MIDINote(0), referencePitch: .concert440)
        #expect(abs(freq.rawValue - 8.18) < 0.1)
    }

    @Test("MIDI 127 frequency is approximately 12543 Hz")
    func midi127Frequency() async {
        let freq = TuningSystem.equalTemperament.frequency(for: MIDINote(127), referencePitch: .concert440)
        #expect(abs(freq.rawValue - 12543.0) < 1.0)
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

    // MARK: - Transposition

    @Test("C4 transposed by perfect fifth gives G4")
    func transposedByPerfectFifth() async {
        let c4 = MIDINote(60)
        let g4 = c4.transposed(by: .perfectFifth)
        #expect(g4.rawValue == 67)
    }

    @Test("Transposition by prime returns same note")
    func transposedByPrimeReturnsSameNote() async {
        let note = MIDINote(60)
        let result = note.transposed(by: .prime)
        #expect(result == note)
    }

    @Test("Transposition at top of MIDI range succeeds when within bounds")
    func transposedAtTopBoundary() async {
        let note = MIDINote(120)
        let result = note.transposed(by: .perfectFifth)
        #expect(result.rawValue == 127)
    }
}

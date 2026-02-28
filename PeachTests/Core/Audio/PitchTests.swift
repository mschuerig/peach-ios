import Testing
import Foundation
@testable import Peach

@Suite("Pitch Tests")
struct PitchTests {

    // MARK: - Pitch Frequency (AC #1, #2)

    @Test("A4 pitch frequency returns 440.0 Hz")
    func a4Frequency() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: .concert440)
        #expect(freq.rawValue == 440.0)
    }

    @Test("middle C frequency within 0.1-cent precision")
    func middleCFrequency() async {
        let pitch = Pitch(note: MIDINote(60), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: .concert440)
        // Theoretical: 440 * 2^(-9/12) ≈ 261.6255653005986
        #expect(abs(freq.rawValue - 261.6255653) < 0.01)
    }

    @Test("C5 frequency within 0.1-cent precision")
    func c5Frequency() async {
        let pitch = Pitch(note: MIDINote(72), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: .concert440)
        // Theoretical: 440 * 2^(3/12) ≈ 523.2511306011972
        #expect(abs(freq.rawValue - 523.2511306) < 0.01)
    }

    @Test("pitch with cents offset computes correct frequency")
    func pitchWithCentsOffset() async {
        // A4 + 50 cents = 440 * 2^(50/1200) ≈ 452.893 Hz
        let pitch = Pitch(note: MIDINote(69), cents: Cents(50))
        let freq = pitch.frequency(referencePitch: .concert440)
        #expect(abs(freq.rawValue - 452.893) < 0.01)
    }

    @Test("pitch frequency uses default referencePitch of concert440")
    func defaultReferencePitch() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        let freq = pitch.frequency()
        #expect(freq.rawValue == 440.0)
    }

    // MARK: - MIDINote.pitch(at:in:) (AC #3, #4)

    @Test("MIDINote.pitch with perfectFifth returns correct Pitch")
    func pitchAtPerfectFifth() async {
        let pitch = MIDINote(60).pitch(at: .perfectFifth, in: .equalTemperament)
        #expect(pitch.note == MIDINote(67))
        #expect(pitch.cents == Cents(0))
    }

    @Test("MIDINote.pitch defaults to prime/equalTemperament")
    func pitchDefaults() async {
        let pitch = MIDINote(60).pitch()
        #expect(pitch.note == MIDINote(60))
        #expect(pitch.cents == Cents(0))
    }

    @Test("MIDINote.pitch for all 13 intervals in equalTemperament has cents always 0")
    func allIntervalsEqualTemperamentCentsZero() async {
        let base = MIDINote(48) // C3, low enough to transpose up by octave
        for interval in Interval.allCases {
            let pitch = base.pitch(at: interval, in: .equalTemperament)
            #expect(pitch.note == base.transposed(by: interval),
                    "Note mismatch for \(interval)")
            #expect(pitch.cents == Cents(0),
                    "Cents should be 0 for equal temperament \(interval)")
        }
    }

    @Test("MIDINote.pitch at minorSecond returns correct note")
    func pitchAtMinorSecond() async {
        let pitch = MIDINote(60).pitch(at: .minorSecond, in: .equalTemperament)
        #expect(pitch.note == MIDINote(61))
        #expect(pitch.cents == Cents(0))
    }

    @Test("MIDINote.pitch at octave returns correct note")
    func pitchAtOctave() async {
        let pitch = MIDINote(60).pitch(at: .octave, in: .equalTemperament)
        #expect(pitch.note == MIDINote(72))
        #expect(pitch.cents == Cents(0))
    }

    // MARK: - Hashable (AC #6)

    @Test("Pitch can be used as Set element")
    func hashableSetElement() async {
        let pitch1 = Pitch(note: MIDINote(69), cents: Cents(0))
        let pitch2 = Pitch(note: MIDINote(69), cents: Cents(0))
        let pitch3 = Pitch(note: MIDINote(60), cents: Cents(0))
        let set: Set<Pitch> = [pitch1, pitch2, pitch3]
        #expect(set.count == 2)
    }

    @Test("Pitch can be used as Dictionary key")
    func hashableDictionaryKey() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        var dict: [Pitch: String] = [:]
        dict[pitch] = "A4"
        #expect(dict[pitch] == "A4")
    }

    // MARK: - Sendable (AC #6)

    @Test("Pitch is a value type (Sendable)")
    func sendableValueType() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        // Value type struct is automatically Sendable
        let copy = pitch
        #expect(copy.note == pitch.note)
        #expect(copy.cents == pitch.cents)
    }

    // MARK: - Frequency.concert440 (AC #5)

    @Test("Frequency.concert440 has value 440.0")
    func frequencyConcert440() async {
        #expect(Frequency.concert440.rawValue == 440.0)
    }
}

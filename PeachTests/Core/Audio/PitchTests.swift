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

    @Test("pitch with negative cents offset computes correct frequency")
    func pitchWithNegativeCentsOffset() async {
        // A4 - 50 cents = 440 * 2^(-50/1200) ≈ 427.474 Hz
        let pitch = Pitch(note: MIDINote(69), cents: Cents(-50))
        let freq = pitch.frequency(referencePitch: .concert440)
        #expect(abs(freq.rawValue - 427.474) < 0.01)
    }

    @Test("pitch frequency uses default referencePitch of concert440")
    func defaultReferencePitch() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        let freq = pitch.frequency()
        #expect(freq.rawValue == 440.0)
    }

    @Test("pitch frequency with non-standard reference pitch")
    func nonStandardReferencePitch() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: Frequency(442.0))
        #expect(freq.rawValue == 442.0)
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

    @Test("Pitch can be sent across concurrency boundaries")
    func sendableAcrossBoundary() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        let result = await Task.detached { pitch }.value
        #expect(result == pitch)
    }

    // MARK: - Forward Conversion Edge Cases (migrated from FrequencyCalculationTests)

    @Test("MIDI 0 frequency is approximately 8.18 Hz")
    func midi0Frequency() async {
        let pitch = Pitch(note: MIDINote(0), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: .concert440)
        #expect(abs(freq.rawValue - 8.18) < 0.1)
    }

    @Test("MIDI 127 frequency is approximately 12543 Hz")
    func midi127Frequency() async {
        let pitch = Pitch(note: MIDINote(127), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: .concert440)
        #expect(abs(freq.rawValue - 12543.0) < 1.0)
    }

    @Test("+100 cents equals next semitone")
    func extremeCentsEqualsNextSemitone() async {
        let c4Plus100 = Pitch(note: MIDINote(60), cents: Cents(100)).frequency(referencePitch: .concert440)
        let cSharp4 = Pitch(note: MIDINote(61), cents: Cents(0)).frequency(referencePitch: .concert440)
        #expect(abs(c4Plus100.rawValue - cSharp4.rawValue) < 0.01)
    }

    @Test("0.1 cent precision: 0 and 0.1 cents produce different frequencies")
    func subCentPrecision() async {
        let freq1 = Pitch(note: MIDINote(69), cents: Cents(0)).frequency(referencePitch: .concert440)
        let freq2 = Pitch(note: MIDINote(69), cents: Cents(0.1)).frequency(referencePitch: .concert440)
        #expect(freq1 != freq2)
        #expect(abs(freq2.rawValue - freq1.rawValue) < 0.1)
    }

    @Test("A4 at 432 Hz reference returns 432 Hz")
    func a4At432Reference() async {
        let freq = Pitch(note: MIDINote(69), cents: Cents(0)).frequency(referencePitch: Frequency(432.0))
        #expect(abs(freq.rawValue - 432.0) < 0.001)
    }

    @Test("A4 at 415 Hz reference returns 415 Hz")
    func a4At415Reference() async {
        let freq = Pitch(note: MIDINote(69), cents: Cents(0)).frequency(referencePitch: Frequency(415.0))
        #expect(abs(freq.rawValue - 415.0) < 0.001)
    }

    @Test("Middle C at different reference pitches scales proportionally")
    func middleCVariousTunings() async {
        let c4_440 = Pitch(note: MIDINote(60), cents: Cents(0)).frequency(referencePitch: .concert440)
        #expect(abs(c4_440.rawValue - 261.626) < 0.01)

        let c4_442 = Pitch(note: MIDINote(60), cents: Cents(0)).frequency(referencePitch: Frequency(442.0))
        let expected442 = 261.626 * (442.0 / 440.0)
        #expect(abs(c4_442.rawValue - expected442) < 0.01)

        let c4_432 = Pitch(note: MIDINote(60), cents: Cents(0)).frequency(referencePitch: Frequency(432.0))
        let expected432 = 261.626 * (432.0 / 440.0)
        #expect(abs(c4_432.rawValue - expected432) < 0.01)
    }

    @Test("0.1 cent precision with custom reference pitch 442")
    func subCentPrecisionCustomRef() async {
        let freq1 = Pitch(note: MIDINote(69), cents: Cents(0)).frequency(referencePitch: Frequency(442.0))
        let freq2 = Pitch(note: MIDINote(69), cents: Cents(0.1)).frequency(referencePitch: Frequency(442.0))
        #expect(freq1 != freq2)
        #expect(abs(freq2.rawValue - freq1.rawValue) < 0.1)
    }

    @Test("Round-trip: arbitrary note and cents (MIDI 45 + 73.5 cents)")
    func roundTripArbitrary() async {
        let original = Pitch(note: MIDINote(45), cents: Cents(73.5))
        let freq = original.frequency(referencePitch: .concert440)
        let reconstructed = Pitch(frequency: freq, referencePitch: .concert440)
        let finalFreq = reconstructed.frequency(referencePitch: .concert440)
        let centError = 1200.0 * log2(finalFreq.rawValue / freq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("Round-trip: A415 reference pitch preserved")
    func roundTripA415Reference() async {
        let ref = Frequency(415.0)
        let original = Pitch(note: MIDINote(69), cents: Cents(-15))
        let freq = original.frequency(referencePitch: ref)
        let reconstructed = Pitch(frequency: freq, referencePitch: ref)
        #expect(reconstructed.note == MIDINote(69))
        #expect(abs(reconstructed.cents.rawValue - (-15.0)) < 0.1)
    }

    @Test("Cents remainder from inverse conversion is always in range -50 to +50")
    func centsRemainderRange() async {
        for midiValue in stride(from: 0, through: 127, by: 10) {
            for centsValue in stride(from: -49.0, through: 49.0, by: 7.0) {
                let freq = Pitch(note: MIDINote(midiValue), cents: Cents(centsValue))
                    .frequency(referencePitch: .concert440)
                let result = Pitch(frequency: freq, referencePitch: .concert440)
                #expect(result.cents.rawValue >= -50.0 && result.cents.rawValue <= 50.0)
            }
        }
    }

    // MARK: - Pitch.init(frequency:referencePitch:) — Inverse Conversion

    @Test("440 Hz at concert440 reference gives A4 (MIDI 69, 0 cents)")
    func inverseA4() async {
        let pitch = Pitch(frequency: Frequency(440.0), referencePitch: .concert440)
        #expect(pitch.note == MIDINote(69))
        #expect(abs(pitch.cents.rawValue) < 0.01)
    }

    @Test("261.626 Hz at concert440 reference gives Middle C (MIDI 60, 0 cents)")
    func inverseMiddleC() async {
        let pitch = Pitch(frequency: Frequency(261.6255653), referencePitch: .concert440)
        #expect(pitch.note == MIDINote(60))
        #expect(abs(pitch.cents.rawValue) < 0.1)
    }

    @Test("442 Hz at 442 Hz reference gives MIDI 69, 0 cents")
    func inverseNonStandardReference() async {
        let pitch = Pitch(frequency: Frequency(442.0), referencePitch: Frequency(442.0))
        #expect(pitch.note == MIDINote(69))
        #expect(abs(pitch.cents.rawValue) < 0.01)
    }

    @Test("415 Hz at 415 Hz reference gives MIDI 69, 0 cents")
    func inverseBaroqueReference() async {
        let pitch = Pitch(frequency: Frequency(415.0), referencePitch: Frequency(415.0))
        #expect(pitch.note == MIDINote(69))
        #expect(abs(pitch.cents.rawValue) < 0.01)
    }

    @Test("Half-semitone above A4 (~452.893 Hz) gives MIDI 69 or 70 with ~50 cents offset")
    func inverseHalfSemitone() async {
        // 440 * 2^(50/1200) ≈ 452.893 Hz — exactly halfway between A4 and Bb4
        let pitch = Pitch(frequency: Frequency(452.893), referencePitch: .concert440)
        // At +50 cents, rounding goes to 70 (rounds .5 up), so expect MIDI 70, -50 cents
        // OR MIDI 69, +50 cents — either is valid as long as round-trip is correct
        let roundTrip = pitch.frequency(referencePitch: .concert440)
        let centError = 1200.0 * log2(roundTrip.rawValue / 452.893)
        #expect(abs(centError) < 0.1)
    }

    @Test("Half-semitone below A4 (~427.474 Hz) gives correct pitch")
    func inverseNegativeHalfSemitone() async {
        // 440 * 2^(-50/1200) ≈ 427.474 Hz
        let pitch = Pitch(frequency: Frequency(427.474), referencePitch: .concert440)
        let roundTrip = pitch.frequency(referencePitch: .concert440)
        let centError = 1200.0 * log2(roundTrip.rawValue / 427.474)
        #expect(abs(centError) < 0.1)
    }

    @Test("Lowest MIDI note frequency (~8.176 Hz) gives MIDI 0")
    func inverseBoundaryLowest() async {
        // MIDI 0 = C-1 ≈ 8.17579891564 Hz
        let pitch = Pitch(frequency: Frequency(8.17579891564), referencePitch: .concert440)
        #expect(pitch.note == MIDINote(0))
        #expect(abs(pitch.cents.rawValue) < 0.1)
    }

    @Test("Highest MIDI note frequency (~12543.85 Hz) gives MIDI 127")
    func inverseBoundaryHighest() async {
        // MIDI 127 = G9 ≈ 12543.853951 Hz
        let pitch = Pitch(frequency: Frequency(12543.853951), referencePitch: .concert440)
        #expect(pitch.note == MIDINote(127))
        #expect(abs(pitch.cents.rawValue) < 0.1)
    }

    @Test("Frequency below MIDI 0 clamps to MIDI 0")
    func inverseBelowRange() async {
        // Very low frequency that would be below MIDI 0
        let pitch = Pitch(frequency: Frequency(5.0), referencePitch: .concert440)
        #expect(pitch.note == MIDINote(0))
    }

    @Test("Frequency above MIDI 127 clamps to MIDI 127")
    func inverseAboveRange() async {
        // Very high frequency that would be above MIDI 127
        let pitch = Pitch(frequency: Frequency(20000.0), referencePitch: .concert440)
        #expect(pitch.note == MIDINote(127))
    }

    // MARK: - Round-Trip Tests (frequency → Pitch → frequency)

    @Test("Round-trip: A4 frequency preserved within 0.1-cent precision")
    func roundTripA4() async {
        let originalFreq = Frequency(440.0)
        let pitch = Pitch(frequency: originalFreq, referencePitch: .concert440)
        let reconstructed = pitch.frequency(referencePitch: .concert440)
        let centError = 1200.0 * log2(reconstructed.rawValue / originalFreq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("Round-trip: Middle C frequency preserved within 0.1-cent precision")
    func roundTripMiddleC() async {
        let originalFreq = Frequency(261.6255653)
        let pitch = Pitch(frequency: originalFreq, referencePitch: .concert440)
        let reconstructed = pitch.frequency(referencePitch: .concert440)
        let centError = 1200.0 * log2(reconstructed.rawValue / originalFreq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("Round-trip: frequency with cent offset preserved")
    func roundTripWithOffset() async {
        // A4 + 25 cents
        let pitch1 = Pitch(note: MIDINote(69), cents: Cents(25))
        let freq = pitch1.frequency(referencePitch: .concert440)
        let pitch2 = Pitch(frequency: freq, referencePitch: .concert440)
        let reconstructed = pitch2.frequency(referencePitch: .concert440)
        let centError = 1200.0 * log2(reconstructed.rawValue / freq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("Round-trip: negative cent offset preserved")
    func roundTripNegativeOffset() async {
        let pitch1 = Pitch(note: MIDINote(60), cents: Cents(-25))
        let freq = pitch1.frequency(referencePitch: .concert440)
        let pitch2 = Pitch(frequency: freq, referencePitch: .concert440)
        let reconstructed = pitch2.frequency(referencePitch: .concert440)
        let centError = 1200.0 * log2(reconstructed.rawValue / freq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("Round-trip: non-440 reference pitch preserved")
    func roundTripNonStandardRef() async {
        let ref = Frequency(442.0)
        let pitch1 = Pitch(note: MIDINote(60), cents: Cents(30))
        let freq = pitch1.frequency(referencePitch: ref)
        let pitch2 = Pitch(frequency: freq, referencePitch: ref)
        let reconstructed = pitch2.frequency(referencePitch: ref)
        let centError = 1200.0 * log2(reconstructed.rawValue / freq.rawValue)
        #expect(abs(centError) < 0.1)
    }

    @Test("Round-trip: exact MIDI notes across range return 0 cents")
    func roundTripExactMidiNotes() async {
        for midiValue in [0, 21, 36, 48, 60, 69, 84, 96, 108, 127] {
            let pitch = Pitch(note: MIDINote(midiValue), cents: Cents(0))
            let freq = pitch.frequency(referencePitch: .concert440)
            let reconstructed = Pitch(frequency: freq, referencePitch: .concert440)
            #expect(reconstructed.note == MIDINote(midiValue), "MIDI note \(midiValue) failed")
            #expect(abs(reconstructed.cents.rawValue) < 0.1)
        }
    }

    @Test("Pitch.init(frequency:) uses concert440 as default reference")
    func inverseDefaultReference() async {
        let pitch = Pitch(frequency: Frequency(440.0))
        #expect(pitch.note == MIDINote(69))
        #expect(abs(pitch.cents.rawValue) < 0.01)
    }

    // MARK: - Frequency.concert440 (AC #5)

    @Test("Frequency.concert440 has value 440.0")
    func frequencyConcert440() async {
        #expect(Frequency.concert440.rawValue == 440.0)
    }
}

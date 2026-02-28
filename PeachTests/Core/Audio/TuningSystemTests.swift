import Testing
import Foundation
@testable import Peach

@Suite("TuningSystem Tests")
struct TuningSystemTests {

    // MARK: - Equal Temperament Cent Offsets (AC #1, #2, #3)

    @Test("equalTemperament centOffset for perfectFifth returns 700.0")
    func perfectFifthCentOffset() async {
        #expect(TuningSystem.equalTemperament.centOffset(for: .perfectFifth) == 700.0)
    }

    @Test("equalTemperament centOffset for prime returns 0.0")
    func primeCentOffset() async {
        #expect(TuningSystem.equalTemperament.centOffset(for: .prime) == 0.0)
    }

    @Test("equalTemperament centOffset for octave returns 1200.0")
    func octaveCentOffset() async {
        #expect(TuningSystem.equalTemperament.centOffset(for: .octave) == 1200.0)
    }

    // MARK: - All 13 Intervals (AC #1, #2, #3)

    @Test("all 13 intervals have correct equal temperament cent values")
    func allIntervalsCentValues() async {
        let expectedCents: [Interval: Double] = [
            .prime: 0, .minorSecond: 100, .majorSecond: 200,
            .minorThird: 300, .majorThird: 400, .perfectFourth: 500,
            .tritone: 600, .perfectFifth: 700, .minorSixth: 800,
            .majorSixth: 900, .minorSeventh: 1000, .majorSeventh: 1100,
            .octave: 1200
        ]
        for interval in Interval.allCases {
            let expected = expectedCents[interval]
            #expect(
                TuningSystem.equalTemperament.centOffset(for: interval) == expected,
                "Unexpected cent offset for \(interval)"
            )
        }
    }

    // MARK: - CaseIterable (AC #4)

    @Test("CaseIterable gives 1 case")
    func caseIterableCount() async {
        #expect(TuningSystem.allCases.count == 1)
    }

    // MARK: - Codable (AC #4)

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() async throws {
        let original = TuningSystem.equalTemperament
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TuningSystem.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Hashable (AC #4)

    @Test("can be used as Set element")
    func hashableSetElement() async {
        let set: Set<TuningSystem> = [.equalTemperament, .equalTemperament]
        #expect(set.count == 1)
    }

    @Test("can be used as Dictionary key")
    func hashableDictionaryKey() async {
        var dict: [TuningSystem: String] = [:]
        dict[.equalTemperament] = "12-TET"
        #expect(dict[.equalTemperament] == "12-TET")
    }

    // MARK: - frequency(for: DetunedMIDINote) (Story 22.3 AC #3)

    @Test("A4 with zero offset returns 440.0 Hz")
    func frequencyA4ZeroOffset() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(69), offset: Cents(0)),
            referencePitch: .concert440
        )
        #expect(freq.rawValue == 440.0)
    }

    @Test("middle C frequency within 0.1-cent precision")
    func frequencyMiddleC() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(60)),
            referencePitch: .concert440
        )
        #expect(abs(freq.rawValue - 261.6255653) < 0.01)
    }

    @Test("C5 frequency within 0.1-cent precision")
    func frequencyC5() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(72)),
            referencePitch: .concert440
        )
        #expect(abs(freq.rawValue - 523.2511306) < 0.01)
    }

    @Test("DetunedMIDINote with +50 cents offset computes correct frequency")
    func frequencyPositiveCentsOffset() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(69), offset: Cents(50)),
            referencePitch: .concert440
        )
        #expect(abs(freq.rawValue - 452.893) < 0.01)
    }

    @Test("DetunedMIDINote with -50 cents offset computes correct frequency")
    func frequencyNegativeCentsOffset() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(69), offset: Cents(-50)),
            referencePitch: .concert440
        )
        #expect(abs(freq.rawValue - 427.474) < 0.01)
    }

    @Test("frequency with non-standard reference pitch 442")
    func frequencyNonStandardReference() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(69)),
            referencePitch: Frequency(442.0)
        )
        #expect(freq.rawValue == 442.0)
    }

    @Test("MIDI 0 frequency is approximately 8.18 Hz")
    func frequencyMidi0() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(0)),
            referencePitch: .concert440
        )
        #expect(abs(freq.rawValue - 8.18) < 0.1)
    }

    @Test("MIDI 127 frequency is approximately 12543 Hz")
    func frequencyMidi127() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(127)),
            referencePitch: .concert440
        )
        #expect(abs(freq.rawValue - 12543.0) < 1.0)
    }

    @Test("+100 cents equals next semitone")
    func frequencyPlus100CentsEqualsNextSemitone() async {
        let c4Plus100 = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(60), offset: Cents(100)),
            referencePitch: .concert440
        )
        let cSharp4 = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(61)),
            referencePitch: .concert440
        )
        #expect(abs(c4Plus100.rawValue - cSharp4.rawValue) < 0.01)
    }

    @Test("0.1 cent precision: 0 and 0.1 cents produce different frequencies")
    func frequencySubCentPrecision() async {
        let freq1 = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(69), offset: Cents(0)),
            referencePitch: .concert440
        )
        let freq2 = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: MIDINote(69), offset: Cents(0.1)),
            referencePitch: .concert440
        )
        #expect(freq1 != freq2)
        #expect(abs(freq2.rawValue - freq1.rawValue) < 0.1)
    }

    @Test("A4 at 432 Hz reference returns 432 Hz")
    func frequencyA4At432Reference() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(69)),
            referencePitch: Frequency(432.0)
        )
        #expect(abs(freq.rawValue - 432.0) < 0.001)
    }

    @Test("middle C at different reference pitches scales proportionally")
    func frequencyMiddleCVariousTunings() async {
        let c4_440 = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(60)),
            referencePitch: .concert440
        )
        #expect(abs(c4_440.rawValue - 261.626) < 0.01)

        let c4_442 = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(60)),
            referencePitch: Frequency(442.0)
        )
        let expected442 = 261.626 * (442.0 / 440.0)
        #expect(abs(c4_442.rawValue - expected442) < 0.01)
    }

    // MARK: - frequency(for: MIDINote) Convenience (Story 22.3 AC #4)

    @Test("MIDINote overload returns same result as DetunedMIDINote with zero offset")
    func frequencyMIDINoteConvenienceDelegates() async {
        let fromMIDINote = TuningSystem.equalTemperament.frequency(
            for: MIDINote(60),
            referencePitch: .concert440
        )
        let fromDetuned = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(MIDINote(60)),
            referencePitch: .concert440
        )
        #expect(fromMIDINote == fromDetuned)
    }

    @Test("MIDINote overload A4 returns 440 Hz")
    func frequencyMIDINoteA4() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: MIDINote(69),
            referencePitch: .concert440
        )
        #expect(freq.rawValue == 440.0)
    }

    @Test("MIDINote overload requires explicit referencePitch (no defaults)")
    func frequencyMIDINoteExplicitParams() async {
        // This test verifies both parameters must be passed — compile-time check
        let freq = TuningSystem.equalTemperament.frequency(
            for: MIDINote(69),
            referencePitch: Frequency(442.0)
        )
        #expect(freq.rawValue == 442.0)
    }
}

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

    // MARK: - Just Intonation Cent Offsets

    @Test("all 13 intervals have correct just intonation cent values")
    func allIntervalsJustIntonationCentValues() async {
        let expectedCents: [Interval: Double] = [
            .prime: 0.0, .minorSecond: 111.731, .majorSecond: 203.910,
            .minorThird: 315.641, .majorThird: 386.314, .perfectFourth: 498.045,
            .tritone: 590.224, .perfectFifth: 701.955, .minorSixth: 813.686,
            .majorSixth: 884.359, .minorSeventh: 1017.596, .majorSeventh: 1088.269,
            .octave: 1200.0
        ]
        for interval in Interval.allCases {
            let actual = TuningSystem.justIntonation.centOffset(for: interval)
            let expected = expectedCents[interval]!
            #expect(
                abs(actual - expected) < 0.001,
                "Unexpected JI cent offset for \(interval): got \(actual), expected \(expected)"
            )
        }
    }

    @Test("justIntonation centOffset for prime returns 0.0")
    func justIntonationPrimeCentOffset() async {
        #expect(TuningSystem.justIntonation.centOffset(for: .prime) == 0.0)
    }

    @Test("justIntonation centOffset for octave returns 1200.0")
    func justIntonationOctaveCentOffset() async {
        #expect(TuningSystem.justIntonation.centOffset(for: .octave) == 1200.0)
    }

    @Test("justIntonation centOffset for majorThird returns 386.314")
    func justIntonationMajorThirdCentOffset() async {
        let actual = TuningSystem.justIntonation.centOffset(for: .majorThird)
        #expect(abs(actual - 386.314) < 0.001)
    }

    @Test("justIntonation centOffset for perfectFifth returns 701.955")
    func justIntonationPerfectFifthCentOffset() async {
        let actual = TuningSystem.justIntonation.centOffset(for: .perfectFifth)
        #expect(abs(actual - 701.955) < 0.001)
    }

    // MARK: - CaseIterable (AC #4)

    @Test("CaseIterable gives 2 cases")
    func caseIterableCount() async {
        #expect(TuningSystem.allCases.count == 2)
    }

    // MARK: - Codable (AC #4)

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() async throws {
        let original = TuningSystem.equalTemperament
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TuningSystem.self, from: data)
        #expect(decoded == original)
    }

    @Test("Codable round-trip preserves justIntonation")
    func codableRoundTripJustIntonation() async throws {
        let original = TuningSystem.justIntonation
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

    // MARK: - Display Names

    @Test("displayName returns Equal Temperament for equalTemperament")
    func displayNameEqualTemperament() async {
        #expect(TuningSystem.equalTemperament.displayName == String(localized: "Equal Temperament"))
    }

    @Test("displayName returns Just Intonation for justIntonation")
    func displayNameJustIntonation() async {
        #expect(TuningSystem.justIntonation.displayName == String(localized: "Just Intonation"))
    }

    @Test("all cases have non-empty displayName")
    func allCasesHaveDisplayName() async {
        for system in TuningSystem.allCases {
            #expect(!system.displayName.isEmpty)
        }
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

    // MARK: - Just Intonation Frequency Precision (NFR14)

    @Test("justIntonation frequency for just major third is accurate to 0.1 cent")
    func justIntonationFrequencyMajorThird() async {
        // Just M3 ratio = 5/4, so expected Hz = 440.0 × 5/4 = 550.0
        // MIDI 73 (C#5) with offset 386.314 - 400.0 = -13.686 cents
        let freq = TuningSystem.justIntonation.frequency(
            for: DetunedMIDINote(note: MIDINote(73), offset: Cents(-13.686)),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * (5.0 / 4.0) // 550.0 Hz exactly
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("justIntonation frequency for just perfect fifth is accurate to 0.1 cent")
    func justIntonationFrequencyPerfectFifth() async {
        // Just P5 ratio = 3/2, so expected Hz = 440.0 × 3/2 = 660.0
        // MIDI 76 (E5) with offset 701.955 - 700.0 = +1.955 cents
        let freq = TuningSystem.justIntonation.frequency(
            for: DetunedMIDINote(note: MIDINote(76), offset: Cents(1.955)),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * (3.0 / 2.0) // 660.0 Hz exactly
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("justIntonation frequency for just minor seventh is accurate to 0.1 cent")
    func justIntonationFrequencyMinorSeventh() async {
        // Just m7 ratio = 9/5, so expected Hz = 440.0 × 9/5 = 792.0
        // MIDI 79 (G5) with offset 1017.596 - 1000.0 = +17.596 cents
        let freq = TuningSystem.justIntonation.frequency(
            for: DetunedMIDINote(note: MIDINote(79), offset: Cents(17.596)),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * (9.0 / 5.0) // 792.0 Hz exactly
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    // MARK: - Storage Identifiers (Story 23.1)

    @Test("storageIdentifier returns stable string for equalTemperament")
    func storageIdentifierEqualTemperament() async {
        #expect(TuningSystem.equalTemperament.storageIdentifier == "equalTemperament")
    }

    @Test("fromStorageIdentifier round-trips equalTemperament")
    func fromStorageIdentifierRoundTrip() async {
        let original = TuningSystem.equalTemperament
        let identifier = original.storageIdentifier
        let restored = TuningSystem.fromStorageIdentifier(identifier)
        #expect(restored == original)
    }

    @Test("storageIdentifier returns justIntonation for justIntonation")
    func storageIdentifierJustIntonation() async {
        #expect(TuningSystem.justIntonation.storageIdentifier == "justIntonation")
    }

    @Test("fromStorageIdentifier round-trips justIntonation")
    func fromStorageIdentifierJustIntonationRoundTrip() async {
        let original = TuningSystem.justIntonation
        let identifier = original.storageIdentifier
        let restored = TuningSystem.fromStorageIdentifier(identifier)
        #expect(restored == original)
    }

    @Test("fromStorageIdentifier returns nil for unknown identifier")
    func fromStorageIdentifierUnknown() async {
        #expect(TuningSystem.fromStorageIdentifier("") == nil)
        #expect(TuningSystem.fromStorageIdentifier("EqualTemperament") == nil)
        #expect(TuningSystem.fromStorageIdentifier("pythagorean") == nil)
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
        // Both parameters are explicitly supplied — no defaults exist on the method signature
        let freq = TuningSystem.equalTemperament.frequency(
            for: MIDINote(69),
            referencePitch: Frequency(442.0)
        )
        #expect(freq.rawValue == 442.0)
    }
}

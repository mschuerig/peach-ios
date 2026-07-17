import Testing
import Foundation
@testable import Peach

/// Shared assertion oracle: cent distance from `reference` up to `target`
/// (negative when target is below).
func centsAbove(_ reference: Frequency, _ target: Frequency) -> Double {
    Cents.perOctave.rawValue * log2(target.rawValue / reference.rawValue)
}

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
                TuningSystem.equalTemperament.centOffset(for: interval).rawValue == expected,
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
            let actual = TuningSystem.justIntonation.centOffset(for: interval).rawValue
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
        let actual = TuningSystem.justIntonation.centOffset(for: .majorThird).rawValue
        #expect(abs(actual - 386.314) < 0.001)
    }

    @Test("justIntonation centOffset for perfectFifth returns 701.955")
    func justIntonationPerfectFifthCentOffset() async {
        let actual = TuningSystem.justIntonation.centOffset(for: .perfectFifth).rawValue
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
            #expect(system.displayName.isEmpty == false)
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

    @Test("justIntonation produces just major third frequency for MIDINote 4 semitones above A4")
    func justIntonationFrequencyMajorThird() async {
        let freq = TuningSystem.justIntonation.frequency(
            for: MIDINote(73),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * (5.0 / 4.0) // 550.0 Hz
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("justIntonation produces just perfect fifth frequency for MIDINote 7 semitones above A4")
    func justIntonationFrequencyPerfectFifth() async {
        let freq = TuningSystem.justIntonation.frequency(
            for: MIDINote(76),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * (3.0 / 2.0) // 660.0 Hz
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("justIntonation produces just minor seventh frequency for MIDINote 10 semitones above A4")
    func justIntonationFrequencyMinorSeventh() async {
        let freq = TuningSystem.justIntonation.frequency(
            for: MIDINote(79),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * (9.0 / 5.0) // 792.0 Hz
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    // MARK: - Just Intonation Decomposition Edge Cases

    @Test("justIntonation produces correct frequency for note below reference (D4, 7 semitones below A4)")
    func justIntonationFrequencyBelowReference() async {
        let freq = TuningSystem.justIntonation.frequency(
            for: MIDINote(62),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 / (3.0 / 2.0) // 293.333... Hz
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("justIntonation produces correct frequency for multi-octave span (19 semitones above A4)")
    func justIntonationFrequencyMultiOctaveSpan() async {
        let freq = TuningSystem.justIntonation.frequency(
            for: MIDINote(88),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * 2.0 * (3.0 / 2.0) // 1320.0 Hz
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("equalTemperament still produces 12-TET perfect fifth after refactor")
    func equalTemperamentPerfectFifthUnchanged() async {
        let freq = TuningSystem.equalTemperament.frequency(
            for: MIDINote(76),
            referencePitch: .concert440
        )
        let expectedHz = 440.0 * pow(2.0, 7.0 / 12.0) // 659.255... Hz
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("justIntonation applies positive DetunedMIDINote offset on top of JI perfect fifth")
    func justIntonationWithPositiveDetunedOffset() async {
        let freq = TuningSystem.justIntonation.frequency(
            for: DetunedMIDINote(note: MIDINote(76), offset: Cents(10)),
            referencePitch: .concert440
        )
        let jiPerfectFifthHz = 440.0 * (3.0 / 2.0) // 660.0 Hz
        let expectedHz = jiPerfectFifthHz * pow(2.0, 10.0 / 1200.0)
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    @Test("justIntonation applies negative DetunedMIDINote offset on top of JI perfect fifth")
    func justIntonationWithNegativeDetunedOffset() async {
        let freq = TuningSystem.justIntonation.frequency(
            for: DetunedMIDINote(note: MIDINote(76), offset: Cents(-15)),
            referencePitch: .concert440
        )
        let jiPerfectFifthHz = 440.0 * (3.0 / 2.0) // 660.0 Hz
        let expectedHz = jiPerfectFifthHz * pow(2.0, -15.0 / 1200.0)
        let centError = abs(1200.0 * log2(freq.rawValue / expectedHz))
        #expect(centError < 0.1)
    }

    // MARK: - Reference-Relative Bridge Helpers (Story 87.1)

    /// Equal-tempered absolute frequency of a note — the reference tone's pitch in all tuning systems.
    private func etFrequency(of note: MIDINote) -> Frequency {
        TuningSystem.equalTemperament.frequency(for: note, referencePitch: .concert440)
    }

    // MARK: - intervalCents(for:) (Story 87.1)

    @Test("equalTemperament intervalCents is signed semitones times 100")
    func intervalCentsEqualTemperamentSigned() async {
        #expect(TuningSystem.equalTemperament.intervalCents(for: .up(.perfectFifth)) == Cents(700.0))
        #expect(TuningSystem.equalTemperament.intervalCents(for: .down(.perfectFifth)) == Cents(-700.0))
        #expect(TuningSystem.equalTemperament.intervalCents(for: .up(.octave)) == Cents(1200.0))
        #expect(TuningSystem.equalTemperament.intervalCents(for: .prime) == Cents(0.0))
    }

    @Test("justIntonation intervalCents is the pure-ratio size, negated when descending")
    func intervalCentsJustIntonationSigned() async {
        let up = TuningSystem.justIntonation.intervalCents(for: .up(.majorThird))
        let down = TuningSystem.justIntonation.intervalCents(for: .down(.majorThird))
        #expect(abs(up.rawValue - 386.314) < 0.001)
        #expect(abs(down.rawValue + 386.314) < 0.001)
        #expect(TuningSystem.justIntonation.intervalCents(for: .prime) == Cents(0.0))
    }

    // MARK: - Reference-Relative Fifths from Former Wolf Roots (Matrix Row 1)

    @Test("justIntonation perfect fifth is pure 3/2 from every former wolf root", arguments: [MIDINote(71), MIDINote(67), MIDINote(75)])
    func justIntonationFifthPureFromWolfRoots(root: MIDINote) async {
        let reference = etFrequency(of: root)
        let target = TuningSystem.justIntonation.frequency(
            for: DetunedDirectedInterval(.up(.perfectFifth)), from: root, referencePitch: .concert440)
        #expect(abs(centsAbove(reference, target) - 701.955) < 0.001)
    }

    // MARK: - Reference-Relative Major Thirds from Former Wolf Roots (Matrix Row 2)

    @Test("justIntonation major third is pure 5/4 from every former wolf root", arguments: [MIDINote(61), MIDINote(63), MIDINote(66), MIDINote(68)])
    func justIntonationMajorThirdPureFromWolfRoots(root: MIDINote) async {
        let reference = etFrequency(of: root)
        let target = TuningSystem.justIntonation.frequency(
            for: DetunedDirectedInterval(.up(.majorThird)), from: root, referencePitch: .concert440)
        #expect(abs(centsAbove(reference, target) - 386.314) < 0.001)
    }

    // MARK: - Root Invariance (Matrix Row 3)

    @Test("justIntonation in-tune relationship is invariant under reference choice")
    func justIntonationRootInvariance() async {
        let intervals: [DirectedInterval] = [
            .up(.minorSecond), .up(.majorThird), .down(.perfectFifth), .up(.minorSeventh),
        ]
        let detune = Cents(7.3)
        for interval in intervals {
            let refA = etFrequency(of: MIDINote(60))
            let refB = etFrequency(of: MIDINote(78))
            let detuned = DetunedDirectedInterval(interval: interval, offset: detune)
            let targetA = TuningSystem.justIntonation.frequency(for: detuned, from: MIDINote(60), referencePitch: .concert440)
            let targetB = TuningSystem.justIntonation.frequency(for: detuned, from: MIDINote(78), referencePitch: .concert440)
            #expect(
                abs(centsAbove(refA, targetA) - centsAbove(refB, targetB)) < 0.000001,
                "Root-dependent in-tune point for \(interval)"
            )
        }
    }

    // MARK: - Descending Inversion (Matrix Row 4)

    @Test("justIntonation descending perfect fifth is the inverted pure ratio")
    func justIntonationDescendingFifthInverted() async {
        let reference = etFrequency(of: MIDINote(69))
        let target = TuningSystem.justIntonation.frequency(
            for: DetunedDirectedInterval(.down(.perfectFifth)), from: MIDINote(69), referencePitch: .concert440)
        #expect(abs(centsAbove(reference, target) + 701.955) < 0.001)
    }

    // MARK: - ET Equivalence with the Absolute Path (Matrix Row 5)

    @Test("equalTemperament reference-relative path matches the absolute path for all directed intervals",
          arguments: Interval.allCases, Direction.allCases)
    func equalTemperamentReferenceRelativeMatchesAbsolutePath(interval: Interval, direction: Direction) async {
        let referenceNotes: [MIDINote] = [MIDINote(48), MIDINote(60), MIDINote(71)]
        let detunes: [Cents] = [Cents(0), Cents(8.0), Cents(-14.6)]
        let directed = DirectedInterval(interval: interval, direction: direction)
        for referenceNote in referenceNotes {
            for detune in detunes {
                let targetNote = referenceNote.transposed(by: directed)
                let absolute = TuningSystem.equalTemperament.frequency(
                    for: DetunedMIDINote(note: targetNote, offset: detune),
                    referencePitch: .concert440)
                let relative = TuningSystem.equalTemperament.frequency(
                    for: DetunedDirectedInterval(interval: directed, offset: detune),
                    from: referenceNote, referencePitch: .concert440)
                #expect(
                    abs(centsAbove(absolute, relative)) < 0.000001,
                    "ET divergence for \(directed) from \(referenceNote.rawValue) detuned \(detune.rawValue)"
                )
            }
        }
    }

    // MARK: - Detune on Top of the Pure Ratio (Matrix Row 6 at API Level)

    @Test("justIntonation applies detune on top of the pure ratio")
    func justIntonationDetuneOnTopOfPureRatio() async {
        let reference = etFrequency(of: MIDINote(64))
        let target = TuningSystem.justIntonation.frequency(
            for: DetunedDirectedInterval(interval: .up(.perfectFifth), offset: Cents(8.0)),
            from: MIDINote(64), referencePitch: .concert440)
        #expect(abs(centsAbove(reference, target) - (701.955 + 8.0)) < 0.001)
    }

    @Test("justIntonation unison detune matches the bare detune (prime is 1/1)")
    func justIntonationUnisonDetune() async {
        let reference = etFrequency(of: MIDINote(57))
        let target = TuningSystem.justIntonation.frequency(
            for: DetunedDirectedInterval(interval: .prime, offset: Cents(8.0)),
            from: MIDINote(57), referencePitch: .concert440)
        #expect(abs(centsAbove(reference, target) - 8.0) < 0.001)
    }

    // MARK: - Octave Purity (Matrix Row 7)

    @Test("octave is exactly 2/1 in both tuning systems")
    func octavePureInBothSystems() async {
        let reference = etFrequency(of: MIDINote(52))
        for system in TuningSystem.allCases {
            let target = system.frequency(for: DetunedDirectedInterval(.up(.octave)), from: MIDINote(52), referencePitch: .concert440)
            #expect(abs(centsAbove(reference, target) - 1200.0) < 0.000001)
        }
    }

    // MARK: - ET-vs-JI Divergence Constants (Matrix Row 10)

    @Test("justIntonation major third target is 13.686 cents flat of the equal-tempered target")
    func justIntonationMajorThirdDivergenceFromET() async {
        let etTarget = TuningSystem.equalTemperament.frequency(
            for: DetunedDirectedInterval(.up(.majorThird)), from: MIDINote(61), referencePitch: .concert440)
        let jiTarget = TuningSystem.justIntonation.frequency(
            for: DetunedDirectedInterval(.up(.majorThird)), from: MIDINote(61), referencePitch: .concert440)
        #expect(abs(centsAbove(jiTarget, etTarget) - 13.686) < 0.001)
    }

    @Test("justIntonation perfect fifth target is 1.955 cents sharp of the equal-tempered target")
    func justIntonationPerfectFifthDivergenceFromET() async {
        let etTarget = TuningSystem.equalTemperament.frequency(
            for: DetunedDirectedInterval(.up(.perfectFifth)), from: MIDINote(71), referencePitch: .concert440)
        let jiTarget = TuningSystem.justIntonation.frequency(
            for: DetunedDirectedInterval(.up(.perfectFifth)), from: MIDINote(71), referencePitch: .concert440)
        #expect(abs(centsAbove(etTarget, jiTarget) - 1.955) < 0.001)
    }

    // MARK: - String Identifier

    @Test("identifier returns stable string for equalTemperament")
    func identifierEqualTemperament() async {
        #expect(TuningSystem.equalTemperament.identifier == "equalTemperament")
    }

    @Test("init(identifier:) round-trips equalTemperament")
    func identifierRoundTrip() async {
        let original = TuningSystem.equalTemperament
        let restored = TuningSystem(identifier: original.identifier)
        #expect(restored == original)
    }

    @Test("identifier returns justIntonation for justIntonation")
    func identifierJustIntonation() async {
        #expect(TuningSystem.justIntonation.identifier == "justIntonation")
    }

    @Test("init(identifier:) round-trips justIntonation")
    func identifierJustIntonationRoundTrip() async {
        let original = TuningSystem.justIntonation
        let restored = TuningSystem(identifier: original.identifier)
        #expect(restored == original)
    }

    @Test("init(identifier:) returns nil for unknown identifier")
    func identifierUnknown() async {
        #expect(TuningSystem(identifier: "") == nil)
        #expect(TuningSystem(identifier: "EqualTemperament") == nil)
        #expect(TuningSystem(identifier: "pythagorean") == nil)
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

import Testing
import Foundation
@testable import Peach

@Suite("Interval Tests")
struct IntervalTests {

    // MARK: - Semitone Values (AC #1)

    @Test("prime has 0 semitones")
    func primeSemitones() async {
        #expect(Interval.prime.semitones == 0)
    }

    @Test("minorSecond has 1 semitone")
    func minorSecondSemitones() async {
        #expect(Interval.minorSecond.semitones == 1)
    }

    @Test("majorSecond has 2 semitones")
    func majorSecondSemitones() async {
        #expect(Interval.majorSecond.semitones == 2)
    }

    @Test("minorThird has 3 semitones")
    func minorThirdSemitones() async {
        #expect(Interval.minorThird.semitones == 3)
    }

    @Test("majorThird has 4 semitones")
    func majorThirdSemitones() async {
        #expect(Interval.majorThird.semitones == 4)
    }

    @Test("perfectFourth has 5 semitones")
    func perfectFourthSemitones() async {
        #expect(Interval.perfectFourth.semitones == 5)
    }

    @Test("tritone has 6 semitones")
    func tritoneSemitones() async {
        #expect(Interval.tritone.semitones == 6)
    }

    @Test("perfectFifth has 7 semitones")
    func perfectFifthSemitones() async {
        #expect(Interval.perfectFifth.semitones == 7)
    }

    @Test("minorSixth has 8 semitones")
    func minorSixthSemitones() async {
        #expect(Interval.minorSixth.semitones == 8)
    }

    @Test("majorSixth has 9 semitones")
    func majorSixthSemitones() async {
        #expect(Interval.majorSixth.semitones == 9)
    }

    @Test("minorSeventh has 10 semitones")
    func minorSeventhSemitones() async {
        #expect(Interval.minorSeventh.semitones == 10)
    }

    @Test("majorSeventh has 11 semitones")
    func majorSeventhSemitones() async {
        #expect(Interval.majorSeventh.semitones == 11)
    }

    @Test("octave has 12 semitones")
    func octaveSemitones() async {
        #expect(Interval.octave.semitones == 12)
    }

    // MARK: - CaseIterable (AC #5)

    @Test("CaseIterable gives 13 cases")
    func caseIterableCount() async {
        #expect(Interval.allCases.count == 13)
    }

    // MARK: - Codable (AC #5)

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() async throws {
        let original = Interval.perfectFifth
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Interval.self, from: data)
        #expect(decoded == original)
    }

    @Test("All cases survive Codable round-trip")
    func allCasesCodableRoundTrip() async throws {
        for interval in Interval.allCases {
            let data = try JSONEncoder().encode(interval)
            let decoded = try JSONDecoder().decode(Interval.self, from: data)
            #expect(decoded == interval)
        }
    }

    // MARK: - Hashable (AC #5)

    @Test("Can be used as Set element")
    func hashableSetElement() async {
        let set: Set<Interval> = [.prime, .prime, .octave]
        #expect(set.count == 2)
    }

    @Test("Can be used as Dictionary key")
    func hashableDictionaryKey() async {
        var dict: [Interval: String] = [:]
        dict[.perfectFifth] = "P5"
        dict[.majorThird] = "M3"
        #expect(dict[.perfectFifth] == "P5")
        #expect(dict[.majorThird] == "M3")
    }

    // MARK: - Interval.between (AC #3, #4)

    @Test("Between C4 and G4 returns perfectFifth")
    func betweenKnownInterval() async throws {
        let interval = try Interval.between(MIDINote(60), MIDINote(67))
        #expect(interval == .perfectFifth)
    }

    @Test("Between is distance-independent — reversed order gives same result")
    func betweenDistanceIndependent() async throws {
        let interval = try Interval.between(MIDINote(67), MIDINote(60))
        #expect(interval == .perfectFifth)
    }

    @Test("Between same note returns prime")
    func betweenSameNoteReturnsPrime() async throws {
        let interval = try Interval.between(MIDINote(60), MIDINote(60))
        #expect(interval == .prime)
    }

    @Test("Between notes 12 semitones apart returns octave")
    func betweenOctave() async throws {
        let interval = try Interval.between(MIDINote(60), MIDINote(72))
        #expect(interval == .octave)
    }

    @Test("Between throws for distance exceeding octave")
    func betweenThrowsForLargeDistance() async {
        #expect(throws: AudioError.self) {
            try Interval.between(MIDINote(60), MIDINote(80))
        }
    }

    // MARK: - Name (direction-agnostic)

    @Test("each interval maps to its expected localization key", arguments: [
        (Interval.prime, "Prime"),
        (.minorSecond, "Minor Second"),
        (.majorSecond, "Major Second"),
        (.minorThird, "Minor Third"),
        (.majorThird, "Major Third"),
        (.perfectFourth, "Perfect Fourth"),
        (.tritone, "Tritone"),
        (.perfectFifth, "Perfect Fifth"),
        (.minorSixth, "Minor Sixth"),
        (.majorSixth, "Major Sixth"),
        (.minorSeventh, "Minor Seventh"),
        (.majorSeventh, "Major Seventh"),
        (.octave, "Octave"),
    ])
    func nameLocalizationKey(interval: Interval, expectedKey: String) async {
        #expect(interval.name == String(localized: String.LocalizationValue(expectedKey)))
    }

    @Test("all intervals have non-empty name")
    func allIntervalsHaveName() async {
        for interval in Interval.allCases {
            #expect(!interval.name.isEmpty)
        }
    }

    @Test("each interval has a unique name")
    func uniqueNames() async {
        let names = Set(Interval.allCases.map(\.name))
        #expect(names.count == Interval.allCases.count)
    }

    // MARK: - Abbreviation

    @Test("each interval maps to its standard abbreviation", arguments: [
        (Interval.prime, "P1"),
        (.minorSecond, "m2"),
        (.majorSecond, "M2"),
        (.minorThird, "m3"),
        (.majorThird, "M3"),
        (.perfectFourth, "P4"),
        (.tritone, "d5"),
        (.perfectFifth, "P5"),
        (.minorSixth, "m6"),
        (.majorSixth, "M6"),
        (.minorSeventh, "m7"),
        (.majorSeventh, "M7"),
        (.octave, "P8"),
    ])
    func abbreviation(interval: Interval, expected: String) async {
        #expect(interval.abbreviation == expected)
    }

    @Test("all intervals have unique abbreviations")
    func uniqueAbbreviations() async {
        let abbreviations = Set(Interval.allCases.map(\.abbreviation))
        #expect(abbreviations.count == Interval.allCases.count)
    }
}

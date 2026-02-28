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
}

import Foundation
import Testing
@testable import Peach

@Suite("CompletedRhythmComparison")
struct CompletedRhythmComparisonTests {

    @Test("stored properties are accessible and correct")
    func storedPropertiesAreAccessibleAndCorrect() async {
        let tempo = TempoBPM(120)
        let offset = RhythmOffset(.milliseconds(50))
        let timestamp = Date(timeIntervalSince1970: 1000)

        let result = CompletedRhythmComparison(
            tempo: tempo,
            offset: offset,
            isCorrect: true,
            timestamp: timestamp
        )

        #expect(result.tempo == tempo)
        #expect(result.offset == offset)
        #expect(result.isCorrect == true)
        #expect(result.timestamp == timestamp)
    }

    @Test("isCorrect stores false value")
    func isCorrectStoresFalseValue() async {
        let result = CompletedRhythmComparison(
            tempo: TempoBPM(90),
            offset: RhythmOffset(.milliseconds(-30)),
            isCorrect: false,
            timestamp: Date()
        )

        #expect(result.isCorrect == false)
    }

    @Test("default timestamp is populated")
    func defaultTimestampIsPopulated() async {
        let before = Date()
        let result = CompletedRhythmComparison(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.zero),
            isCorrect: true
        )
        let after = Date()

        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }

    @Test("conforms to Sendable")
    func conformsToSendable() async {
        let result = CompletedRhythmComparison(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(10)),
            isCorrect: true
        )

        let sendable: any Sendable = result
        #expect(sendable is CompletedRhythmComparison)
    }
}

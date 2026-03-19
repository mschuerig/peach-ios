import Foundation
import Testing
@testable import Peach

@Suite("CompletedRhythmMatching")
struct CompletedRhythmMatchingTests {

    @Test("stored properties are accessible and correct")
    func storedPropertiesAreAccessibleAndCorrect() async {
        let tempo = TempoBPM(100)
        let expectedOffset = RhythmOffset(.zero)
        let userOffset = RhythmOffset(.milliseconds(-25))
        let timestamp = Date(timeIntervalSince1970: 2000)

        let result = CompletedRhythmMatching(
            tempo: tempo,
            expectedOffset: expectedOffset,
            userOffset: userOffset,
            timestamp: timestamp
        )

        #expect(result.tempo == tempo)
        #expect(result.expectedOffset == expectedOffset)
        #expect(result.userOffset == userOffset)
        #expect(result.timestamp == timestamp)
    }

    @Test("expectedOffset and userOffset are independent values")
    func expectedAndUserOffsetsAreIndependent() async {
        let expected = RhythmOffset(.zero)
        let user = RhythmOffset(.milliseconds(42))

        let result = CompletedRhythmMatching(
            tempo: TempoBPM(120),
            expectedOffset: expected,
            userOffset: user
        )

        #expect(result.expectedOffset != result.userOffset)
        #expect(result.expectedOffset == expected)
        #expect(result.userOffset == user)
    }

    @Test("default timestamp is populated")
    func defaultTimestampIsPopulated() async {
        let before = Date()
        let result = CompletedRhythmMatching(
            tempo: TempoBPM(120),
            expectedOffset: RhythmOffset(.zero),
            userOffset: RhythmOffset(.milliseconds(10))
        )
        let after = Date()

        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }

    @Test("conforms to Sendable")
    func conformsToSendable() async {
        let result = CompletedRhythmMatching(
            tempo: TempoBPM(120),
            expectedOffset: RhythmOffset(.zero),
            userOffset: RhythmOffset(.milliseconds(5))
        )

        let sendable: any Sendable = result
        #expect(sendable is CompletedRhythmMatching)
    }
}

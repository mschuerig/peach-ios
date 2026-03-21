import Foundation
import Testing
@testable import Peach

@Suite("RhythmOffset")
struct RhythmOffsetTests {

    // MARK: - Direction

    @Test("Negative duration returns early direction")
    func directionNegative() async {
        let offset = RhythmOffset(.milliseconds(-50))
        #expect(offset.direction == .early)
    }

    @Test("Positive duration returns late direction")
    func directionPositive() async {
        let offset = RhythmOffset(.milliseconds(50))
        #expect(offset.direction == .late)
    }

    @Test("Zero duration returns late direction")
    func directionZero() async {
        let offset = RhythmOffset(.zero)
        #expect(offset.direction == .late)
    }

    // MARK: - percentageOfSixteenthNote

    @Test("12.5ms offset at 120 BPM is 10% of sixteenth note")
    func percentageAt120BPM_12_5ms() async {
        let offset = RhythmOffset(.milliseconds(12.5))
        let percentage = offset.percentageOfSixteenthNote(at: TempoBPM(120))
        #expect(percentage == 10.0)
    }

    @Test("125ms offset at 120 BPM is 100% of sixteenth note")
    func percentageAt120BPM_125ms() async {
        let offset = RhythmOffset(.milliseconds(125))
        let percentage = offset.percentageOfSixteenthNote(at: TempoBPM(120))
        #expect(percentage == 100.0)
    }

    @Test("Negative offset uses absolute value for percentage")
    func percentageNegativeOffset() async {
        let offset = RhythmOffset(.milliseconds(-12.5))
        let percentage = offset.percentageOfSixteenthNote(at: TempoBPM(120))
        #expect(percentage == 10.0)
    }
    // MARK: - absoluteMilliseconds

    @Test("absoluteMilliseconds returns positive value for positive offset")
    func absoluteMillisecondsPositive() async {
        let offset = RhythmOffset(.milliseconds(42))
        #expect(offset.absoluteMilliseconds == 42.0)
    }

    @Test("absoluteMilliseconds returns positive value for negative offset")
    func absoluteMillisecondsNegative() async {
        let offset = RhythmOffset(.milliseconds(-42))
        #expect(offset.absoluteMilliseconds == 42.0)
    }

    @Test("absoluteMilliseconds handles durations exceeding one second")
    func absoluteMillisecondsOverOneSecond() async {
        let offset = RhythmOffset(.milliseconds(1200))
        #expect(offset.absoluteMilliseconds == 1200.0)
    }

    @Test("absoluteMilliseconds is zero for zero offset")
    func absoluteMillisecondsZero() async {
        let offset = RhythmOffset(.zero)
        #expect(offset.absoluteMilliseconds == 0.0)
    }

    // MARK: - Codable

    @Test("Round-trip encode and decode preserves duration")
    func codable() async throws {
        let original = RhythmOffset(.milliseconds(42))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RhythmOffset.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Hashable

    @Test("Equal values hash equally")
    func hashable() async {
        let set: Set<RhythmOffset> = [
            RhythmOffset(.milliseconds(50)),
            RhythmOffset(.milliseconds(50)),
            RhythmOffset(.milliseconds(-50))
        ]
        #expect(set.count == 2)
    }
}

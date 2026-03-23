import Foundation
import Testing
@testable import Peach

@Suite("TempoBPM")
struct TempoBPMTests {

    // MARK: - Comparable

    @Test("60 BPM is less than 120 BPM")
    func comparable() async {
        let slow = TempoBPM(60)
        let fast = TempoBPM(120)
        #expect(slow < fast)
    }

    // MARK: - Hashable

    @Test("Equal values hash equally")
    func hashable() async {
        let set: Set<TempoBPM> = [TempoBPM(120), TempoBPM(120), TempoBPM(60)]
        #expect(set.count == 2)
    }

    // MARK: - Codable

    @Test("Round-trip encode and decode preserves value")
    func codable() async throws {
        let original = TempoBPM(120)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TempoBPM.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates TempoBPM")
    func integerLiteral() async {
        let tempo: TempoBPM = 120
        #expect(tempo.value == 120)
    }

    // MARK: - sixteenthNoteDuration

    @Test("120 BPM sixteenth note is 125ms")
    func sixteenthNoteDurationAt120() async {
        let tempo = TempoBPM(120)
        #expect(tempo.sixteenthNoteDuration == Duration.milliseconds(125))
    }

    @Test("60 BPM sixteenth note is 250ms")
    func sixteenthNoteDurationAt60() async {
        let tempo = TempoBPM(60)
        #expect(tempo.sixteenthNoteDuration == Duration.milliseconds(250))
    }

    @Test("240 BPM sixteenth note is 62.5ms")
    func sixteenthNoteDurationAt240() async {
        let tempo = TempoBPM(240)
        #expect(tempo.sixteenthNoteDuration == Duration.seconds(0.0625))
    }

    // MARK: - quarterNoteDuration

    @Test("120 BPM quarter note is 500ms")
    func quarterNoteDurationAt120() async {
        let tempo = TempoBPM(120)
        #expect(tempo.quarterNoteDuration == Duration.milliseconds(500))
    }

    @Test("60 BPM quarter note is 1000ms")
    func quarterNoteDurationAt60() async {
        let tempo = TempoBPM(60)
        #expect(tempo.quarterNoteDuration == Duration.milliseconds(1000))
    }

    @Test("quarter note is four times sixteenth note")
    func quarterIsFourTimesSixteenth() async {
        let tempo = TempoBPM(80)
        #expect(tempo.quarterNoteDuration == tempo.sixteenthNoteDuration * 4)
    }
}

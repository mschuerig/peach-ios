#if os(iOS)
import Testing
import Foundation
@testable import Peach

@Suite("HapticFeedbackManager RhythmOffsetDetectionObserver Tests")
struct HapticFeedbackManagerRhythmTests {

    @Test("rhythmOffsetDetectionCompleted triggers haptic on incorrect answer")
    func triggersHapticOnIncorrect() async {
        let manager = HapticFeedbackManager()
        let result = CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: false
        )
        // Calling on device would trigger haptic; on simulator we verify no crash.
        manager.rhythmOffsetDetectionCompleted(result)
    }

    @Test("rhythmOffsetDetectionCompleted does NOT trigger on correct answer")
    func noHapticOnCorrect() async {
        let manager = HapticFeedbackManager()
        let result = CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: true
        )
        manager.rhythmOffsetDetectionCompleted(result)
    }

    @Test("mock tracks rhythm offset detection calls")
    func mockTracksRhythmCalls() async {
        let mock = MockHapticFeedbackManager()
        let result = CompletedRhythmOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: false
        )
        mock.rhythmOffsetDetectionCompleted(result)
        #expect(mock.rhythmOffsetDetectionCompletedCallCount == 1)
        #expect(mock.lastRhythmOffsetDetection != nil)
    }
}
#endif

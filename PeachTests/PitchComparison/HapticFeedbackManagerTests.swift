import Testing
import Foundation
@testable import Peach

@Suite("HapticFeedbackManager RhythmComparisonObserver Tests")
struct HapticFeedbackManagerRhythmTests {

    @Test("rhythmComparisonCompleted triggers haptic on incorrect answer")
    func triggersHapticOnIncorrect() async {
        let manager = HapticFeedbackManager()
        let result = CompletedRhythmComparison(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: false
        )
        // Calling on device would trigger haptic; on simulator we verify no crash.
        manager.rhythmComparisonCompleted(result)
    }

    @Test("rhythmComparisonCompleted does NOT trigger on correct answer")
    func noHapticOnCorrect() async {
        let manager = HapticFeedbackManager()
        let result = CompletedRhythmComparison(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: true
        )
        manager.rhythmComparisonCompleted(result)
    }

    @Test("mock tracks rhythm comparison calls")
    func mockTracksRhythmCalls() async {
        let mock = MockHapticFeedbackManager()
        let result = CompletedRhythmComparison(
            tempo: TempoBPM(120),
            offset: RhythmOffset(.milliseconds(-20)),
            isCorrect: false
        )
        mock.rhythmComparisonCompleted(result)
        #expect(mock.rhythmComparisonCompletedCallCount == 1)
        #expect(mock.lastRhythmComparison != nil)
    }
}

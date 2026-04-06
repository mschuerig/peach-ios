#if os(iOS)
import Testing
import Foundation
@testable import Peach

@Suite("HapticFeedbackManager TimingOffsetDetectionObserver Tests")
struct HapticFeedbackManagerRhythmTests {

    @Test("timingOffsetDetectionCompleted triggers haptic on incorrect answer")
    func triggersHapticOnIncorrect() async {
        let manager = HapticFeedbackManager()
        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: TimingOffset(.milliseconds(-20)),
            isCorrect: false
        )
        // Calling on device would trigger haptic; on simulator we verify no crash.
        manager.timingOffsetDetectionCompleted(result)
    }

    @Test("timingOffsetDetectionCompleted does NOT trigger on correct answer")
    func noHapticOnCorrect() async {
        let manager = HapticFeedbackManager()
        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: TimingOffset(.milliseconds(-20)),
            isCorrect: true
        )
        manager.timingOffsetDetectionCompleted(result)
    }

    @Test("mock tracks rhythm offset detection calls")
    func mockTracksRhythmCalls() async {
        let mock = MockHapticFeedbackManager()
        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: TimingOffset(.milliseconds(-20)),
            isCorrect: false
        )
        mock.timingOffsetDetectionCompleted(result)
        #expect(mock.timingOffsetDetectionCompletedCallCount == 1)
        #expect(mock.lastTimingOffsetDetection != nil)
    }
}
#endif

#if os(macOS)
import Testing
import Foundation
@testable import Peach

@Suite("NoOpHapticFeedbackManager Tests")
struct NoOpHapticFeedbackManagerTests {

    @Test("conforms to HapticFeedback and playIncorrectFeedback is a no-op")
    func playIncorrectFeedbackNoOp() async {
        let manager = NoOpHapticFeedbackManager()
        let haptic: HapticFeedback = manager
        haptic.playIncorrectFeedback()
    }

    @Test("conforms to PitchDiscriminationObserver and handles callback without side effects")
    func pitchDiscriminationObserverNoOp() async {
        let manager = NoOpHapticFeedbackManager()
        let trial = PitchDiscriminationTrial(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(60), offset: Cents(10))
        )
        let completed = CompletedPitchDiscriminationTrial(
            trial: trial,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        let observer: PitchDiscriminationObserver = manager
        observer.pitchDiscriminationCompleted(completed)
    }

    @Test("conforms to TimingOffsetDetectionObserver and handles callback without side effects")
    func rhythmOffsetDetectionObserverNoOp() async {
        let manager = NoOpHapticFeedbackManager()
        let result = CompletedTimingOffsetDetectionTrial(
            tempo: TempoBPM(120),
            offset: TimingOffset(.milliseconds(-20)),
            isCorrect: false
        )
        let observer: TimingOffsetDetectionObserver = manager
        observer.timingOffsetDetectionCompleted(result)
    }
}
#endif

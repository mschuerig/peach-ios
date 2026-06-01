import Testing
@testable import Peach

@Suite("BeatSequencer Domain Types")
struct BeatSequencerTests {

    // MARK: - RhythmVelocity

    @Test("RhythmVelocity accent is 127 and normal is 100")
    func rhythmVelocityConstants() async {
        #expect(RhythmVelocity.accent == MIDIVelocity(127))
        #expect(RhythmVelocity.normal == MIDIVelocity(100))
    }

    // MARK: - SequencerTiming

    @Test("SequencerTiming is Sendable")
    func sequencerTimingSendable() async {
        let _: any Sendable = SequencerTiming(
            samplePosition: 0,
            samplesPerBeat: 0,
            sampleRate: .standard44100
        )
    }
}

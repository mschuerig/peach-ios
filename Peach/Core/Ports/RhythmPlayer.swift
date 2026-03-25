import Foundation

struct RhythmPattern: Sendable {
    struct Event: Sendable {
        let sampleOffset: Int64
        let midiNote: MIDINote
        let velocity: MIDIVelocity
    }

    let events: [Event]
    let sampleRate: SampleRate
    let totalDuration: Duration
}

protocol RhythmPlayer {
    func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle
    func stopAll() async throws
}

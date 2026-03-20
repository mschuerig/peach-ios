import Foundation

struct RhythmPattern: Sendable {
    struct Event: Sendable {
        let sampleOffset: Int64
        let soundSourceID: any SoundSourceID
        let velocity: MIDIVelocity
    }

    let events: [Event]
    let sampleRate: Double
    let totalDuration: Duration
}

protocol RhythmPlayer {
    func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle
    func stopAll() async throws
}

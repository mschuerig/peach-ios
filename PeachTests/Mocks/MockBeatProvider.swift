@testable import Peach

final class MockBeatProvider: BeatProvider {
    private let beats: [Beat]
    private(set) var nextBeatCallCount = 0
    private var index = 0

    init(beats: [Beat]) {
        precondition(!beats.isEmpty)
        self.beats = beats
    }

    func nextBeat() -> Beat {
        nextBeatCallCount += 1
        let beat = beats[index % beats.count]
        index += 1
        return beat
    }

    func reset() {
        index = 0
        nextBeatCallCount = 0
    }
}

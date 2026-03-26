@testable import Peach

final class MockMIDIInput: MIDIInput {

    // MARK: - MIDIInput Protocol

    nonisolated var events: AsyncStream<MIDIInputEvent> { stream }

    var isConnected: Bool = true

    // MARK: - Test Controls

    private nonisolated(unsafe) var stream: AsyncStream<MIDIInputEvent>
    private nonisolated(unsafe) var continuation: AsyncStream<MIDIInputEvent>.Continuation

    init() {
        var continuation: AsyncStream<MIDIInputEvent>.Continuation!
        stream = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    nonisolated func send(_ event: MIDIInputEvent) {
        continuation.yield(event)
    }

    nonisolated func finish() {
        continuation.finish()
    }

    // MARK: - Reset

    func reset() {
        continuation.finish()
        var newContinuation: AsyncStream<MIDIInputEvent>.Continuation!
        stream = AsyncStream { newContinuation = $0 }
        continuation = newContinuation
        isConnected = true
    }
}

import Foundation
import os
@testable import Peach

final class MockMIDIInput: MIDIInput {

    // MARK: - MIDIInput Protocol

    nonisolated var events: any AsyncSequence<MIDIInputEvent, Never> & Sendable {
        broadcaster.makeStream()
    }

    var isConnected: Bool = true

    // MARK: - Test Controls

    private nonisolated let broadcaster = MockMIDIBroadcaster()

    nonisolated func send(_ event: MIDIInputEvent) {
        broadcaster.broadcast(event)
    }

    nonisolated func finish() {
        broadcaster.finishAll()
    }
}

private final class MockMIDIBroadcaster: Sendable {

    private nonisolated let listeners = OSAllocatedUnfairLock(initialState: [UUID: AsyncStream<MIDIInputEvent>.Continuation]())

    nonisolated func makeStream() -> AsyncStream<MIDIInputEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            listeners.withLock { $0[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.listeners.withLock { _ = $0.removeValue(forKey: id) }
            }
        }
    }

    nonisolated func broadcast(_ event: MIDIInputEvent) {
        let snapshot = listeners.withLock { Array($0.values) }
        for continuation in snapshot {
            continuation.yield(event)
        }
    }

    nonisolated func finishAll() {
        let snapshot = listeners.withLock { active in
            let copy = Array(active.values)
            active.removeAll()
            return copy
        }
        for continuation in snapshot {
            continuation.finish()
        }
    }
}

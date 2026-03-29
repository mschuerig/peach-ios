import Testing
@testable import Peach

@Suite("MockMIDIInput")
struct MockMIDIInputTests {

    private func makeMock() -> MockMIDIInput {
        MockMIDIInput()
    }

    @Test("yields events sent to active listener")
    func yieldsEvents() async {
        let mock = makeMock()
        let noteOn = MIDIInputEvent.noteOn(
            note: MIDINote(60),
            velocity: MIDIVelocity(100),
            timestamp: 1000
        )
        let noteOff = MIDIInputEvent.noteOff(
            note: MIDINote(60),
            velocity: MIDIVelocity(64),
            timestamp: 2000
        )

        Task.detached {
            try? await Task.sleep(for: .milliseconds(20))
            mock.send(noteOn)
            mock.send(noteOff)
            mock.finish()
        }

        var received: [MIDIInputEvent] = []
        for await event in mock.events {
            received.append(event)
        }

        #expect(received == [noteOn, noteOff])
    }

    @Test("finish() terminates the stream")
    func finishTerminatesStream() async {
        let mock = makeMock()

        Task.detached {
            try? await Task.sleep(for: .milliseconds(20))
            mock.finish()
        }

        var count = 0
        for await _ in mock.events {
            count += 1
        }

        #expect(count == 0)
    }

    @Test("isConnected defaults to true")
    func isConnectedDefaultsToTrue() async {
        let mock = makeMock()
        #expect(mock.isConnected == true)
    }

    @Test("isConnected can be set to false")
    func isConnectedMutable() async {
        let mock = makeMock()
        mock.isConnected = false
        #expect(mock.isConnected == false)
    }

    @Test("second iteration after finish receives new events")
    func reIterationAfterFinish() async {
        let mock = makeMock()

        // First iteration
        Task.detached {
            try? await Task.sleep(for: .milliseconds(20))
            mock.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 1000))
            mock.finish()
        }

        var first: [MIDIInputEvent] = []
        for await event in mock.events {
            first.append(event)
        }
        #expect(first.count == 1)

        // Second iteration on same mock — the core bug scenario
        let pitchBend = MIDIInputEvent.pitchBend(
            value: PitchBendValue(8192),
            channel: MIDIChannel(0),
            timestamp: 3000
        )

        Task.detached {
            try? await Task.sleep(for: .milliseconds(20))
            mock.send(pitchBend)
            mock.finish()
        }

        var second: [MIDIInputEvent] = []
        for await event in mock.events {
            second.append(event)
        }

        #expect(second == [pitchBend])
    }

    @Test("concurrent listeners both receive events")
    func concurrentListeners() async {
        let mock = makeMock()
        let event = MIDIInputEvent.noteOn(
            note: MIDINote(72),
            velocity: MIDIVelocity(80),
            timestamp: 5000
        )

        async let stream1Events: [MIDIInputEvent] = {
            var result: [MIDIInputEvent] = []
            for await e in mock.events {
                result.append(e)
            }
            return result
        }()

        async let stream2Events: [MIDIInputEvent] = {
            var result: [MIDIInputEvent] = []
            for await e in mock.events {
                result.append(e)
            }
            return result
        }()

        // Give both streams time to register their for-await loops
        try? await Task.sleep(for: .milliseconds(50))

        mock.send(event)
        mock.finish()

        let results1 = await stream1Events
        let results2 = await stream2Events

        #expect(results1 == [event])
        #expect(results2 == [event])
    }
}

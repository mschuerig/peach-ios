import Testing
@testable import Peach

@Suite("MockMIDIInput")
struct MockMIDIInputTests {

    private func makeMock() -> MockMIDIInput {
        MockMIDIInput()
    }

    @Test("yields events sent via send()")
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

        mock.send(noteOn)
        mock.send(noteOff)
        mock.finish()

        var received: [MIDIInputEvent] = []
        for await event in mock.events {
            received.append(event)
        }

        #expect(received == [noteOn, noteOff])
    }

    @Test("finish() terminates the stream")
    func finishTerminatesStream() async {
        let mock = makeMock()
        mock.finish()

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

    @Test("reset() restores default state and creates fresh stream")
    func resetRestoresState() async {
        let mock = makeMock()
        mock.isConnected = false
        mock.finish()

        mock.reset()

        #expect(mock.isConnected == true)

        // Verify new stream works after reset
        let pitchBend = MIDIInputEvent.pitchBend(
            value: PitchBendValue(8192),
            channel: MIDIChannel(0),
            timestamp: 3000
        )
        mock.send(pitchBend)
        mock.finish()

        var received: [MIDIInputEvent] = []
        for await event in mock.events {
            received.append(event)
        }

        #expect(received == [pitchBend])
    }
}

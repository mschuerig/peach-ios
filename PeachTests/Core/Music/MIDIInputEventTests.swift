import Testing
@testable import Peach

@Suite("MIDIInputEvent Tests")
struct MIDIInputEventTests {

    @Test("Creates noteOn event with valid domain types")
    func noteOn() async {
        let event = MIDIInputEvent.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 123456789)

        if case .noteOn(let note, let velocity, let timestamp) = event {
            #expect(note == MIDINote(60))
            #expect(velocity == MIDIVelocity(100))
            #expect(timestamp == 123456789)
        } else {
            Issue.record("Expected noteOn case")
        }
    }

    @Test("Creates noteOff event with valid domain types")
    func noteOff() async {
        let event = MIDIInputEvent.noteOff(note: MIDINote(60), velocity: MIDIVelocity(64), timestamp: 987654321)

        if case .noteOff(let note, let velocity, let timestamp) = event {
            #expect(note == MIDINote(60))
            #expect(velocity == MIDIVelocity(64))
            #expect(timestamp == 987654321)
        } else {
            Issue.record("Expected noteOff case")
        }
    }

    @Test("Creates pitchBend event with valid domain types")
    func pitchBend() async {
        let event = MIDIInputEvent.pitchBend(value: PitchBendValue.center, channel: MIDIChannel(0), timestamp: 555555555)

        if case .pitchBend(let value, let channel, let timestamp) = event {
            #expect(value == PitchBendValue.center)
            #expect(channel == MIDIChannel(0))
            #expect(timestamp == 555555555)
        } else {
            Issue.record("Expected pitchBend case")
        }
    }

    @Test("Events with same values are equal")
    func equality() async {
        let event1 = MIDIInputEvent.noteOn(note: MIDINote(60), velocity: MIDIVelocity(127), timestamp: 100)
        let event2 = MIDIInputEvent.noteOn(note: MIDINote(60), velocity: MIDIVelocity(127), timestamp: 100)

        #expect(event1 == event2)
    }

    @Test("Events with different cases are not equal")
    func inequality() async {
        let noteOn = MIDIInputEvent.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 100)
        let noteOff = MIDIInputEvent.noteOff(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 100)

        #expect(noteOn != noteOff)
    }

    @Test("Sendable conformance compiles for concurrent use")
    func sendable() async {
        let event = MIDIInputEvent.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 100)

        let sendableValue: any Sendable = event
        #expect(sendableValue is MIDIInputEvent)
    }
}

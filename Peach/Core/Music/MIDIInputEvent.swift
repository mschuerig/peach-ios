nonisolated enum MIDIInputEvent: Hashable, Sendable {
    case noteOn(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)
    case noteOff(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)
    case pitchBend(value: PitchBendValue, channel: MIDIChannel, timestamp: UInt64)
}

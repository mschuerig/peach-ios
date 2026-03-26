nonisolated protocol MIDIInput {
    var events: AsyncStream<MIDIInputEvent> { get }
    var isConnected: Bool { get }
}

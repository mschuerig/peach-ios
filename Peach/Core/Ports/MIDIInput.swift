nonisolated protocol MIDIInput {
    var events: any AsyncSequence<MIDIInputEvent, Never> & Sendable { get }
    var isConnected: Bool { get }
}

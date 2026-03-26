nonisolated struct MIDIChannel: Hashable, Sendable {
    static let validRange: ClosedRange<UInt8> = 0...15

    let rawValue: UInt8

    init(_ rawValue: UInt8) {
        precondition(Self.validRange.contains(rawValue), "MIDI channel must be 0-15, got \(rawValue)")
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension MIDIChannel: ExpressibleByIntegerLiteral {
    init(integerLiteral value: UInt8) {
        self.init(value)
    }
}

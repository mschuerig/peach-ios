import Foundation

struct MIDIVelocity: Hashable, Sendable {
    nonisolated(unsafe) static let validRange: ClosedRange<UInt8> = 1...127

    let rawValue: UInt8

    nonisolated init(_ rawValue: UInt8) {
        precondition(Self.validRange.contains(rawValue), "MIDI velocity must be 1-127, got \(rawValue)")
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension MIDIVelocity: ExpressibleByIntegerLiteral {
    nonisolated init(integerLiteral value: UInt8) {
        self.init(value)
    }
}

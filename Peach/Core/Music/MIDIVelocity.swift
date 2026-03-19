import Foundation

struct MIDIVelocity: Hashable, Comparable, Sendable {
    static let validRange: ClosedRange<UInt8> = 1...127

    let rawValue: UInt8

    init(_ rawValue: UInt8) {
        precondition(Self.validRange.contains(rawValue), "MIDI velocity must be 1-127, got \(rawValue)")
        self.rawValue = rawValue
    }

    // MARK: - Comparable

    static func < (lhs: MIDIVelocity, rhs: MIDIVelocity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension MIDIVelocity: ExpressibleByIntegerLiteral {
    init(integerLiteral value: UInt8) {
        self.init(value)
    }
}

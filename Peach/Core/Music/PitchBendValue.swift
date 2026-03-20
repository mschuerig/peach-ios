nonisolated struct PitchBendValue: Hashable, Comparable, Sendable {
    static let validRange: ClosedRange<UInt16> = 0...16383
    static let center = PitchBendValue(8192)

    let rawValue: UInt16

    init(_ rawValue: UInt16) {
        precondition(Self.validRange.contains(rawValue), "Pitch bend must be 0-16383, got \(rawValue)")
        self.rawValue = rawValue
    }

    // MARK: - Comparable

    static func < (lhs: PitchBendValue, rhs: PitchBendValue) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension PitchBendValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: UInt16) {
        self.init(value)
    }
}

nonisolated struct PitchBendValue: Hashable, Comparable, Sendable {
    static let validRange: ClosedRange<UInt16> = 0...16383
    static let center = PitchBendValue(8192)

    let rawValue: UInt16

    init(_ rawValue: UInt16) {
        precondition(Self.validRange.contains(rawValue), "Pitch bend must be 0-16383, got \(rawValue)")
        self.rawValue = rawValue
    }

    init(clamping rawValue: Int) {
        let range = Int(Self.validRange.lowerBound)...Int(Self.validRange.upperBound)
        self.rawValue = UInt16(rawValue.clamped(to: range))
    }

    // MARK: - Slider Mapping

    /// Maps the 14-bit pitch bend range [0, 16383] linearly to [-1.0, +1.0].
    var normalizedSliderValue: Double {
        Double(rawValue) / 8191.5 - 1.0
    }

    /// Whether the value is within the neutral dead zone (center +/- 256).
    var isInNeutralZone: Bool {
        abs(Int(rawValue) - 8192) <= 256
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

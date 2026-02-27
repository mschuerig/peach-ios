import Foundation

struct UnitInterval: Hashable, Comparable, Sendable {
    static let validRange: ClosedRange<Double> = 0.0...1.0

    let rawValue: Double

    init(_ rawValue: Double) {
        self.rawValue = rawValue.clamped(to: Self.validRange)
    }

    // MARK: - Comparable

    static func < (lhs: UnitInterval, rhs: UnitInterval) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByFloatLiteral

extension UnitInterval: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension UnitInterval: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(Double(value))
    }
}

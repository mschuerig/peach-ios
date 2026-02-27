import Foundation

struct NoteDuration: Hashable, Comparable, Sendable {
    static let validRange: ClosedRange<Double> = 0.3...3.0

    let rawValue: Double

    init(_ rawValue: Double) {
        self.rawValue = rawValue.clamped(to: Self.validRange)
    }

    // MARK: - Comparable

    static func < (lhs: NoteDuration, rhs: NoteDuration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByFloatLiteral

extension NoteDuration: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension NoteDuration: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(Double(value))
    }
}

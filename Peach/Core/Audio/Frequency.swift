import Foundation

struct Frequency: Hashable, Comparable, Sendable {
    let rawValue: Double

    nonisolated init(_ rawValue: Double) {
        precondition(rawValue > 0, "Frequency must be positive, got \(rawValue)")
        self.rawValue = rawValue
    }

    // MARK: - Comparable

    nonisolated static func < (lhs: Frequency, rhs: Frequency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByFloatLiteral

extension Frequency: ExpressibleByFloatLiteral {
    nonisolated init(floatLiteral value: Double) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Frequency: ExpressibleByIntegerLiteral {
    nonisolated init(integerLiteral value: Int) {
        self.init(Double(value))
    }
}

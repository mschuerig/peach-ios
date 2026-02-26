import Foundation

struct Cents: Hashable, Comparable, Sendable {
    let rawValue: Double

    var magnitude: Double {
        abs(rawValue)
    }

    nonisolated init(_ rawValue: Double) {
        self.rawValue = rawValue
    }

    // MARK: - Comparable

    nonisolated static func < (lhs: Cents, rhs: Cents) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByFloatLiteral

extension Cents: ExpressibleByFloatLiteral {
    nonisolated init(floatLiteral value: Double) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Cents: ExpressibleByIntegerLiteral {
    nonisolated init(integerLiteral value: Int) {
        self.init(Double(value))
    }
}

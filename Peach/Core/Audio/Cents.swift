import Foundation

struct Cents: Hashable, Comparable, Sendable {
    let rawValue: Double

    var magnitude: Double {
        abs(rawValue)
    }

    init(_ rawValue: Double) {
        self.rawValue = rawValue
    }

    // MARK: - Comparable

    static func < (lhs: Cents, rhs: Cents) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByFloatLiteral

extension Cents: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Cents: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(Double(value))
    }
}

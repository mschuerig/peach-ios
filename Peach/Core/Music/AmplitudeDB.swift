import Foundation

nonisolated struct AmplitudeDB: Hashable, Comparable, Sendable {
    static let validRange: ClosedRange<Double> = -90.0...12.0

    let rawValue: Double

    init(_ rawValue: Double) {
        self.rawValue = rawValue.clamped(to: Self.validRange)
    }

    // MARK: - Comparable

    static func < (lhs: AmplitudeDB, rhs: AmplitudeDB) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - ExpressibleByFloatLiteral

extension AmplitudeDB: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) {
        self.init(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension AmplitudeDB: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(Double(value))
    }
}

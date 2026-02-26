import Foundation

struct AmplitudeDB: Hashable, Comparable, Sendable {
    static let validRange: ClosedRange<Float> = -90.0...12.0

    let rawValue: Float

    init(_ rawValue: Float) {
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
        self.init(Float(value))
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension AmplitudeDB: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(Float(value))
    }
}

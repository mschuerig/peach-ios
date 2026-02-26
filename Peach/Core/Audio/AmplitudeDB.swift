import Foundation

struct AmplitudeDB: Hashable, Sendable {
    nonisolated(unsafe) static let validRange: ClosedRange<Float> = -90.0...12.0

    let rawValue: Float

    nonisolated init(_ rawValue: Float) {
        self.rawValue = rawValue.clamped(to: Self.validRange)
    }
}

// MARK: - ExpressibleByFloatLiteral

extension AmplitudeDB: ExpressibleByFloatLiteral {
    nonisolated init(floatLiteral value: Double) {
        self.init(Float(value))
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension AmplitudeDB: ExpressibleByIntegerLiteral {
    nonisolated init(integerLiteral value: Int) {
        self.init(Float(value))
    }
}

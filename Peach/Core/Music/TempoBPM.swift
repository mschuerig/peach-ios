import Foundation

/// A tempo measured in beats per minute (BPM).
///
/// Used throughout rhythm training to derive note durations and configure
/// session parameters. Value must be positive.
struct TempoBPM: Hashable, Sendable, Codable, Comparable {
    let value: Int

    var sixteenthNoteDuration: Duration {
        .seconds(60.0 / (Double(value) * 4.0))
    }

    var quarterNoteDuration: Duration {
        .seconds(60.0 / Double(value))
    }

    nonisolated init(_ value: Int) {
        precondition(value > 0, "TempoBPM must be positive, got \(value)")
        self.value = value
    }

    // MARK: - Comparable

    static func < (lhs: TempoBPM, rhs: TempoBPM) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension TempoBPM: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(value)
    }
}

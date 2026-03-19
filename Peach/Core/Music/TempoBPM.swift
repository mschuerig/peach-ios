import Foundation

/// A tempo measured in beats per minute (BPM).
///
/// Used throughout rhythm training to derive note durations and configure
/// session parameters. Validation is enforced at the settings/session level,
/// not at construction time.
struct TempoBPM: Hashable, Sendable, Codable, Comparable {
    let value: Int

    var sixteenthNoteDuration: Duration {
        .seconds(60.0 / (Double(value) * 4.0))
    }

    nonisolated init(_ value: Int) {
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

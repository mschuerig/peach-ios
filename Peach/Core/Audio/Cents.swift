import Foundation

/// A microtonal offset measured in cents (1/1200 of an octave).
///
/// Cents is a universal unit — not specific to 12-TET. It appears in
/// `DetunedMIDINote` (microtonal offset), `Comparison` (cent difference
/// between notes), and `TrainingSettings` (difficulty bounds).
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

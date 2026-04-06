import Foundation

/// A microtonal offset measured in cents (1/1200 of an octave).
///
/// Cents is a universal unit — not specific to 12-TET. It appears in
/// `DetunedMIDINote` (microtonal offset), `Comparison` (cent difference
/// between notes), and `TrainingSettings` (difficulty bounds).
nonisolated struct Cents: Hashable, Comparable, Sendable {
    static let perSemitone = Cents(100.0)
    static let perOctave = Cents(1200.0)

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

// MARK: - Arithmetic

nonisolated extension Cents {
    static func + (lhs: Cents, rhs: Cents) -> Cents {
        Cents(lhs.rawValue + rhs.rawValue)
    }

    static func - (lhs: Cents, rhs: Cents) -> Cents {
        Cents(lhs.rawValue - rhs.rawValue)
    }

    static prefix func - (value: Cents) -> Cents {
        Cents(-value.rawValue)
    }

    static func * (lhs: Double, rhs: Cents) -> Cents {
        Cents(lhs * rhs.rawValue)
    }

    static func * (lhs: Cents, rhs: Double) -> Cents {
        Cents(lhs.rawValue * rhs)
    }

    static func / (lhs: Cents, rhs: Cents) -> Double {
        lhs.rawValue / rhs.rawValue
    }

    static func / (lhs: Cents, rhs: Double) -> Cents {
        Cents(lhs.rawValue / rhs)
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

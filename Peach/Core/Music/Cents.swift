import Foundation

/// A microtonal offset measured in cents (1/1200 of an octave).
///
/// Cents is a universal unit — not specific to 12-TET. It appears in
/// `DetunedMIDINote` (microtonal offset), `Comparison` (cent difference
/// between notes), and `TrainingSettings` (difficulty bounds).
// WALKTHROUGH: Inconsistent isolation — MIDINote and MIDIVelocity are `nonisolated struct`,
// but Cents (and Frequency, AmplitudeDB, NoteDuration) only have nonisolated on individual members.
// All pure value types in Core/Music/ should probably be `nonisolated struct` for consistency.
struct Cents: Hashable, Comparable, Sendable {
    /// The number of cents in one octave (1200 = 12 semitones x 100 cents).
    static let perOctave: Double = 1200.0

    let rawValue: Double

    var magnitude: Double {
        abs(rawValue)
    }

    nonisolated init(_ rawValue: Double) {
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

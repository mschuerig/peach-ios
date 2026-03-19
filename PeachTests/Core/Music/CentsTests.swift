import Testing
@testable import Peach

@Suite("Cents Tests")
struct CentsTests {

    // MARK: - Construction

    @Test("Stores positive value")
    func positiveValue() async {
        let cents = Cents(100.0)
        #expect(cents.rawValue == 100.0)
    }

    @Test("Stores negative value (signed)")
    func negativeValue() async {
        let cents = Cents(-50.0)
        #expect(cents.rawValue == -50.0)
    }

    @Test("Stores zero")
    func zeroValue() async {
        let cents = Cents(0.0)
        #expect(cents.rawValue == 0.0)
    }

    // MARK: - Magnitude

    @Test("Magnitude returns absolute value for positive")
    func magnitudePositive() async {
        #expect(Cents(100.0).magnitude == 100.0)
    }

    @Test("Magnitude returns absolute value for negative")
    func magnitudeNegative() async {
        #expect(Cents(-50.0).magnitude == 50.0)
    }

    @Test("Magnitude of zero is zero")
    func magnitudeZero() async {
        #expect(Cents(0.0).magnitude == 0.0)
    }

    // MARK: - ExpressibleByFloatLiteral

    @Test("Float literal creates Cents")
    func floatLiteral() async {
        let cents: Cents = 42.5
        #expect(cents.rawValue == 42.5)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates Cents")
    func integerLiteral() async {
        let cents: Cents = 100
        #expect(cents.rawValue == 100.0)
    }

    // MARK: - Comparable

    @Test("Comparison uses signed raw values")
    func comparable() async {
        #expect(Cents(-50.0) < Cents(50.0))
        #expect(Cents(50.0) == Cents(50.0))
        #expect(Cents(100.0) > Cents(50.0))
    }

    // MARK: - Hashable

    @Test("Equal values have same hash")
    func hashable() async {
        let set: Set<Cents> = [Cents(50.0), Cents(50.0), Cents(100.0)]
        #expect(set.count == 2)
    }
}

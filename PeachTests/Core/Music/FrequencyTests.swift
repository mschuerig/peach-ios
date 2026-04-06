import Testing
@testable import Peach

@Suite("Frequency Tests")
struct FrequencyTests {

    // MARK: - Valid Construction

    @Test("Stores positive value")
    func positiveValue() async {
        let freq = Frequency(440.0)
        #expect(freq.rawValue == 440.0)
    }

    @Test("Stores small positive value")
    func smallPositiveValue() async {
        let freq = Frequency(0.001)
        #expect(freq.rawValue == 0.001)
    }

    // MARK: - ExpressibleByFloatLiteral

    @Test("Float literal creates Frequency")
    func floatLiteral() async {
        let freq: Frequency = 440.0
        #expect(freq.rawValue == 440.0)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates Frequency")
    func integerLiteral() async {
        let freq: Frequency = 440
        #expect(freq.rawValue == 440.0)
    }

    // MARK: - Comparable

    @Test("Lower frequency is less than higher")
    func comparable() async {
        #expect(Frequency(220.0) < Frequency(440.0))
        #expect(Frequency(440.0) == Frequency(440.0))
        #expect(Frequency(880.0) > Frequency(440.0))
    }

    // MARK: - Arithmetic Operators

    @Test("scalar multiplication: Frequency * Double")
    func scalarMultiplyRight() async {
        let result = Frequency(440.0) * 2.0
        #expect(result.rawValue == 880.0)
    }

    @Test("scalar multiplication: Double * Frequency")
    func scalarMultiplyLeft() async {
        let result = 0.5 * Frequency(440.0)
        #expect(result.rawValue == 220.0)
    }

    @Test("ratio division: Frequency / Frequency returns Double")
    func ratioDivision() async {
        let result: Double = Frequency(880.0) / Frequency(440.0)
        #expect(result == 2.0)
    }

    @Test("ratio of concert440 to itself is 1.0")
    func ratioDivisionSelf() async {
        let result: Double = Frequency.concert440 / Frequency.concert440
        #expect(result == 1.0)
    }

    // MARK: - Hashable

    @Test("Equal frequencies have same hash")
    func hashable() async {
        let set: Set<Frequency> = [Frequency(440.0), Frequency(440.0), Frequency(880.0)]
        #expect(set.count == 2)
    }
}

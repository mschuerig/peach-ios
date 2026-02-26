import Testing
@testable import Peach

@Suite("Frequency Tests")
struct FrequencyTests {

    // MARK: - Valid Construction

    @Test("Stores positive value")
    func positiveValue() {
        let freq = Frequency(440.0)
        #expect(freq.rawValue == 440.0)
    }

    @Test("Stores small positive value")
    func smallPositiveValue() {
        let freq = Frequency(0.001)
        #expect(freq.rawValue == 0.001)
    }

    // MARK: - ExpressibleByFloatLiteral

    @Test("Float literal creates Frequency")
    func floatLiteral() {
        let freq: Frequency = 440.0
        #expect(freq.rawValue == 440.0)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates Frequency")
    func integerLiteral() {
        let freq: Frequency = 440
        #expect(freq.rawValue == 440.0)
    }

    // MARK: - Comparable

    @Test("Lower frequency is less than higher")
    func comparable() {
        #expect(Frequency(220.0) < Frequency(440.0))
        #expect(Frequency(440.0) == Frequency(440.0))
        #expect(Frequency(880.0) > Frequency(440.0))
    }

    // MARK: - Hashable

    @Test("Equal frequencies have same hash")
    func hashable() {
        let set: Set<Frequency> = [Frequency(440.0), Frequency(440.0), Frequency(880.0)]
        #expect(set.count == 2)
    }
}

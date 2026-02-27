import Testing
@testable import Peach

@Suite("UnitInterval Tests")
struct UnitIntervalTests {

    // MARK: - Valid Construction

    @Test("Stores value within range")
    func withinRange() async {
        let value = UnitInterval(0.5)
        #expect(value.rawValue == 0.5)
    }

    @Test("Stores boundary values")
    func boundaryValues() async {
        let low = UnitInterval(0.0)
        let high = UnitInterval(1.0)

        #expect(low.rawValue == 0.0)
        #expect(high.rawValue == 1.0)
    }

    // MARK: - Clamping

    @Test("Clamps value above maximum to 1.0")
    func clampsAboveMax() async {
        let value = UnitInterval(1.5)
        #expect(value.rawValue == 1.0)
    }

    @Test("Clamps value below minimum to 0.0")
    func clampsBelowMin() async {
        let value = UnitInterval(-0.5)
        #expect(value.rawValue == 0.0)
    }

    // MARK: - ExpressibleByFloatLiteral

    @Test("Float literal creates UnitInterval")
    func floatLiteral() async {
        let value: UnitInterval = 0.75
        #expect(value.rawValue == 0.75)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates UnitInterval")
    func integerLiteral() async {
        let value: UnitInterval = 0
        #expect(value.rawValue == 0.0)
    }

    // MARK: - Comparable

    @Test("Lower value is less than higher")
    func comparable() async {
        #expect(UnitInterval(0.2) < UnitInterval(0.8))
        #expect(UnitInterval(0.5) == UnitInterval(0.5))
        #expect(UnitInterval(0.9) > UnitInterval(0.1))
    }

    // MARK: - Hashable

    @Test("Equal values have same hash")
    func hashable() async {
        let set: Set<UnitInterval> = [UnitInterval(0.5), UnitInterval(0.5), UnitInterval(0.3)]
        #expect(set.count == 2)
    }
}

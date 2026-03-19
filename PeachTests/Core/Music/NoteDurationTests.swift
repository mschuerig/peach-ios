import Testing
@testable import Peach

@Suite("NoteDuration Tests")
struct NoteDurationTests {

    // MARK: - Valid Construction

    @Test("Stores value within range")
    func withinRange() async {
        let duration = NoteDuration(1.0)
        #expect(duration.rawValue == 1.0)
    }

    @Test("Stores boundary values")
    func boundaryValues() async {
        let low = NoteDuration(0.3)
        let high = NoteDuration(3.0)

        #expect(low.rawValue == 0.3)
        #expect(high.rawValue == 3.0)
    }

    // MARK: - Clamping

    @Test("Clamps value above maximum to 3.0")
    func clampsAboveMax() async {
        let duration = NoteDuration(5.0)
        #expect(duration.rawValue == 3.0)
    }

    @Test("Clamps value below minimum to 0.3")
    func clampsBelowMin() async {
        let duration = NoteDuration(0.1)
        #expect(duration.rawValue == 0.3)
    }

    // MARK: - ExpressibleByFloatLiteral

    @Test("Float literal creates NoteDuration")
    func floatLiteral() async {
        let duration: NoteDuration = 1.5
        #expect(duration.rawValue == 1.5)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates NoteDuration")
    func integerLiteral() async {
        let duration: NoteDuration = 2
        #expect(duration.rawValue == 2.0)
    }

    // MARK: - Comparable

    @Test("Shorter duration is less than longer")
    func comparable() async {
        #expect(NoteDuration(0.5) < NoteDuration(2.0))
        #expect(NoteDuration(1.0) == NoteDuration(1.0))
        #expect(NoteDuration(2.5) > NoteDuration(0.5))
    }

    // MARK: - Hashable

    @Test("Equal durations have same hash")
    func hashable() async {
        let set: Set<NoteDuration> = [NoteDuration(1.0), NoteDuration(1.0), NoteDuration(2.0)]
        #expect(set.count == 2)
    }
}

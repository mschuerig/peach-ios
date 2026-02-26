import Testing
@testable import Peach

@Suite("AmplitudeDB Tests")
struct AmplitudeDBTests {

    // MARK: - Valid Construction

    @Test("Stores value within range")
    func withinRange() {
        let amp = AmplitudeDB(0.0)
        #expect(amp.rawValue == 0.0)
    }

    @Test("Stores boundary values")
    func boundaryValues() {
        let low = AmplitudeDB(-90.0)
        let high = AmplitudeDB(12.0)

        #expect(low.rawValue == -90.0)
        #expect(high.rawValue == 12.0)
    }

    // MARK: - Clamping

    @Test("Clamps value above maximum to 12.0")
    func clampsAboveMax() {
        let amp = AmplitudeDB(20.0)
        #expect(amp.rawValue == 12.0)
    }

    @Test("Clamps value below minimum to -90.0")
    func clampsBelowMin() {
        let amp = AmplitudeDB(-100.0)
        #expect(amp.rawValue == -90.0)
    }

    // MARK: - ExpressibleByFloatLiteral

    @Test("Float literal creates AmplitudeDB")
    func floatLiteral() {
        let amp: AmplitudeDB = -3.0
        #expect(amp.rawValue == -3.0)
    }

    // MARK: - ExpressibleByIntegerLiteral

    @Test("Integer literal creates AmplitudeDB")
    func integerLiteral() {
        let amp: AmplitudeDB = 0
        #expect(amp.rawValue == 0.0)
    }

    // MARK: - Hashable

    @Test("Equal amplitudes have same hash")
    func hashable() {
        let set: Set<AmplitudeDB> = [AmplitudeDB(0.0), AmplitudeDB(0.0), AmplitudeDB(-3.0)]
        #expect(set.count == 2)
    }
}

import Testing
import Foundation
@testable import Peach

@Suite("WelfordAccumulator Tests")
struct WelfordAccumulatorTests {

    // MARK: - WelfordMeasurement Protocol

    @Test("Cents conforms to WelfordMeasurement via rawValue")
    func centsWelfordMeasurementConformance() async {
        let cents = Cents(42.5)
        #expect(cents.statisticalValue == 42.5)

        let roundTripped = Cents(statisticalValue: 42.5)
        #expect(roundTripped.rawValue == 42.5)
    }

    // MARK: - Generic Accumulator with Cents

    @Test("empty accumulator has zero count and nil typed accessors")
    func emptyAccumulator() async {
        let acc = WelfordAccumulator<Cents>()
        #expect(acc.count == 0)
        #expect(acc.mean == 0.0)
        #expect(acc.typedMean == nil)
        #expect(acc.typedStdDev == nil)
        #expect(acc.populationStdDev == nil)
    }

    @Test("single update sets mean and typed mean")
    func singleUpdate() async {
        var acc = WelfordAccumulator<Cents>()
        acc.update(Cents(10.0))

        #expect(acc.count == 1)
        #expect(acc.mean == 10.0)
        #expect(acc.typedMean == Cents(10.0))
        #expect(acc.typedStdDev == nil) // need >= 2 for sample stddev
    }

    @Test("multiple updates compute correct running mean")
    func multipleUpdates() async {
        var acc = WelfordAccumulator<Cents>()
        acc.update(Cents(10.0))
        acc.update(Cents(20.0))
        acc.update(Cents(30.0))

        #expect(acc.count == 3)
        #expect(abs(acc.mean - 20.0) < 0.01)
        #expect(acc.typedMean == Cents(20.0))
    }

    @Test("population stddev matches expected value")
    func populationStdDev() async throws {
        var acc = WelfordAccumulator<Cents>()
        acc.update(Cents(10.0))
        acc.update(Cents(20.0))
        acc.update(Cents(30.0))

        // Population stddev of [10, 20, 30] = sqrt(200/3) ≈ 8.165
        let stddev = try #require(acc.populationStdDev)
        #expect(abs(stddev - 8.165) < 0.01)
    }

    @Test("typed stddev returns Cents value")
    func typedStdDev() async throws {
        var acc = WelfordAccumulator<Cents>()
        acc.update(Cents(10.0))
        acc.update(Cents(20.0))
        acc.update(Cents(30.0))

        // Sample stddev of [10, 20, 30] = sqrt(200/2) = 10.0
        let typedStdDev = try #require(acc.typedStdDev)
        #expect(abs(typedStdDev.rawValue - 10.0) < 0.01)
    }

    @Test("raw mean accessor preserved for internal math")
    func rawMeanAccessor() async {
        var acc = WelfordAccumulator<Cents>()
        acc.update(Cents(15.0))
        acc.update(Cents(25.0))

        #expect(acc.mean == 20.0)
    }
}

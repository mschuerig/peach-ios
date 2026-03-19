import Foundation

/// Bridges domain types to `Double` for Welford's statistical algorithm.
protocol WelfordMeasurement: Sendable {
    var statisticalValue: Double { get }
    init(statisticalValue: Double)
}

// MARK: - Cents + WelfordMeasurement

extension Cents: WelfordMeasurement {
    var statisticalValue: Double { rawValue }

    init(statisticalValue: Double) {
        self.init(statisticalValue)
    }
}

// MARK: - WelfordAccumulator

/// Welford's online algorithm for computing running mean and variance in a single pass.
struct WelfordAccumulator<Measurement: WelfordMeasurement> {
    private(set) var count: Int = 0
    private(set) var mean: Double = 0.0
    private var m2: Double = 0.0

    mutating func update(_ value: Measurement) {
        count += 1
        let delta = value.statisticalValue - mean
        mean += delta / Double(count)
        let delta2 = value.statisticalValue - mean
        m2 += delta * delta2
    }

    var typedMean: Measurement? {
        count > 0 ? Measurement(statisticalValue: mean) : nil
    }

    var typedStdDev: Measurement? {
        guard count >= 2 else { return nil }
        return Measurement(statisticalValue: sqrt(m2 / Double(count - 1)))
    }

    var populationStdDev: Double? {
        count >= 2 ? sqrt(m2 / Double(count)) : nil
    }
}

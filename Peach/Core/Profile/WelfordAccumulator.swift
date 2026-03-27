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

// MARK: - RhythmOffset + WelfordMeasurement

extension RhythmOffset: WelfordMeasurement {
    var statisticalValue: Double {
        duration / .milliseconds(1)
    }

    init(statisticalValue: Double) {
        self.init(.milliseconds(statisticalValue))
    }
}

// MARK: - WelfordAccumulator

/// Welford's online algorithm for computing running mean and variance in a single pass.
struct WelfordAccumulator: Sendable {
    private(set) var count: Int = 0
    private(set) var mean: Double = 0.0
    private var m2: Double = 0.0

    mutating func update(_ value: Double) {
        count += 1
        let delta = value - mean
        mean += delta / Double(count)
        let delta2 = value - mean
        m2 += delta * delta2
    }

    var sampleStdDev: Double? {
        count >= 2 ? sqrt(m2 / Double(count - 1)) : nil
    }

    var populationStdDev: Double? {
        count >= 2 ? sqrt(m2 / Double(count)) : nil
    }
}

extension WelfordAccumulator {
    init<S: Sequence<Double>>(_ values: S) {
        self.init()
        for value in values {
            update(value)
        }
    }
}

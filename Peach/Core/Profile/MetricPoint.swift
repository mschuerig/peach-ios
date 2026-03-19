import Foundation

/// A single timestamped measurement from a training exercise.
struct MetricPoint<Measurement: WelfordMeasurement> {
    let timestamp: Date
    let value: Measurement

    var statisticalValue: Double { value.statisticalValue }
}

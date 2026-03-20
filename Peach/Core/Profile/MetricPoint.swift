import Foundation

/// A single timestamped measurement from a training exercise.
struct MetricPoint: Sendable {
    let timestamp: Date
    let value: Double
}

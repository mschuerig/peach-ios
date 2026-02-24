import Foundation
import SwiftUI

struct TimelineDataPoint {
    let timestamp: Date
    let centDifference: Double
    let isCorrect: Bool
    let note1: Int
}

struct AggregatedDataPoint {
    let periodStart: Date
    let meanThreshold: Double
    let comparisonCount: Int
    let correctCount: Int
}

@Observable
@MainActor
final class ThresholdTimeline {

    private(set) var dataPoints: [TimelineDataPoint] = []
    private let windowSize: Int
    private let aggregationComponent: Calendar.Component

    init(records: [ComparisonRecord] = [], windowSize: Int = 20, aggregationComponent: Calendar.Component = .day) {
        self.windowSize = windowSize
        self.aggregationComponent = aggregationComponent
        for record in records {
            dataPoints.append(TimelineDataPoint(
                timestamp: record.timestamp,
                centDifference: abs(record.note2CentOffset),
                isCorrect: record.isCorrect,
                note1: record.note1
            ))
        }
    }

    var aggregatedPoints: [AggregatedDataPoint] {
        guard !dataPoints.isEmpty else { return [] }

        let calendar = Calendar.current
        var groups: [Date: [TimelineDataPoint]] = [:]

        for point in dataPoints {
            guard let interval = calendar.dateInterval(of: aggregationComponent, for: point.timestamp) else { continue }
            groups[interval.start, default: []].append(point)
        }

        return groups.sorted(by: { $0.key < $1.key }).map { periodStart, points in
            let mean = points.map(\.centDifference).reduce(0.0, +) / Double(points.count)
            let correctCount = points.filter(\.isCorrect).count
            return AggregatedDataPoint(
                periodStart: periodStart,
                meanThreshold: mean,
                comparisonCount: points.count,
                correctCount: correctCount
            )
        }
    }

    func rollingMean() -> [(date: Date, value: Double)] {
        let points = aggregatedPoints
        guard !points.isEmpty else { return [] }

        var result: [(date: Date, value: Double)] = []
        for i in 0..<points.count {
            let windowStart = max(0, i - windowSize + 1)
            let window = points[windowStart...i]
            let mean = window.map(\.meanThreshold).reduce(0.0, +) / Double(window.count)
            result.append((date: points[i].periodStart, value: mean))
        }
        return result
    }

    func rollingStdDev() -> [(date: Date, value: Double)] {
        let points = aggregatedPoints
        guard !points.isEmpty else { return [] }

        var result: [(date: Date, value: Double)] = []
        for i in 0..<points.count {
            let windowStart = max(0, i - windowSize + 1)
            let window = Array(points[windowStart...i])
            let count = window.count

            if count < 2 {
                result.append((date: points[i].periodStart, value: 0.0))
                continue
            }

            let values = window.map(\.meanThreshold)
            let mean = values.reduce(0.0, +) / Double(count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(count - 1)
            result.append((date: points[i].periodStart, value: sqrt(variance)))
        }
        return result
    }

    func reset() {
        dataPoints = []
    }
}

// MARK: - ComparisonObserver Conformance

extension ThresholdTimeline: ComparisonObserver {
    func comparisonCompleted(_ completed: CompletedComparison) {
        dataPoints.append(TimelineDataPoint(
            timestamp: completed.timestamp,
            centDifference: completed.comparison.centDifference,
            isCorrect: completed.isCorrect,
            note1: completed.comparison.note1
        ))
    }
}

// MARK: - Environment Key

private struct ThresholdTimelineKey: EnvironmentKey {
    nonisolated(unsafe) static var defaultValue: ThresholdTimeline = {
        @MainActor func makeDefault() -> ThresholdTimeline {
            ThresholdTimeline()
        }
        return MainActor.assumeIsolated {
            makeDefault()
        }
    }()
}

extension EnvironmentValues {
    var thresholdTimeline: ThresholdTimeline {
        get { self[ThresholdTimelineKey.self] }
        set { self[ThresholdTimelineKey.self] = newValue }
    }
}

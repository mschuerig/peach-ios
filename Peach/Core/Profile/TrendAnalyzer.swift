import Foundation

/// Direction of user's detection threshold trend
enum Trend: Equatable {
    /// User is detecting smaller differences (threshold going down — improvement)
    case improving
    /// No significant change in detection ability
    case stable
    /// User is detecting larger differences (threshold going up — regression)
    case declining
}

/// Analyzes trend direction from chronological comparison records
///
/// Computes trend by splitting records into earlier and later halves,
/// comparing mean `abs(centOffset)` between them.
/// Conforms to `ComparisonObserver` for incremental updates during training.
@Observable
final class TrendAnalyzer {

    /// Minimum number of records required before showing any trend
    static let minimumRecordCount = 20

    /// Percentage threshold for classifying trend (>5% change required)
    static let changeThreshold = 0.05

    /// Current computed trend direction, or nil if insufficient data
    private(set) var trend: Trend?

    /// Stored absolute cent offsets for trend computation (chronological order)
    private var absOffsets: [Double]

    /// Creates a TrendAnalyzer from existing comparison records
    /// - Parameter records: Historical records sorted by timestamp (oldest first)
    init(records: [ComparisonRecord] = []) {
        self.absOffsets = records.map { abs($0.centOffset) }
        self.trend = nil
        recompute()
    }

    /// Resets all trend data to initial state
    /// Used by Settings "Reset All Training Data" action
    func reset() {
        absOffsets = []
        trend = nil
    }

    /// Recomputes trend from stored offsets
    private func recompute() {
        guard absOffsets.count >= Self.minimumRecordCount else {
            trend = nil
            return
        }

        let midpoint = absOffsets.count / 2
        let earlierHalf = absOffsets[..<midpoint]
        let laterHalf = absOffsets[midpoint...]

        let earlierMean = earlierHalf.reduce(0.0, +) / Double(earlierHalf.count)
        let laterMean = laterHalf.reduce(0.0, +) / Double(laterHalf.count)

        guard earlierMean > 0 else {
            trend = .stable
            return
        }

        let changeRatio = (laterMean - earlierMean) / earlierMean

        if changeRatio < -Self.changeThreshold {
            trend = .improving
        } else if changeRatio > Self.changeThreshold {
            trend = .declining
        } else {
            trend = .stable
        }
    }
}

// MARK: - Resettable Conformance

extension TrendAnalyzer: Resettable {}

// MARK: - ComparisonObserver Conformance

extension TrendAnalyzer: ComparisonObserver {
    func comparisonCompleted(_ completed: CompletedComparison) {
        absOffsets.append(completed.comparison.targetNote.offset.magnitude)
        recompute()
    }
}

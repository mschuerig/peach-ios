import SwiftUI

/// Displays mean detection threshold, standard deviation, and trend indicator
/// Data is derived from PerceptualProfile (mean/stdDev) and TrendAnalyzer (trend)
struct SummaryStatisticsView: View {
    @Environment(\.perceptualProfile) private var profile
    @Environment(\.trendAnalyzer) private var trendAnalyzer

    private let midiRange: ClosedRange<Int>

    init(midiRange: ClosedRange<Int> = 36...84) {
        self.midiRange = midiRange
    }

    var body: some View {
        let stats = Self.computeStats(from: profile, midiRange: midiRange)

        HStack(spacing: 24) {
            statItem(
                label: "Mean",
                value: Self.formatMean(stats?.mean)
            )
            .accessibilityLabel(Self.accessibilityMean(stats?.mean))

            statItem(
                label: "Std Dev",
                value: Self.formatStdDev(stats?.stdDev)
            )
            .accessibilityLabel(Self.accessibilityStdDev(stats?.stdDev))

            if let trend = trendAnalyzer.trend {
                trendItem(trend: trend)
                    .accessibilityLabel(Self.accessibilityTrend(trend))
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: stats == nil ? .ignore : .contain)
        .accessibilityLabel(stats == nil ? String(localized: "No training data yet") : String(localized: "Summary statistics"))
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private func statItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func trendItem(trend: Trend) -> some View {
        VStack(spacing: 2) {
            Image(systemName: Self.trendSymbol(trend))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Trend")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Trend Display

    /// SF Symbol name for each trend direction
    /// Down-right = improving (threshold going down is good)
    /// Right = stable
    /// Up-right = declining (threshold going up is bad)
    static func trendSymbol(_ trend: Trend) -> String {
        switch trend {
        case .improving: "arrow.down.right"
        case .stable: "arrow.right"
        case .declining: "arrow.up.right"
        }
    }

    // MARK: - Statistics Computation

    struct Stats {
        let mean: Double
        let stdDev: Double?
    }

    /// Computes display statistics from the profile using per-note means
    /// Returns nil if no trained notes exist (cold start)
    static func computeStats(from profile: PerceptualProfile, midiRange: ClosedRange<Int>) -> Stats? {
        let trainedNotes = midiRange.filter { profile.statsForNote(MIDINote($0)).isTrained }
        guard !trainedNotes.isEmpty else { return nil }

        let means = trainedNotes.map { profile.statsForNote(MIDINote($0)).mean }
        let mean = means.reduce(0.0, +) / Double(means.count)

        let stdDev: Double?
        if means.count >= 2 {
            let variance = means.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(means.count - 1)
            stdDev = sqrt(variance)
        } else {
            stdDev = nil
        }

        return Stats(mean: mean, stdDev: stdDev)
    }

    // MARK: - Formatting

    static func formatMean(_ value: Double?) -> String {
        guard let value else { return "—" }
        let rounded = Int(value.rounded())
        return String(localized: "\(rounded) cents")
    }

    static func formatStdDev(_ value: Double?) -> String {
        guard let value else { return "—" }
        let rounded = Int(value.rounded())
        return String(localized: "±\(rounded) cents")
    }

    // MARK: - Accessibility

    static func accessibilityMean(_ value: Double?) -> String {
        guard let value else { return String(localized: "No training data yet") }
        let rounded = Int(value.rounded())
        return String(localized: "Mean detection threshold: \(rounded) cents")
    }

    static func accessibilityStdDev(_ value: Double?) -> String {
        guard let value else { return "" }
        let rounded = Int(value.rounded())
        return String(localized: "Standard deviation: \(rounded) cents")
    }

    static func accessibilityTrend(_ trend: Trend) -> String {
        switch trend {
        case .improving: String(localized: "Trend: improving")
        case .stable: String(localized: "Trend: stable")
        case .declining: String(localized: "Trend: declining")
        }
    }
}

#Preview("With Data") {
    SummaryStatisticsView()
        .environment(\.perceptualProfile, {
            let p = PerceptualProfile()
            for note in stride(from: 36, through: 84, by: 3) {
                let threshold = Double.random(in: 10...80)
                p.update(note: MIDINote(note), centOffset: threshold, isCorrect: true)
            }
            return p
        }())
        .environment(\.trendAnalyzer, {
            let records = (0..<20).map { i in
                ComparisonRecord(
                    note1: 60, note2: 60,
                    note2CentOffset: i < 10 ? 50.0 : 30.0,
                    isCorrect: true,
                    timestamp: Date(timeIntervalSince1970: Double(i) * 60)
                )
            }
            return TrendAnalyzer(records: records)
        }())
}

#Preview("Cold Start") {
    SummaryStatisticsView()
}

import SwiftUI

struct TimingStatsView: View {
    let latestMs: Double?
    let bestMs: Double?
    let trend: Trend?

    private var config: TrainingDisciplineConfig { TrainingDisciplineID.timingOffsetDetection.config }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(Self.latestText(latestMs ?? 0, unitSymbol: config.unitSymbol))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let trend {
                    Image(systemName: Self.trendSymbol(trend))
                        .font(.footnote)
                        .foregroundStyle(Self.trendColor(trend))
                        .accessibilityLabel(Self.trendLabel(trend))
                }
            }
            .opacity(latestMs != nil ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(latestMs.map { Self.latestAccessibilityLabel($0, unitLabel: config.unitLabel, trend: trend) } ?? "")
            .accessibilityHidden(latestMs == nil)

            Text(Self.bestText(bestMs ?? 0, unitSymbol: config.unitSymbol))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(bestMs != nil ? 1 : 0)
                .accessibilityLabel(bestMs.map { Self.bestAccessibilityLabel($0, unitLabel: config.unitLabel) } ?? "")
                .accessibilityHidden(bestMs == nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Trend Helpers

    static func trendSymbol(_ trend: Trend) -> String {
        switch trend {
        case .improving: "arrow.down.right"
        case .stable: "arrow.right"
        case .declining: "arrow.up.right"
        }
    }

    static func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .improving: .green
        case .stable: .secondary
        case .declining: .orange
        }
    }

    static func trendLabel(_ trend: Trend) -> String {
        switch trend {
        case .improving: String(localized: "Improving")
        case .stable: String(localized: "Stable")
        case .declining: String(localized: "Declining")
        }
    }

    // MARK: - Formatting and Accessibility (extracted for testability)

    static func latestText(_ ms: Double, unitSymbol: String) -> String {
        String(localized: "Latest: \(TimingOffsetFormatter.compact(ms, unitSymbol: unitSymbol))")
    }

    static func bestText(_ ms: Double, unitSymbol: String) -> String {
        String(localized: "Best: \(TimingOffsetFormatter.compact(ms, unitSymbol: unitSymbol))")
    }

    static func latestAccessibilityLabel(_ ms: Double, unitLabel: String, trend: Trend?) -> String {
        var label = String(localized: "Latest result: \(TimingOffsetFormatter.spoken(ms, unitLabel: unitLabel))")
        if let trend {
            label += ", \(trendLabel(trend))"
        }
        return label
    }

    static func bestAccessibilityLabel(_ ms: Double, unitLabel: String) -> String {
        String(localized: "Best result: \(TimingOffsetFormatter.spoken(ms, unitLabel: unitLabel))")
    }
}

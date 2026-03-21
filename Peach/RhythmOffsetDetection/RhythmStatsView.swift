import SwiftUI

struct RhythmStatsView: View {
    let latestValue: Double?
    let sessionBest: Double?
    let trend: Trend?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("Latest: \(Self.percentageText(latestValue ?? 0))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let trend {
                    Image(systemName: Self.trendSymbol(trend))
                        .font(.footnote)
                        .foregroundStyle(Self.trendColor(trend))
                        .accessibilityLabel(Self.trendLabel(trend))
                }
            }
            .opacity(latestValue != nil ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(latestValue.map { Self.latestAccessibilityLabel($0, trend: trend) } ?? "")
            .accessibilityHidden(latestValue == nil)

            Text("Best: \(Self.percentageText(sessionBest ?? 0))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(sessionBest != nil ? 1 : 0)
                .accessibilityLabel(sessionBest.map { Self.bestAccessibilityLabel($0) } ?? "")
                .accessibilityHidden(sessionBest == nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Formatting

    static func percentageText(_ value: Double) -> String {
        String(format: "%.0f%%", value)
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

    // MARK: - Accessibility

    static func latestAccessibilityLabel(_ value: Double, trend: Trend?) -> String {
        var label = String(localized: "Latest result: \(Self.percentageText(value))")
        if let trend {
            label += ", \(trendLabel(trend))"
        }
        return label
    }

    static func bestAccessibilityLabel(_ value: Double) -> String {
        String(localized: "Best result: \(Self.percentageText(value))")
    }
}

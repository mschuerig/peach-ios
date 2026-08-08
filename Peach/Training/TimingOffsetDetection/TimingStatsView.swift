import SwiftUI

struct TimingStatsView: View {
    let latestMs: Double?
    let bestMs: Double?
    let trend: Trend?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("Latest: \(TimingOffsetFormatter.compact(latestMs ?? 0))")
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
            .accessibilityLabel(latestMs.map { Self.latestAccessibilityLabel($0, trend: trend) } ?? "")
            .accessibilityHidden(latestMs == nil)

            Text("Best: \(TimingOffsetFormatter.compact(bestMs ?? 0))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(bestMs != nil ? 1 : 0)
                .accessibilityLabel(bestMs.map { Self.bestAccessibilityLabel($0) } ?? "")
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

    // MARK: - Accessibility

    static func latestAccessibilityLabel(_ ms: Double, trend: Trend?) -> String {
        var label = String(localized: "Latest result: \(TimingOffsetFormatter.spoken(ms))")
        if let trend {
            label += ", \(trendLabel(trend))"
        }
        return label
    }

    static func bestAccessibilityLabel(_ ms: Double) -> String {
        String(localized: "Best result: \(TimingOffsetFormatter.spoken(ms))")
    }
}

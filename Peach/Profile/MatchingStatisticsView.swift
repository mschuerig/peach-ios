import SwiftUI

struct MatchingStatisticsView: View {
    @Environment(\.perceptualProfile) private var profile

    var body: some View {
        let stats = Self.computeMatchingStats(from: profile)

        if let stats {
            HStack(spacing: 24) {
                statItem(
                    label: "Mean Error",
                    value: Self.formatMeanError(stats.meanError)
                )
                .accessibilityLabel(Self.accessibilityMeanError(stats.meanError))

                statItem(
                    label: "Std Dev",
                    value: Self.formatStdDev(stats.stdDev)
                )
                .accessibilityLabel(Self.accessibilityStdDev(stats.stdDev))

                statItem(
                    label: "Samples",
                    value: Self.formatSampleCount(stats.sampleCount)
                )
                .accessibilityLabel(Self.accessibilitySamples(stats.sampleCount))
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Pitch matching statistics"))
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        } else {
            Text("Start pitch matching to see your accuracy")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .accessibilityLabel(String(localized: "Start pitch matching to see your accuracy"))
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
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

    // MARK: - Statistics Computation

    struct MatchingStats {
        let meanError: Double
        let stdDev: Double?
        let sampleCount: Int
    }

    static func computeMatchingStats(from profile: PerceptualProfile) -> MatchingStats? {
        guard let mean = profile.matchingMean else { return nil }
        return MatchingStats(
            meanError: mean,
            stdDev: profile.matchingStdDev,
            sampleCount: profile.matchingSampleCount
        )
    }

    // MARK: - Formatting

    static func formatMeanError(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(localized: "\(value, specifier: "%.1f") cents")
    }

    static func formatStdDev(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(localized: "±\(value, specifier: "%.1f") cents")
    }

    static func formatSampleCount(_ count: Int) -> String {
        "\(count)"
    }

    // MARK: - Accessibility

    static func accessibilityMeanError(_ value: Double?) -> String {
        guard let value else {
            return String(localized: "Start pitch matching to see your accuracy")
        }
        return String(localized: "Mean matching error: \(value, specifier: "%.1f") cents")
    }

    static func accessibilityStdDev(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(localized: "Standard deviation: \(value, specifier: "%.1f") cents")
    }

    static func accessibilitySamples(_ count: Int) -> String {
        String(localized: "\(count) pitch matching exercises completed")
    }
}

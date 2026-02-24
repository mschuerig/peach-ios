import SwiftUI

struct ProfileScreen: View {
    @Environment(\.perceptualProfile) private var profile
    @Environment(\.thresholdTimeline) private var timeline

    private let midiRange: ClosedRange<Int> = 36...84

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ThresholdTimelineView()
                .padding(.horizontal)

            SummaryStatisticsView(midiRange: midiRange)

            Spacer()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: timeline.dataPoints.isEmpty ? .combine : .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Accessibility

    private var accessibilitySummary: String {
        Self.accessibilitySummary(timeline: timeline)
    }

    @MainActor
    static func accessibilitySummary(timeline: ThresholdTimeline) -> String {
        let aggregated = timeline.aggregatedPoints
        guard !aggregated.isEmpty else {
            return String(localized: "Threshold timeline. No training data available.")
        }

        let totalComparisons = timeline.dataPoints.count
        let firstDate = aggregated.first!.periodStart
        let lastDate = aggregated.last!.periodStart

        let dateRange: String
        if Calendar.current.isDate(firstDate, inSameDayAs: lastDate) {
            dateRange = lastDate.formatted(.dateTime.month().day())
        } else {
            dateRange = "\(firstDate.formatted(.dateTime.month().day())) – \(lastDate.formatted(.dateTime.month().day()))"
        }

        let means = timeline.rollingMean()
        let currentAvg = means.last.map { Int($0.value.rounded()) } ?? 0

        return String(localized: "Threshold timeline showing \(totalComparisons) comparisons over \(dateRange). Current average: \(currentAvg) cents.")
    }
}

#Preview("With Data") {
    NavigationStack {
        ProfileScreen()
            .environment(\.thresholdTimeline, {
                let records = (0..<50).map { i in
                    let baseOffset = 50.0 - Double(i) * 0.5
                    let noise = Double.random(in: -10...10)
                    return ComparisonRecord(
                        note1: 60,
                        note2: 60,
                        note2CentOffset: baseOffset + noise,
                        isCorrect: Bool.random(),
                        timestamp: Date().addingTimeInterval(Double(i - 50) * 86400)
                    )
                }
                return ThresholdTimeline(records: records)
            }())
            .environment(\.perceptualProfile, {
                let p = PerceptualProfile()
                for note in stride(from: 36, through: 84, by: 3) {
                    p.update(note: note, centOffset: Double.random(in: 10...80), isCorrect: true)
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
}

#Preview("Cold Start") {
    NavigationStack {
        ProfileScreen()
    }
}

// MARK: - Environment Key for PerceptualProfile

private struct PerceptualProfileKey: EnvironmentKey {
    nonisolated(unsafe) static var defaultValue: PerceptualProfile = {
        @MainActor func makeDefault() -> PerceptualProfile {
            PerceptualProfile()
        }
        return MainActor.assumeIsolated {
            makeDefault()
        }
    }()
}

extension EnvironmentValues {
    var perceptualProfile: PerceptualProfile {
        get { self[PerceptualProfileKey.self] }
        set { self[PerceptualProfileKey.self] = newValue }
    }
}

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

            Divider()
                .padding(.horizontal)

            MatchingStatisticsView()

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
                        referenceNote: 60,
                        targetNote: 60,
                        centOffset: baseOffset + noise,
                        isCorrect: Bool.random(),
                        timestamp: Date().addingTimeInterval(Double(i - 50) * 86400)
                    )
                }
                return ThresholdTimeline(records: records)
            }())
            .environment(\.perceptualProfile, {
                let p = PerceptualProfile()
                for note in stride(from: 36, through: 84, by: 3) {
                    p.update(note: MIDINote(note), centOffset: Double.random(in: 10...80), isCorrect: true)
                }
                for note in [60, 62, 64, 67, 69] {
                    p.updateMatching(note: MIDINote(note), centError: Double.random(in: 2...25))
                }
                return p
            }())
            .environment(\.trendAnalyzer, {
                let records = (0..<20).map { i in
                    ComparisonRecord(
                        referenceNote: 60, targetNote: 60,
                        centOffset: i < 10 ? 50.0 : 30.0,
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

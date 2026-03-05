import SwiftUI

struct ProfileScreen: View {
    @Environment(\.progressTimeline) private var progressTimeline

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(TrainingMode.allCases, id: \.self) { mode in
                    let state = progressTimeline.state(for: mode)
                    if state != .noData {
                        ProgressChartView(mode: mode)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Accessibility

    private var accessibilitySummary: String {
        Self.accessibilitySummary(progressTimeline: progressTimeline)
    }

    static func accessibilitySummary(progressTimeline: ProgressTimeline) -> String {
        let activeModes = TrainingMode.allCases.filter { progressTimeline.state(for: $0) != .noData }
        guard !activeModes.isEmpty else {
            return String(localized: "Profile. No training data available.")
        }
        let modeNames = activeModes.map(\.config.displayName).joined(separator: ", ")
        return String(localized: "Profile showing progress for: \(modeNames)")
    }
}

#Preview("With Data") {
    NavigationStack {
        ProfileScreen()
            .environment(\.progressTimeline, {
                var comparisons: [ComparisonRecord] = []
                for i in 0..<50 {
                    let baseOffset = 50.0 - Double(i) * 0.5
                    let noise = Double.random(in: -10...10)
                    comparisons.append(ComparisonRecord(
                        referenceNote: 60,
                        targetNote: 60,
                        centOffset: baseOffset + noise,
                        isCorrect: true,
                        interval: 0,
                        tuningSystem: "equalTemperament",
                        timestamp: Date().addingTimeInterval(Double(i - 50) * 3600)
                    ))
                }
                return ProgressTimeline(comparisonRecords: comparisons)
            }())
    }
}

#Preview("Cold Start") {
    NavigationStack {
        ProfileScreen()
    }
}

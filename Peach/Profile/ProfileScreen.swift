import SwiftUI
import TipKit

struct ProfileScreen: View {
    @Environment(\.progressTimeline) private var progressTimeline
    @State private var tipGroup = TipGroup(.ordered) {
        ChartOverviewTip()
        EWMALineTip()
        StdDevBandTip()
        BaselineTip()
        GranularityZoneTip()
    }
    @State private var showHelpSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let currentTip = tipGroup.currentTip {
                    TipView(currentTip)
                }
                ForEach(TrainingMode.allCases, id: \.self) { mode in
                    let state = progressTimeline.state(for: mode)
                    if state != .noData {
                        ProgressChartView(mode: mode)
                    }
                }
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Self.accessibilitySummary(progressTimeline: progressTimeline))
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showHelpSheet = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        HelpContentView(sections: Self.helpSections)
                    }
                    .padding()
                }
                .navigationTitle(String(localized: "Chart Help"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Done")) {
                            showHelpSheet = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Help Content

    private static let helpSections = [
        HelpSection(
            title: String(localized: "Your Progress Chart",
                          comment: "Chart overview help title"),
            body: String(localized: "This chart shows how your pitch perception is developing over time.",
                         comment: "Chart overview help body")
        ),
        HelpSection(
            title: String(localized: "Trend Line",
                          comment: "EWMA line help title"),
            body: String(localized: "The blue line shows your smoothed average — it filters out random ups and downs to reveal your real progress.",
                         comment: "EWMA line help body")
        ),
        HelpSection(
            title: String(localized: "Variability Band",
                          comment: "Stddev band help title"),
            body: String(localized: "The shaded area around the line shows how consistent you are — a narrower band means more reliable results.",
                         comment: "Stddev band help body")
        ),
        HelpSection(
            title: String(localized: "Target Baseline",
                          comment: "Baseline help title"),
            body: String(localized: "The green dashed line is your goal — as the trend line approaches it, your ear is getting sharper.",
                         comment: "Baseline help body")
        ),
        HelpSection(
            title: String(localized: "Time Zones",
                          comment: "Granularity zone help title"),
            body: String(localized: "The chart groups your data by time: months on the left, recent days in the middle, and today's sessions on the right.",
                         comment: "Granularity zone help body")
        ),
    ]

    // MARK: - Accessibility

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
                var comparisons: [PitchComparisonRecord] = []
                for i in 0..<50 {
                    let baseOffset = 50.0 - Double(i) * 0.5
                    let noise = Double.random(in: -10...10)
                    comparisons.append(PitchComparisonRecord(
                        referenceNote: 60,
                        targetNote: 60,
                        centOffset: baseOffset + noise,
                        isCorrect: true,
                        interval: 0,
                        tuningSystem: "equalTemperament",
                        timestamp: Date().addingTimeInterval(Double(i - 50) * 3600)
                    ))
                }
                return ProgressTimeline(pitchComparisonRecords: comparisons)
            }())
    }
}

#Preview("Cold Start") {
    NavigationStack {
        ProfileScreen()
    }
}

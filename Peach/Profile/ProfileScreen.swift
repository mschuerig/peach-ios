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
                ForEach(TrainingDisciplineID.allCases, id: \.self) { mode in
                    switch mode {
                    case .timingOffsetDetection, .continuousRhythmMatching:
                        RhythmProfileCardView(mode: mode)
                    default:
                        let state = progressTimeline.state(for: mode)
                        if state != .noData {
                            ProgressChartView(mode: mode)
                        }
                    }
                }
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Self.accessibilitySummary(progressTimeline: progressTimeline))
        }
        .navigationTitle("Profile")
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showHelpSheet = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
            }
        }
        .platformHelp(
            isPresented: $showHelpSheet,
            title: String(localized: "Profile Help"),
            sections: HelpContent.profile
        )
    }

    // MARK: - Accessibility

    static func accessibilitySummary(progressTimeline: ProgressTimeline) -> String {
        let activeModes = TrainingDisciplineID.allCases.filter { progressTimeline.state(for: $0) != .noData }
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
                let profile = PerceptualProfile { builder in
                    for i in 0..<50 {
                        let baseOffset = 50.0 - Double(i) * 0.5
                        let noise = Double.random(in: -10...10)
                        builder.addPoint(MetricPoint(
                            timestamp: Date().addingTimeInterval(Double(i - 50) * 3600),
                            value: abs(baseOffset + noise)
                        ), for: .pitch(.unisonPitchDiscrimination))
                    }
                }
                return ProgressTimeline(profile: profile)
            }())
    }
}

#Preview("Cold Start") {
    NavigationStack {
        ProfileScreen()
    }
}

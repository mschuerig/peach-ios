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
                ForEach(TrainingDisciplineRegistry.shared.allUI, id: \.id) { discipline in
                    discipline.profileCard
                }
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
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
            sections: HelpContent.profileHelpSections()
        )
    }

    // MARK: - Accessibility

    static func accessibilitySummary(progressTimeline: ProgressTimeline) -> String {
        let activeDisciplines = TrainingDisciplineRegistry.shared.allUI.filter {
            progressTimeline.state(for: $0.id) != .noData
        }
        guard !activeDisciplines.isEmpty else {
            return String(localized: "Profile. No training data available.")
        }
        let disciplineNames = activeDisciplines.map(\.config.displayName).joined(separator: ", ")
        return String(localized: "Profile showing progress for: \(disciplineNames)")
    }
}

#if DEBUG
#Preview("With Data") {
    PreviewSupport.bootstrapRegistryIfNeeded()
    return NavigationStack {
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
    PreviewSupport.bootstrapRegistryIfNeeded()
    return NavigationStack {
        ProfileScreen()
    }
}
#endif

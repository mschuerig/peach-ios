import SwiftUI

struct StartScreen: View {
    @State private var showInfoSheet = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    // MARK: - Layout Parameters (extracted for testability)

    static func sectionSpacing(isCompact: Bool) -> CGFloat {
        isCompact ? 24 : 28
    }

    static func cardSpacing(isCompact: Bool) -> CGFloat {
        isCompact ? 6 : 10
    }

    static let cardCornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if isCompactHeight {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .padding()
        .navigationTitle("Peach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Peach")
                    .font(.headline)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Info")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: NavigationDestination.profile) {
                    Image(systemName: "chart.xyaxis.line")
                }
                .accessibilityLabel("Profile")

                NavigationLink(value: NavigationDestination.settings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .pitchDiscrimination(let isIntervalMode):
                PitchDiscriminationScreen(isIntervalMode: isIntervalMode)
            case .pitchMatching(let isIntervalMode):
                PitchMatchingScreen(isIntervalMode: isIntervalMode)
            case .settings:
                SettingsScreen()
            case .profile:
                ProfileScreen()
            case .rhythmOffsetDetection:
                RhythmOffsetDetectionScreen()
            case .continuousRhythmMatching:
                ContinuousRhythmMatchingScreen()
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            InfoScreen()
        }
    }

    // MARK: - Layouts

    private var portraitLayout: some View {
        ScrollView(.vertical) {
            VStack(spacing: Self.sectionSpacing(isCompact: false)) {
                pitchSection
                intervalsSection
                rhythmSection
            }
            .padding(.vertical)
        }
    }

    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: Self.sectionSpacing(isCompact: true)) {
            pitchSection
                .frame(maxWidth: .infinity)
            intervalsSection
                .frame(maxWidth: .infinity)
            rhythmSection
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sections

    private var pitchSection: some View {
        VStack(spacing: Self.cardSpacing(isCompact: isCompactHeight)) {
            Text("Pitch")
                .font(.title3)
                .foregroundStyle(.secondary)

            NavigationLink(value: NavigationDestination.pitchDiscrimination(isIntervalMode: false)) {
                trainingCard("Compare", systemImage: "ear", mode: .unisonPitchDiscrimination, isHero: true)
            }
            .buttonStyle(TrainingCardButtonStyle())
            .accessibilityLabel("Compare Pitch")

            NavigationLink(value: NavigationDestination.pitchMatching(isIntervalMode: false)) {
                trainingCard("Match", systemImage: "target", mode: .unisonPitchMatching)
            }
            .buttonStyle(TrainingCardButtonStyle())
            .accessibilityLabel("Match Pitch")
        }
    }

    private var intervalsSection: some View {
        VStack(spacing: Self.cardSpacing(isCompact: isCompactHeight)) {
            Text("Intervals")
                .font(.title3)
                .foregroundStyle(.secondary)

            NavigationLink(value: NavigationDestination.pitchDiscrimination(isIntervalMode: true)) {
                trainingCard("Compare", systemImage: "ear", mode: .intervalPitchDiscrimination)
            }
            .buttonStyle(TrainingCardButtonStyle())
            .accessibilityLabel("Compare Intervals")

            NavigationLink(value: NavigationDestination.pitchMatching(isIntervalMode: true)) {
                trainingCard("Match", systemImage: "target", mode: .intervalPitchMatching)
            }
            .buttonStyle(TrainingCardButtonStyle())
            .accessibilityLabel("Match Interval")
        }
    }

    private var rhythmSection: some View {
        VStack(spacing: Self.cardSpacing(isCompact: isCompactHeight)) {
            Text("Rhythm")
                .font(.title3)
                .foregroundStyle(.secondary)

            NavigationLink(value: NavigationDestination.rhythmOffsetDetection) {
                trainingCard("Compare", systemImage: "metronome", mode: .rhythmOffsetDetection)
            }
            .buttonStyle(TrainingCardButtonStyle())
            .accessibilityLabel("Compare Timing")

            NavigationLink(value: NavigationDestination.continuousRhythmMatching) {
                trainingCard("Fill the Gap", systemImage: "hand.tap", mode: .continuousRhythmMatching)
            }
            .buttonStyle(TrainingCardButtonStyle())
            .accessibilityLabel("Fill the Gap")
        }
    }

    // MARK: - Card View

    private func trainingCard(
        _ title: LocalizedStringKey,
        systemImage: String,
        mode: TrainingDiscipline,
        isHero: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
            ProgressSparklineView(mode: mode)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .foregroundStyle(.primary)
        .background(
            RoundedRectangle(cornerRadius: Self.cardCornerRadius)
                .fill(isHero ? .thinMaterial : .regularMaterial)
        )
        .overlay {
            if isHero {
                RoundedRectangle(cornerRadius: Self.cardCornerRadius)
                    .strokeBorder(.tint.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

private struct TrainingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        StartScreen()
    }
}

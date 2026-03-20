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
                VStack {
                    HStack(spacing: Self.sectionSpacing(isCompact: true)) {
                        singleNotesSection
                        intervalsSection
                    }
                    rhythmPOCButton
                }
            } else {
                VStack(spacing: Self.sectionSpacing(isCompact: false)) {
                    Spacer()
                    singleNotesSection
                    intervalsSection
                    rhythmPOCButton
                    Spacer()
                }
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
            case .pitchComparison(let isIntervalMode):
                PitchComparisonScreen(isIntervalMode: isIntervalMode)
            case .pitchMatching(let isIntervalMode):
                PitchMatchingScreen(isIntervalMode: isIntervalMode)
            case .settings:
                SettingsScreen()
            case .profile:
                ProfileScreen()
            case .rhythmPOC:
                RhythmPOCScreen()
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            InfoScreen()
        }
    }

    // MARK: - Sections

    private var singleNotesSection: some View {
        VStack(spacing: Self.cardSpacing(isCompact: isCompactHeight)) {
            Text("Single Notes")
                .font(.title3)
                .foregroundStyle(.secondary)

            NavigationLink(value: NavigationDestination.pitchComparison(isIntervalMode: false)) {
                trainingCard("Hear & Compare", systemImage: "ear", mode: .unisonPitchComparison)
            }
            .buttonStyle(TrainingCardButtonStyle())

            NavigationLink(value: NavigationDestination.pitchMatching(isIntervalMode: false)) {
                trainingCard("Tune & Match", systemImage: "target", mode: .unisonMatching)
            }
            .buttonStyle(TrainingCardButtonStyle())
        }
    }

    private var intervalsSection: some View {
        VStack(spacing: Self.cardSpacing(isCompact: isCompactHeight)) {
            Text("Intervals")
                .font(.title3)
                .foregroundStyle(.secondary)

            NavigationLink(value: NavigationDestination.pitchComparison(isIntervalMode: true)) {
                trainingCard("Hear & Compare", systemImage: "ear", mode: .intervalPitchComparison)
            }
            .buttonStyle(TrainingCardButtonStyle())

            NavigationLink(value: NavigationDestination.pitchMatching(isIntervalMode: true)) {
                trainingCard("Tune & Match", systemImage: "target", mode: .intervalMatching)
            }
            .buttonStyle(TrainingCardButtonStyle())
        }
    }

    // MARK: - Rhythm POC

    private var rhythmPOCButton: some View {
        NavigationLink(value: NavigationDestination.rhythmPOC) {
            Label("Rhythm POC", systemImage: "metronome")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: Self.cardCornerRadius)
                        .fill(.orange.opacity(0.15))
                        .strokeBorder(.orange, lineWidth: 1)
                )
        }
        .buttonStyle(TrainingCardButtonStyle())
    }

    // MARK: - Card View

    private func trainingCard(
        _ title: LocalizedStringKey,
        systemImage: String,
        mode: TrainingMode
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
                .fill(.regularMaterial)
        )
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

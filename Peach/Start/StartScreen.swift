import SwiftUI

struct StartScreen: View {
    @State private var showInfoSheet = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @AppStorage(SettingsKeys.intervals)
    private var intervalSelection = IntervalSelection.default

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
                HStack(spacing: Self.sectionSpacing(isCompact: true)) {
                    singleNotesSection
                    intervalsSection
                }
            } else {
                VStack(spacing: Self.sectionSpacing(isCompact: false)) {
                    Spacer()
                    singleNotesSection
                    intervalsSection
                    Spacer()
                }
            }
        }
        .padding()
        .navigationTitle("Peach")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Info")
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
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
            case .comparison(let intervals):
                ComparisonScreen(intervals: intervals)
            case .pitchMatching(let intervals):
                PitchMatchingScreen(intervals: intervals)
            case .settings:
                SettingsScreen()
            case .profile:
                ProfileScreen()
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

            NavigationLink(value: NavigationDestination.comparison(intervals: [.prime])) {
                trainingCard("Hear & Compare", systemImage: "ear")
            }
            .buttonStyle(TrainingCardButtonStyle())

            NavigationLink(value: NavigationDestination.pitchMatching(intervals: [.prime])) {
                trainingCard("Tune & Match", systemImage: "target")
            }
            .buttonStyle(TrainingCardButtonStyle())
        }
    }

    private var intervalsSection: some View {
        VStack(spacing: Self.cardSpacing(isCompact: isCompactHeight)) {
            Text("Intervals")
                .font(.title3)
                .foregroundStyle(.secondary)

            NavigationLink(value: NavigationDestination.comparison(intervals: intervalSelection.intervals)) {
                trainingCard("Hear & Compare", systemImage: "ear")
            }
            .buttonStyle(TrainingCardButtonStyle())

            NavigationLink(value: NavigationDestination.pitchMatching(intervals: intervalSelection.intervals)) {
                trainingCard("Tune & Match", systemImage: "target")
            }
            .buttonStyle(TrainingCardButtonStyle())
        }
    }

    // MARK: - Card View

    private func trainingCard(
        _ title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
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

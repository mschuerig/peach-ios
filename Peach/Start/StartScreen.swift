import SwiftUI

struct StartScreen: View {
    @State private var showInfoSheet = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    // MARK: - Layout Parameters (extracted for testability)

    static func vstackSpacing(isCompact: Bool) -> CGFloat {
        isCompact ? 16 : 40
    }

    var body: some View {
        VStack(spacing: Self.vstackSpacing(isCompact: isCompactHeight)) {
            Spacer()

            // Profile Preview (navigates to full Profile Screen)
            NavigationLink(value: NavigationDestination.profile) {
                ProfilePreviewView()
            }
            .buttonStyle(.plain)

            Spacer()

            // Comparison Button (Primary Action)
            NavigationLink(value: NavigationDestination.comparison(intervals: [.prime])) {
                Text("Comparison")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Pitch Matching Button (Secondary Action)
            NavigationLink(value: NavigationDestination.pitchMatching(intervals: [.prime])) {
                Text("Pitch Matching")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            // Visual separator between unison and interval groups
            Divider()

            // Interval Comparison Button
            NavigationLink(value: NavigationDestination.comparison(intervals: [.perfectFifth])) {
                Text("Interval Comparison")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            // Interval Pitch Matching Button
            NavigationLink(value: NavigationDestination.pitchMatching(intervals: [.perfectFifth])) {
                Text("Interval Pitch Matching")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()

            // Secondary Navigation Buttons
            HStack(spacing: 32) {
                NavigationLink(value: NavigationDestination.settings) {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                }
                .accessibilityLabel("Settings")

                NavigationLink(value: NavigationDestination.profile) {
                    Image(systemName: "chart.xyaxis.line")
                        .imageScale(.large)
                }
                .accessibilityLabel("Profile")

                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .imageScale(.large)
                }
                .accessibilityLabel("Info")
            }
        }
        .padding()
        .navigationTitle("Peach")
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

}

#Preview {
    NavigationStack {
        StartScreen()
    }
}

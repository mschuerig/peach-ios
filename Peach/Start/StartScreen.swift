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

            // Start Training Button (Primary Action)
            NavigationLink(value: NavigationDestination.training) {
                Text("Start Training")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Pitch Matching Button (Secondary Action)
            NavigationLink(value: NavigationDestination.pitchMatching) {
                Label("Pitch Matching", systemImage: "waveform")
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
            case .training:
                ComparisonScreen()
            case .pitchMatching:
                PitchMatchingScreen()
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

import SwiftUI
import os

struct PitchMatchingScreen: View {
    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingScreen")

    var body: some View {
        VStack(spacing: 8) {
            if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
                Text(interval.displayName)
                    .font(.title3)
                    .accessibilityLabel(String(localized: "Target interval: \(interval.displayName)"))
            }

            VerticalPitchSlider(
                isActive: pitchMatchingSession.state == .playingTunable,
                onValueChange: { value in
                    pitchMatchingSession.adjustPitch(value)
                },
                onCommit: { value in
                    pitchMatchingSession.commitPitch(value)
                }
            )
            .padding()
            .overlay {
                if pitchMatchingSession.state == .showingFeedback {
                    PitchMatchingFeedbackIndicator(
                        centError: pitchMatchingSession.lastResult?.userCentError
                    )
                    .transition(.opacity)
                }
            }
            .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchMatchingSession.state == .showingFeedback)
        }
        .navigationTitle("Pitch Matching")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 20) {
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
                }
            }
        }
        .onAppear {
            logger.info("PitchMatchingScreen appeared - starting pitch matching")
            pitchMatchingSession.start()
        }
        .onDisappear {
            logger.info("PitchMatchingScreen disappeared - stopping pitch matching")
            pitchMatchingSession.stop()
        }
    }

    // MARK: - Layout Parameters (extracted for testability)

    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        PitchMatchingScreen()
    }
}

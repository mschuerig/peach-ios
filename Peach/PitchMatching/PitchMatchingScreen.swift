import SwiftUI
import os

struct PitchMatchingScreen: View {
    let intervals: Set<DirectedInterval>

    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingScreen")

    var body: some View {
        VStack(spacing: 8) {
            if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
                VStack(spacing: 2) {
                    Text(interval.displayName)
                        .font(.title3)
                    Text(pitchMatchingSession.sessionTuningSystem.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Target interval: \(interval.displayName), \(pitchMatchingSession.sessionTuningSystem.displayName)"))
            }

            PitchMatchingFeedbackIndicator(
                centError: pitchMatchingSession.lastResult?.userCentError
            )
            .frame(height: Self.feedbackIndicatorHeight)
            .opacity(pitchMatchingSession.state == .showingFeedback ? 1 : 0)
            .accessibilityHidden(pitchMatchingSession.state != .showingFeedback)
            .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchMatchingSession.state == .showingFeedback)

            VerticalPitchSlider(
                isActive: pitchMatchingSession.state == .awaitingSliderTouch || pitchMatchingSession.state == .playingTunable,
                onValueChange: { value in
                    pitchMatchingSession.adjustPitch(value)
                },
                onCommit: { value in
                    pitchMatchingSession.commitPitch(value)
                }
            )
            .padding()
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
            pitchMatchingSession.start(intervals: intervals)
        }
        .onDisappear {
            logger.info("PitchMatchingScreen disappeared - stopping pitch matching")
            pitchMatchingSession.stop()
        }
    }

    // MARK: - Layout Parameters (extracted for testability)

    static let feedbackIndicatorHeight: CGFloat = 130

    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        PitchMatchingScreen(intervals: [DirectedInterval.prime])
    }
}

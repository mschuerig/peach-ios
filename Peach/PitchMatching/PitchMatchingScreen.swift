import SwiftUI
import os

struct PitchMatchingScreen: View {
    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingScreen")

    var body: some View {
        VerticalPitchSlider(
            isActive: pitchMatchingSession.state == .playingTunable,
            referenceFrequency: pitchMatchingSession.referenceFrequency ?? 440.0,
            onFrequencyChange: { frequency in
                pitchMatchingSession.adjustFrequency(frequency)
            },
            onRelease: { frequency in
                pitchMatchingSession.commitResult(userFrequency: frequency)
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
            pitchMatchingSession.startPitchMatching()
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

// MARK: - Environment Key for PitchMatchingSession

extension EnvironmentValues {
    @Entry var pitchMatchingSession: PitchMatchingSession = {
        return PitchMatchingSession(
            notePlayer: MockNotePlayerForPitchMatchingPreview(),
            profile: PerceptualProfile(),
            observers: []
        )
    }()
}

// MARK: - Preview Mocks

private final class MockNotePlayerForPitchMatchingPreview: NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        MockPlaybackHandleForPitchMatchingPreview()
    }

    func stopAll() async throws {}
}

private final class MockPlaybackHandleForPitchMatchingPreview: PlaybackHandle {
    func stop() async throws {}
    func adjustFrequency(_ frequency: Frequency) async throws {}
}

// MARK: - Previews

#Preview {
    NavigationStack {
        PitchMatchingScreen()
    }
}

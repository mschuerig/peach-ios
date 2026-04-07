import SwiftUI

struct PitchMatchingScreen: View {
    let isIntervalMode: Bool

    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.userSettings) private var userSettings
    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var intervals: Set<DirectedInterval> {
        isIntervalMode ? userSettings.intervals : [.prime]
    }

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var trainingDiscipline: TrainingDisciplineID {
        Self.trainingDiscipline(for: intervals)
    }

    var body: some View {
        VStack(spacing: 8) {
            statsHeader

            PitchSlider(
                isHorizontal: isCompactHeight,
                isActive: pitchMatchingSession.canAdjustPitch,
                onValueChange: { value in
                    pitchMatchingSession.clearKeyboardPitchValue()
                    pitchMatchingSession.adjustPitch(value)
                },
                onCommit: { value in
                    pitchMatchingSession.clearKeyboardPitchValue()
                    pitchMatchingSession.commitPitch(value)
                },
                externalValue: pitchMatchingSession.midiPitchBendValue ?? pitchMatchingSession.keyboardPitchValue
            )
            .padding()
        }
        .onKeyPress(.upArrow) {
            pitchMatchingSession.adjustPitchByStep(up: true) ? .handled : .ignored
        }
        .onKeyPress(.downArrow) {
            pitchMatchingSession.adjustPitchByStep(up: false) ? .handled : .ignored
        }
        .onKeyPress(.space) {
            pitchMatchingSession.commitCurrentPitch() ? .handled : .ignored
        }
        .onKeyPress(.return) {
            pitchMatchingSession.commitCurrentPitch() ? .handled : .ignored
        }
        .trainingScreen(
            helpSections: HelpContent.pitchMatching,
            destination: .pitchMatching(isIntervalMode: isIntervalMode)
        ) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                Text(isIntervalMode ? String(localized: "Intervals") : String(localized: "Pitch"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isIntervalMode
                ? String(localized: "Intervals \u{2013} Match")
                : String(localized: "Pitch \u{2013} Match"))
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                TrainingStatsView(
                    latestValue: pitchMatchingSession.lastResult.map { Cents($0.userCentError.magnitude) },
                    sessionBest: pitchMatchingSession.sessionBestCentError,
                    trend: progressTimeline.trend(for: trainingDiscipline)
                )

                if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(interval.displayName)
                            .font(.title3)
                        Text(pitchMatchingSession.sessionTuningSystem.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Target interval: \(interval.displayName), \(pitchMatchingSession.sessionTuningSystem.displayName)"))
                }
            }

            Spacer()

            PitchMatchingFeedbackIndicator(
                centError: pitchMatchingSession.lastResult?.userCentError
            )
            .opacity(pitchMatchingSession.state == .showingFeedback ? 1 : 0)
            .accessibilityHidden(pitchMatchingSession.state != .showingFeedback)
            .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchMatchingSession.state == .showingFeedback)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    static func trainingDiscipline(for intervals: Set<DirectedInterval>) -> TrainingDisciplineID {
        intervals == [.prime] ? .unisonPitchMatching : .intervalPitchMatching
    }

    // MARK: - Layout Parameters (extracted for testability)

    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        PitchMatchingScreen(isIntervalMode: false)
    }
    .previewEnvironment()
}

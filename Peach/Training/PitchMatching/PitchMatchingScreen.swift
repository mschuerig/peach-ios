import SwiftUI

struct PitchMatchingScreen: View {
    let isIntervalMode: Bool

    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.userSettings) private var userSettings
    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear a **reference note**. Your goal is to match its pitch by sliding to the exact same frequency. The closer you get, the better your ear is becoming.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "**Touch** the slider to hear your note, then **drag** to adjust the pitch. When you think you've matched the reference, **release** the slider to lock in your answer.\n\nYou can also use a **MIDI controller** — move the pitch bend wheel to adjust the pitch continuously.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each attempt, you'll see how many **cents** off you were. A smaller number means a closer match — zero would be perfect. Use the feedback to fine-tune your listening.")
        ),
        HelpSection(
            title: String(localized: "Intervals"),
            body: String(localized: "In interval mode, your target pitch is a specific **musical interval** away from the reference note. Instead of matching the same note, you're matching a note that's a certain distance above or below it.")
        ),
    ]

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
            helpSections: Self.helpSections,
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

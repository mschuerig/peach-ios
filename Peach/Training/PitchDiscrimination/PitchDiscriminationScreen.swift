import SwiftUI

struct PitchDiscriminationScreen: View {
    let isIntervalMode: Bool

    @Environment(\.pitchDiscriminationSession) private var pitchDiscriminationSession
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
            answerButtonsGroup
        }
        .padding()
        .onKeyPress(.upArrow, phases: .down) { _ in
            pitchDiscriminationSession.handleAnswer(isHigher: true) ? .handled : .ignored
        }
        .onKeyPress(.downArrow, phases: .down) { _ in
            pitchDiscriminationSession.handleAnswer(isHigher: false) ? .handled : .ignored
        }
        .onKeyPress(characters: .letters, phases: .down) { keyPress in
            guard !keyPress.modifiers.contains(.command),
                  !keyPress.modifiers.contains(.control),
                  !keyPress.modifiers.contains(.option) else { return .ignored }
            return pitchDiscriminationSession.handleShortcutKey(keyPress.characters) ? .handled : .ignored
        }
        .trainingScreen(
            helpSections: HelpContent.pitchDiscrimination,
            destination: .pitchDiscrimination(isIntervalMode: isIntervalMode)
        ) {
            HStack(spacing: 6) {
                Image(systemName: "ear")
                Text(isIntervalMode ? String(localized: "Intervals") : String(localized: "Pitch"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isIntervalMode
                ? String(localized: "Intervals \u{2013} Compare")
                : String(localized: "Pitch \u{2013} Compare"))
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                TrainingStatsView(
                    latestValue: pitchDiscriminationSession.lastCompletedCentDifference,
                    sessionBest: pitchDiscriminationSession.sessionBestCentDifference,
                    trend: progressTimeline.trend(for: trainingDiscipline)
                )

                if pitchDiscriminationSession.isIntervalMode, let interval = pitchDiscriminationSession.currentInterval {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(interval.displayName)
                            .font(.title3)
                        Text(pitchDiscriminationSession.sessionTuningSystem.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Target interval: \(interval.displayName), \(pitchDiscriminationSession.sessionTuningSystem.displayName)"))
                }
            }

            Spacer()

            PitchDiscriminationFeedbackIndicator(
                isCorrect: pitchDiscriminationSession.isLastAnswerCorrect
            )
            .opacity(pitchDiscriminationSession.showFeedback ? 1 : 0)
            .accessibilityHidden(!pitchDiscriminationSession.showFeedback)
            .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchDiscriminationSession.showFeedback)
        }
        .padding(.horizontal)
    }

    private var answerButtonsGroup: some View {
        Group {
            if isCompactHeight {
                HStack(spacing: 8) {
                    answerButton(direction: .higher)
                    answerButton(direction: .lower)
                }
            } else {
                VStack(spacing: 8) {
                    answerButton(direction: .higher)
                    answerButton(direction: .lower)
                }
            }
        }
    }

    // MARK: - Button Views

    private enum AnswerDirection {
        case higher, lower

        var isHigher: Bool { self == .higher }

        var iconName: String {
            switch self {
            case .higher: "arrow.up.circle.fill"
            case .lower: "arrow.down.circle.fill"
            }
        }

        var label: LocalizedStringKey {
            switch self {
            case .higher: "Higher"
            case .lower: "Lower"
            }
        }
    }

    private func answerButton(direction: AnswerDirection) -> some View {
        Button {
            pitchDiscriminationSession.handleAnswer(isHigher: direction.isHigher)
        } label: {
            VStack(spacing: 12) {
                Image(systemName: direction.iconName)
                    .font(.system(size: Self.buttonIconSize(isCompact: isCompactHeight)))
                Text(direction.label)
                    .font(Self.buttonTextFont(isCompact: isCompactHeight))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: Self.buttonMinHeight(isCompact: isCompactHeight))
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .disabled(!pitchDiscriminationSession.canAcceptAnswer)
        .accessibilityLabel(direction.label)
    }

    // MARK: - Layout Parameters (extracted for testability)

    static func buttonIconSize(isCompact: Bool) -> CGFloat {
        isCompact ? 60 : 80
    }

    static func buttonMinHeight(isCompact: Bool) -> CGFloat {
        isCompact ? 120 : 200
    }

    static func buttonTextFont(isCompact: Bool) -> Font {
        isCompact ? .title2 : .title
    }

    // MARK: - Helpers

    static func trainingDiscipline(for intervals: Set<DirectedInterval>) -> TrainingDisciplineID {
        intervals == [.prime] ? .unisonPitchDiscrimination : .intervalPitchDiscrimination
    }

    /// Returns the animation for feedback indicator transitions
    /// Returns nil when Reduce Motion is enabled (instant show/hide)
    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        PitchDiscriminationScreen(isIntervalMode: false)
    }
    .previewEnvironment()
}

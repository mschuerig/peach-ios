import SwiftUI

struct TimingOffsetDetectionScreen: View {
    @Environment(\.timingOffsetDetectionSession) private var session
    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 8) {
            statsHeader
            TimingDotView(litCount: session.litDotCount)
                .padding(.vertical, 8)
            answerButtonsGroup
        }
        .padding()
        .onKeyPress(.leftArrow, phases: .down) { _ in
            session.handleAnswer(direction: .early) ? .handled : .ignored
        }
        .onKeyPress(.rightArrow, phases: .down) { _ in
            session.handleAnswer(direction: .late) ? .handled : .ignored
        }
        .onKeyPress(characters: .letters, phases: .down) { keyPress in
            guard !keyPress.modifiers.contains(.command),
                  !keyPress.modifiers.contains(.control),
                  !keyPress.modifiers.contains(.option) else { return .ignored }
            return session.handleShortcutKey(keyPress.characters) ? .handled : .ignored
        }
        .trainingScreen(
            helpSections: HelpContent.timingOffsetDetection,
            destination: .timingOffsetDetection
        ) {
            HStack(spacing: 6) {
                Image(systemName: "metronome")
                Text(String(localized: "Rhythm"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Rhythm \u{2013} Compare"))
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            TimingStatsView(
                latestValue: session.lastCompletedOffsetPercentage,
                latestMs: session.lastCompletedOffsetMs,
                sessionBest: session.sessionBestOffsetPercentage,
                bestMs: session.sessionBestOffsetMs,
                trend: progressTimeline.trend(for: .timingOffsetDetection)
            )

            Spacer()

            TimingOffsetDetectionFeedbackView(
                isCorrect: session.isLastAnswerCorrect,
                offsetPercentage: session.lastCompletedOffsetPercentage
            )
            .opacity(session.showFeedback ? 1 : 0)
            .accessibilityHidden(!session.showFeedback)
            .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: session.showFeedback)
        }
        .padding(.horizontal)
    }

    private var answerButtonsGroup: some View {
        HStack(spacing: 8) {
            answerButton(direction: .early)
            answerButton(direction: .late)
        }
    }

    // MARK: - Button Views

    private enum AnswerDirection {
        case early, late

        var timingDirection: TimingDirection {
            switch self {
            case .early: .early
            case .late: .late
            }
        }

        var iconName: String {
            switch self {
            case .early: "arrow.left"
            case .late: "arrow.right"
            }
        }

        var label: LocalizedStringKey {
            switch self {
            case .early: "Early"
            case .late: "Late"
            }
        }
    }

    private func answerButton(direction: AnswerDirection) -> some View {
        Button {
            session.handleAnswer(direction: direction.timingDirection)
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
        .disabled(!session.canAcceptAnswer)
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

    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        TimingOffsetDetectionScreen()
    }
    .previewEnvironment()
}

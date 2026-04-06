import SwiftUI

struct ContinuousRhythmMatchingScreen: View {
    @Environment(\.continuousRhythmMatchingSession) private var session
    @Environment(\.userSettings) private var userSettings
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTouchActive = false

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "A continuous stream of 16th notes plays — fill the gap by tapping at the right moment.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Tap the **Tap** button when the outlined note should sound. The bold first dot marks beat one.\n\nYou can also play any key on a connected **MIDI keyboard** instead of tapping.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each hit, an arrow shows whether you tapped early (←) or late (→) with the offset in milliseconds. The color indicates accuracy: **green** (precise), **yellow** (moderate), **red** (erratic). Stats update after each trial of 16 cycles.")
        ),
    ]

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 8) {
            statsHeader
            ContinuousRhythmMatchingDotView(
                activeStep: session.currentStep,
                gapPosition: session.currentGapPosition
            )
            .padding(.vertical, 8)
            tapButton
        }
        .padding()
        .onKeyPress(.space, phases: .down) { _ in
            session.handleTap()
            return .handled
        }
        .onKeyPress(.return, phases: .down) { _ in
            session.handleTap()
            return .handled
        }
        .trainingScreen(
            helpSections: Self.helpSections,
            destination: .continuousRhythmMatching
        ) {
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                Text(String(localized: "Rhythm"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Rhythm \u{2013} Fill the Gap"))
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let result = session.lastTrialResult,
                   let meanOffset = result.meanOffsetPercentage,
                   let meanMs = result.meanOffsetMs {
                    Text(String(localized: "Mean offset: \(TimingStatsView.percentageText(meanOffset, ms: meanMs))"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RhythmTimingFeedbackIndicator(
                offsetMs: session.lastHitOffsetMs,
                tempo: userSettings.tempoBPM
            )
            .opacity(session.showFeedback ? 1 : 0)
            .accessibilityHidden(!session.showFeedback)
            .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: session.showFeedback)

            Text(Self.cycleProgressText(session.cyclesInCurrentTrial))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal)
    }

    // MARK: - Animation

    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    private var tapButton: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: Self.buttonIconSize(isCompact: isCompactHeight)))
            Text("Tap")
                .font(Self.buttonTextFont(isCompact: isCompactHeight))
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: Self.buttonMinHeight(isCompact: isCompactHeight))
        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
        .opacity(isTouchActive ? 0.7 : 1.0)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isTouchActive else { return }
                    isTouchActive = true
                    session.handleTap()
                }
                .onEnded { _ in
                    isTouchActive = false
                }
        )
        .onAppear { isTouchActive = false }
        .accessibilityLabel("Tap")
        .accessibilityHint(String(localized: "Tap to fill the gap in the rhythm"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { session.handleTap() }
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

    // MARK: - Formatting

    static func cycleProgressText(_ count: Int) -> String {
        "\(count)/\(ContinuousRhythmMatchingSession.cyclesPerTrial)"
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        ContinuousRhythmMatchingScreen()
    }
    .previewEnvironment()
}

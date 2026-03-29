import SwiftUI

struct RhythmOffsetDetectionScreen: View {
    @Environment(\.rhythmOffsetDetectionSession) private var session
    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.trainingLifecycle) private var lifecycle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Environment(\.dismiss) private var dismiss

    @FocusState private var isFocused: Bool
    @State private var showHelpSheet = false

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear four clicks — a short rhythmic pattern. The **third** click may arrive slightly **early** or **late**. Your job is to decide which one it was.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Once the pattern finishes, the **Early** and **Late** buttons become active. Tap the one that matches what you heard.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each answer you'll see a **checkmark** (correct) or **X** (incorrect), along with the current difficulty as a percentage.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "The percentage shows how far off-beat the last click was — a smaller number means a harder challenge. Your **session best** tracks the smallest offset you answered correctly.")
        ),
    ]

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 8) {
            statsHeader
            RhythmDotView(litCount: session.litDotCount)
                .padding(.vertical, 8)
            answerButtonsGroup
        }
        .padding()
        .inlineNavigationBarTitle()
        .toolbar { toolbarContent }
        .sheet(isPresented: $showHelpSheet) { helpSheetContent }
        .onChange(of: showHelpSheet) { _, isShowing in
            if isShowing {
                lifecycle.helpSheetPresented()
            } else {
                isFocused = true
                lifecycle.helpSheetDismissed()
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
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
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onAppear {
            isFocused = true
            lifecycle.trainingScreenAppeared(destination: .rhythmOffsetDetection)
        }
        .onDisappear {
            lifecycle.trainingScreenDisappeared()
        }
        .trainingIdleOverlay()
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            RhythmStatsView(
                latestValue: session.lastCompletedOffsetPercentage,
                latestMs: session.lastCompletedOffsetMs,
                sessionBest: session.sessionBestOffsetPercentage,
                bestMs: session.sessionBestOffsetMs,
                trend: progressTimeline.trend(for: .rhythmOffsetDetection)
            )

            Spacer()

            RhythmOffsetDetectionFeedbackView(
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Image(systemName: "metronome")
                Text(String(localized: "Rhythm"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Rhythm \u{2013} Compare"))
        }
        ToolbarItem(placement: .automatic) {
            HStack(spacing: 20) {
                Button {
                    showHelpSheet = true
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }

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

    private var helpSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HelpContentView(sections: Self.helpSections)
                }
                .padding()
            }
            .navigationTitle(String(localized: "Training Help"))
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        showHelpSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Button Views

    private enum AnswerDirection {
        case early, late

        var rhythmDirection: RhythmDirection {
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
            session.handleAnswer(direction: direction.rhythmDirection)
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
        RhythmOffsetDetectionScreen()
    }
    .previewEnvironment()
}

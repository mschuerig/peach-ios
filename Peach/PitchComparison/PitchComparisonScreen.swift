import SwiftUI
import os

struct PitchComparisonScreen: View {
    let intervals: Set<DirectedInterval>

    /// Training session injected via environment
    @Environment(\.pitchComparisonSession) private var pitchComparisonSession

    /// Progress timeline for accuracy summary
    @Environment(\.progressTimeline) private var progressTimeline

    /// Whether the user has enabled Reduce Motion in system accessibility settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Vertical size class: .compact in landscape iPhone, .regular in portrait and iPad
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showHelpSheet = false

    /// Logger for debugging lifecycle events
    private let logger = Logger(subsystem: "com.peach.app", category: "PitchComparisonScreen")

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "Two notes play one after the other. Your job is to decide: was the **second note higher or lower** than the first? The closer the notes are, the harder it gets — and the sharper your ear becomes.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "After both notes have played, the **Higher** and **Lower** buttons become active. Tap the one that matches what you heard. You can't answer while the notes are still playing.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each answer you'll see a brief **checkmark** (correct) or **X** (incorrect). Use this to calibrate your listening — over time, you'll notice patterns in what you get right.")
        ),
        HelpSection(
            title: String(localized: "Difficulty"),
            body: String(localized: "The number at the top shows the **cent difference** between the two notes — a smaller number means a harder comparison. Your **session best** tracks the smallest difference you answered correctly.")
        ),
        HelpSection(
            title: String(localized: "Intervals"),
            body: String(localized: "In interval mode, the two notes are separated by a specific **musical interval** (like a fifth or an octave) instead of a small pitch difference. You still decide which note is higher — but now you're training your sense of musical distance.")
        ),
    ]

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var trainingMode: TrainingMode {
        Self.trainingMode(for: intervals)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    TrainingStatsView(
                        latestValue: pitchComparisonSession.lastCompletedCentDifference,
                        sessionBest: pitchComparisonSession.sessionBestCentDifference,
                        trend: progressTimeline.trend(for: trainingMode)
                    )

                    if pitchComparisonSession.isIntervalMode, let interval = pitchComparisonSession.currentInterval {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(interval.displayName)
                                .font(.title3)
                            Text(pitchComparisonSession.sessionTuningSystem.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(localized: "Target interval: \(interval.displayName), \(pitchComparisonSession.sessionTuningSystem.displayName)"))
                    }
                }

                Spacer()

                PitchComparisonFeedbackIndicator(
                    isCorrect: pitchComparisonSession.isLastAnswerCorrect
                )
                .opacity(pitchComparisonSession.showFeedback ? 1 : 0)
                .accessibilityHidden(!pitchComparisonSession.showFeedback)
                .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchComparisonSession.showFeedback)
            }
            .padding(.horizontal)

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
        .padding()
        .navigationTitle("Hear & Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
        .sheet(isPresented: $showHelpSheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        HelpContentView(sections: Self.helpSections)
                    }
                    .padding()
                }
                .navigationTitle(String(localized: "Training Help"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Done")) {
                            showHelpSheet = false
                        }
                    }
                }
            }
        }
        .onChange(of: showHelpSheet) { _, isShowing in
            if isShowing {
                logger.info("Help sheet shown - stopping training")
                pitchComparisonSession.stop()
            } else {
                logger.info("Help sheet dismissed - restarting training")
                pitchComparisonSession.start(intervals: intervals)
            }
        }
        .onAppear {
            logger.info("PitchComparisonScreen appeared - starting training")
            pitchComparisonSession.start(intervals: intervals)
        }
        .onDisappear {
            logger.info("PitchComparisonScreen disappeared - stopping training")
            pitchComparisonSession.stop()
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
            pitchComparisonSession.handleAnswer(isHigher: direction.isHigher)
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
        .disabled(!buttonsEnabled)
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

    static func trainingMode(for intervals: Set<DirectedInterval>) -> TrainingMode {
        intervals == [.prime] ? .unisonPitchComparison : .intervalPitchComparison
    }

    /// Buttons are enabled when in playingNote2 or awaitingAnswer states
    private var buttonsEnabled: Bool {
        pitchComparisonSession.state == .playingNote2 || pitchComparisonSession.state == .awaitingAnswer
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
        PitchComparisonScreen(intervals: [DirectedInterval.prime])
    }
}

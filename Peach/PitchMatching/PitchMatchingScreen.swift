import SwiftUI

struct PitchMatchingScreen: View {
    let isIntervalMode: Bool

    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.userSettings) private var userSettings
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
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onAppear {
            isFocused = true
            lifecycle.trainingScreenAppeared(destination: .pitchMatching(isIntervalMode: isIntervalMode))
        }
        .onDisappear {
            lifecycle.trainingScreenDisappeared()
        }
        .trainingIdleOverlay()
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                Text(isIntervalMode ? String(localized: "Intervals") : String(localized: "Pitch"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isIntervalMode
                ? String(localized: "Intervals \u{2013} Match")
                : String(localized: "Pitch \u{2013} Match"))
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

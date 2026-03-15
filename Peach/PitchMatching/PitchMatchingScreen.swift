import SwiftUI
import os

struct PitchMatchingScreen: View {
    let isIntervalMode: Bool

    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.userSettings) private var userSettings
    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showHelpSheet = false

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingScreen")

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear a **reference note**. Your goal is to match its pitch by sliding to the exact same frequency. The closer you get, the better your ear is becoming.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "**Touch** the slider to hear your note, then **drag** to adjust the pitch. When you think you've matched the reference, **release** the slider to lock in your answer.")
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

    private var trainingMode: TrainingMode {
        Self.trainingMode(for: intervals)
    }

    var body: some View {
        VStack(spacing: 8) {
            statsHeader

            PitchSlider(
                isHorizontal: isCompactHeight,
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
        .navigationTitle("Tune & Match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showHelpSheet) { helpSheetContent }
        .onChange(of: showHelpSheet) { _, isShowing in
            if isShowing {
                logger.info("Help sheet shown - stopping pitch matching")
                pitchMatchingSession.stop()
            } else {
                logger.info("Help sheet dismissed - restarting pitch matching")
                pitchMatchingSession.start(settings: .from(userSettings, intervals: intervals))
            }
        }
        .onAppear {
            logger.info("PitchMatchingScreen appeared - (re)starting pitch matching")
            pitchMatchingSession.stop()
            pitchMatchingSession.start(settings: .from(userSettings, intervals: intervals))
        }
        .onDisappear {
            logger.info("PitchMatchingScreen disappeared - stopping pitch matching")
            pitchMatchingSession.stop()
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                TrainingStatsView(
                    latestValue: pitchMatchingSession.lastResult.map { Cents($0.userCentError.magnitude) },
                    sessionBest: pitchMatchingSession.sessionBestCentError,
                    trend: progressTimeline.trend(for: trainingMode)
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

    private var helpSheetContent: some View {
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

    // MARK: - Helpers

    static func trainingMode(for intervals: Set<DirectedInterval>) -> TrainingMode {
        intervals == [.prime] ? .unisonMatching : .intervalMatching
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
}

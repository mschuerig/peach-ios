import SwiftUI
import os

struct PitchMatchingScreen: View {
    let intervals: Set<DirectedInterval>

    @Environment(\.pitchMatchingSession) private var pitchMatchingSession
    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showHelpSheet = false

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingScreen")

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear a **reference note**. Your goal is to match its pitch by sliding to the exact same frequency. The closer you get, the better your ear is becoming.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "**Touch** the slider to hear your note, then **drag** up or down to adjust the pitch. When you think you've matched the reference, **release** the slider to lock in your answer.")
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

    private var trainingMode: TrainingMode {
        Self.trainingMode(for: intervals)
    }

    var body: some View {
        VStack(spacing: 8) {
            TrainingStatsView(
                latestValue: pitchMatchingSession.lastResult.map { Cents($0.userCentError.magnitude) },
                sessionBest: pitchMatchingSession.sessionBestCentError,
                trend: progressTimeline.trend(for: trainingMode)
            )
            .padding(.horizontal)

            if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
                VStack(spacing: 2) {
                    Text(interval.displayName)
                        .font(.title3)
                    Text(pitchMatchingSession.sessionTuningSystem.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Target interval: \(interval.displayName), \(pitchMatchingSession.sessionTuningSystem.displayName)"))
            }

            PitchMatchingFeedbackIndicator(
                centError: pitchMatchingSession.lastResult?.userCentError
            )
            .frame(height: Self.feedbackIndicatorHeight)
            .opacity(pitchMatchingSession.state == .showingFeedback ? 1 : 0)
            .accessibilityHidden(pitchMatchingSession.state != .showingFeedback)
            .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchMatchingSession.state == .showingFeedback)

            VerticalPitchSlider(
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
                logger.info("Help sheet shown - stopping pitch matching")
                pitchMatchingSession.stop()
            } else {
                logger.info("Help sheet dismissed - restarting pitch matching")
                pitchMatchingSession.start(intervals: intervals)
            }
        }
        .onAppear {
            logger.info("PitchMatchingScreen appeared - starting pitch matching")
            pitchMatchingSession.start(intervals: intervals)
        }
        .onDisappear {
            logger.info("PitchMatchingScreen disappeared - stopping pitch matching")
            pitchMatchingSession.stop()
        }
    }

    // MARK: - Helpers

    static func trainingMode(for intervals: Set<DirectedInterval>) -> TrainingMode {
        intervals == [.prime] ? .unisonMatching : .intervalMatching
    }

    // MARK: - Layout Parameters (extracted for testability)

    static let feedbackIndicatorHeight: CGFloat = 130

    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        PitchMatchingScreen(intervals: [DirectedInterval.prime])
    }
}

import SwiftUI
import os

struct ContinuousRhythmMatchingScreen: View {
    @Environment(\.continuousRhythmMatchingSession) private var session
    @Environment(\.userSettings) private var userSettings
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showHelpSheet = false

    private let logger = Logger(subsystem: "com.peach.app", category: "ContinuousRhythmMatchingScreen")

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "A continuous stream of 16th notes plays — fill the gap by tapping at the right moment.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "Tap the **Tap** button when the outlined note should sound. The bold first dot marks beat one.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "The gap dot briefly changes color after each hit: **green** (close), **yellow** (moderate), **red** (far). Stats update after each trial of 16 cycles.")
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
                gapPosition: session.currentGapPosition,
                feedbackPercentage: session.showFeedback ? session.lastHitOffsetPercentage : nil
            )
            .padding(.vertical, 8)
            tapButton
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showHelpSheet) { helpSheetContent }
        .onChange(of: showHelpSheet) { _, isShowing in
            if isShowing {
                logger.info("Help sheet shown - stopping training")
                session.stop()
            } else {
                logger.info("Help sheet dismissed - restarting training")
                session.start(settings: .from(userSettings))
            }
        }
        .onAppear {
            logger.info("ContinuousRhythmMatchingScreen appeared - (re)starting training")
            session.stop()
            session.start(settings: .from(userSettings))
        }
        .onDisappear {
            logger.info("ContinuousRhythmMatchingScreen disappeared - stopping training")
            session.stop()
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let result = session.lastTrialResult,
                   let meanOffset = result.meanOffsetPercentage,
                   let meanMs = result.meanOffsetMs {
                    Text(String(localized: "Mean offset: \(RhythmStatsView.percentageText(meanOffset, ms: meanMs))"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Text(Self.cycleProgressText(session.cyclesInCurrentTrial))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal)
    }

    private var tapButton: some View {
        Button {
            session.handleTap()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "hand.tap")
                    .font(.system(size: Self.buttonIconSize(isCompact: isCompactHeight)))
                Text("Tap")
                    .font(Self.buttonTextFont(isCompact: isCompactHeight))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: Self.buttonMinHeight(isCompact: isCompactHeight))
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .accessibilityLabel("Tap")
        .accessibilityHint(String(localized: "Tap to fill the gap in the rhythm"))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                Text(String(localized: "Rhythm"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Rhythm \u{2013} Fill"))
        }
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
}

import SwiftUI
import os

struct RhythmMatchingScreen: View {
    @Environment(\.rhythmMatchingSession) private var session
    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.userSettings) private var userSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showHelpSheet = false

    private let logger = Logger(subsystem: "com.peach.app", category: "RhythmMatchingScreen")

    static let helpSections: [HelpSection] = [
        HelpSection(
            title: String(localized: "Goal"),
            body: String(localized: "You'll hear 3 clicks — then you tap the 4th. Your goal is to land exactly on the beat.")
        ),
        HelpSection(
            title: String(localized: "Controls"),
            body: String(localized: "The **Tap** button is always active. Tap it at the moment you think the 4th click should fall.")
        ),
        HelpSection(
            title: String(localized: "Feedback"),
            body: String(localized: "After each tap, an arrow and percentage show how close you were — **early** (left arrow) or **late** (right arrow). The color indicates precision: **green** (close), **yellow** (moderate), **red** (far).")
        ),
    ]

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    private var fourthDotColor: Color? {
        guard session.showFeedback, let percentage = session.lastUserOffsetPercentage else {
            return nil
        }
        return RhythmMatchingDotView.dotColor(forPercentage: percentage)
    }

    var body: some View {
        VStack(spacing: 8) {
            statsHeader
            RhythmMatchingDotView(litCount: session.litDotCount, fourthDotColor: fourthDotColor)
                .padding(.vertical, 8)
            tapButton
        }
        .padding()
        .navigationTitle("Rhythm")
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
            logger.info("RhythmMatchingScreen appeared - (re)starting training")
            session.stop()
            session.start(settings: .from(userSettings))
        }
        .onDisappear {
            logger.info("RhythmMatchingScreen disappeared - stopping training")
            session.stop()
        }
    }

    // MARK: - Subviews

    private var statsHeader: some View {
        HStack(alignment: .top) {
            RhythmStatsView(
                latestValue: session.lastUserOffsetPercentage.map { abs($0) },
                latestMs: session.lastUserOffsetMs,
                sessionBest: nil,
                bestMs: nil,
                trend: progressTimeline.trend(for: .rhythmMatching)
            )

            Spacer()

            RhythmMatchingFeedbackView(offsetPercentage: session.lastUserOffsetPercentage)
                .opacity(session.showFeedback ? 1 : 0)
                .accessibilityHidden(!session.showFeedback)
                .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: session.showFeedback)
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
        .accessibilityHint(String(localized: "Tap at the correct moment to match the rhythm"))
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

    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        RhythmMatchingScreen()
    }
}

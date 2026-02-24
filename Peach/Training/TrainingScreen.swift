import SwiftUI
import os

struct TrainingScreen: View {
    /// Training session injected via environment
    @Environment(\.trainingSession) private var trainingSession

    /// Whether the user has enabled Reduce Motion in system accessibility settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Vertical size class: .compact in landscape iPhone, .regular in portrait and iPad
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Logger for debugging lifecycle events
    private let logger = Logger(subsystem: "com.peach.app", category: "TrainingScreen")

    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 8) {
            if let difficulty = trainingSession.currentDifficulty {
                DifficultyDisplayView(
                    currentDifficulty: difficulty,
                    sessionBest: trainingSession.sessionBestCentDifference
                )
                .padding(.horizontal)
            }

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
        .overlay {
            if trainingSession.showFeedback {
                FeedbackIndicator(
                    isCorrect: trainingSession.isLastAnswerCorrect,
                    iconSize: Self.feedbackIconSize(isCompact: isCompactHeight)
                )
                .transition(.opacity)
            }
        }
        .animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: trainingSession.showFeedback)
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 20) {
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
        .onAppear {
            logger.info("TrainingScreen appeared - starting training")
            trainingSession.startTraining()
        }
        .onDisappear {
            logger.info("TrainingScreen disappeared - stopping training")
            trainingSession.stop()
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
            trainingSession.handleAnswer(isHigher: direction.isHigher)
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

    static func feedbackIconSize(isCompact: Bool) -> CGFloat {
        isCompact ? 70 : FeedbackIndicator.defaultIconSize
    }

    // MARK: - Helpers

    /// Buttons are enabled when in playingNote2 or awaitingAnswer states
    private var buttonsEnabled: Bool {
        trainingSession.state == .playingNote2 || trainingSession.state == .awaitingAnswer
    }

    /// Returns the animation for feedback indicator transitions
    /// Returns nil when Reduce Motion is enabled (instant show/hide)
    static func feedbackAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }
}

// MARK: - Environment Key for TrainingSession

extension EnvironmentValues {
    @Entry var trainingSession: TrainingSession = {
        let dataStore = MockDataStoreForPreview()
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()
        let hapticManager = MockHapticFeedbackManager()
        let observers: [ComparisonObserver] = [dataStore, profile, hapticManager]
        return TrainingSession(
            notePlayer: MockNotePlayerForPreview(),
            strategy: strategy,
            profile: profile,
            observers: observers
        )
    }()
}

// MARK: - Preview Mocks

private final class MockNotePlayerForPreview: NotePlayer {
    func play(frequency: Double, duration: TimeInterval, velocity: UInt8) async throws {
        try await Task.sleep(for: .milliseconds(100))
    }

    func stop() async throws {}
}

private final class MockDataStoreForPreview: ComparisonRecordStoring, ComparisonObserver {
    func save(_ record: ComparisonRecord) throws {}
    func fetchAll() throws -> [ComparisonRecord] { [] }

    func comparisonCompleted(_ completed: CompletedComparison) {
        // No-op for preview
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        TrainingScreen()
    }
}

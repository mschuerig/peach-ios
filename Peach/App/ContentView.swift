import SwiftUI
import os

struct ContentView: View {
    /// Training session injected from app
    @Environment(\.comparisonSession) private var comparisonSession

    /// Pitch matching session injected from app
    @Environment(\.pitchMatchingSession) private var pitchMatchingSession

    /// Scene phase for app lifecycle monitoring (Story 3.4)
    @Environment(\.scenePhase) private var scenePhase

    /// Navigation path for programmatic navigation control
    @State private var navigationPath: [NavigationDestination] = []

    /// Track previous scene phase to detect transitions
    @State private var previousScenePhase: ScenePhase?

    /// Logger for lifecycle events
    private let logger = Logger(subsystem: "com.peach.app", category: "ContentView")

    var body: some View {
        NavigationStack(path: $navigationPath) {
            StartScreen()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            logger.debug("Scene phase changed: \(String(describing: oldPhase)) → \(String(describing: newPhase))")

            // Handle app backgrounding
            if newPhase == .background {
                handleAppBackgrounding()
            }

            // Handle app foregrounding
            if oldPhase == .background && newPhase == .active {
                handleAppForegrounding()
            }

            previousScenePhase = newPhase
        }
    }

    /// Handles app entering background state
    private func handleAppBackgrounding() {
        logger.info("App backgrounded - stopping training if active")

        // Stop training if it's active (AC#2)
        // This will stop audio and discard any incomplete comparison
        if comparisonSession.state != .idle {
            logger.info("Training was active (state: \(String(describing: comparisonSession.state))) - stopping")
            comparisonSession.stop()
        } else {
            logger.info("Training was already idle - no action needed")
        }

        // Stop pitch matching if it's active (Story 16.3)
        if pitchMatchingSession.state != .idle {
            logger.info("Pitch matching was active (state: \(String(describing: pitchMatchingSession.state))) - stopping")
            pitchMatchingSession.stop()
        }

        // Note: We DON'T clear navigation here - user stays on current screen while backgrounded
    }

    /// Handles app returning to foreground from background
    private func handleAppForegrounding() {
        logger.info("App foregrounded after being backgrounded")

        // Pop navigation to Start Screen (AC#3)
        // This ensures users return to a known, clean state
        if !navigationPath.isEmpty {
            logger.info("Clearing navigation path (was: \(navigationPath)) - returning to Start Screen")
            navigationPath.removeAll()
        } else {
            logger.info("Navigation path already empty - user on Start Screen")
        }
    }
}

#Preview {
    ContentView()
}

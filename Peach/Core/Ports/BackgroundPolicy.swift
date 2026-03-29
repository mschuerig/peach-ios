/// Determines whether the app should stop training when the scene phase changes.
///
/// iOS policy: stop only on background (inactive is transient, e.g. notification center pull-down).
/// macOS policy: stop on background or inactive (app switching triggers inactive immediately).
protocol BackgroundPolicy {
    /// Returns `true` if training should stop for the given scene phase transition.
    func shouldStopTraining(newPhase: AppScenePhase) -> Bool

    /// Returns `true` if navigation should be cleared when returning to the given phase.
    func shouldClearNavigation(oldPhase: AppScenePhase, newPhase: AppScenePhase) -> Bool
}

/// Platform-agnostic representation of SwiftUI's `ScenePhase`.
///
/// Avoids importing SwiftUI in Core/ while preserving the three-state semantics.
enum AppScenePhase {
    case active
    case inactive
    case background
}

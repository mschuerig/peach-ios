/// Determines platform-specific training session lifecycle behavior.
///
/// iOS policy: stop only on background (inactive is transient), auto-start training on navigate/return.
/// macOS policy: stop on background or inactive (app switching), require explicit start/stop.
protocol BackgroundPolicy {
    /// Returns `true` if training should stop for the given scene phase transition.
    func shouldStopTraining(newPhase: AppScenePhase) -> Bool

    /// Whether training starts automatically when navigating to a training screen
    /// or returning from background. iOS: true. macOS: false (explicit start required).
    var shouldAutoStartTraining: Bool { get }
}

/// Platform-agnostic representation of SwiftUI's `ScenePhase`.
///
/// Avoids importing SwiftUI in Core/ while preserving the three-state semantics.
enum AppScenePhase {
    case active
    case inactive
    case background
}

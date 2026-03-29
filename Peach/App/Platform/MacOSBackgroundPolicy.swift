/// macOS background policy: stop training on background or inactive.
///
/// On macOS, switching to another app triggers `.inactive` immediately,
/// so training stops on app switch. Training requires explicit start/stop
/// via button, menu item, or keyboard shortcut.
struct MacOSBackgroundPolicy: BackgroundPolicy {
    func shouldStopTraining(newPhase: AppScenePhase) -> Bool {
        newPhase == .background || newPhase == .inactive
    }

    var shouldAutoStartTraining: Bool { false }
}

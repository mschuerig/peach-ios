/// macOS background policy: stop training on background or inactive.
///
/// On macOS, switching to another app triggers `.inactive` immediately
/// (no transient notification center equivalent), so training must stop.
struct MacOSBackgroundPolicy: BackgroundPolicy {
    func shouldStopTraining(newPhase: AppScenePhase) -> Bool {
        newPhase == .background || newPhase == .inactive
    }

    func shouldClearNavigation(oldPhase: AppScenePhase, newPhase: AppScenePhase) -> Bool {
        false
    }
}

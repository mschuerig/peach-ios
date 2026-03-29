/// iOS background policy: stop training only when entering background.
///
/// Inactive on iOS is transient (e.g. notification center, control center)
/// and should not interrupt training or navigation. Training auto-starts
/// when navigating to a training screen and auto-restarts on foreground return.
struct IOSBackgroundPolicy: BackgroundPolicy {
    func shouldStopTraining(newPhase: AppScenePhase) -> Bool {
        newPhase == .background
    }

    var shouldAutoStartTraining: Bool { true }
}

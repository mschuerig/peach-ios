/// iOS background policy: stop training only when entering background.
///
/// Inactive on iOS is transient (e.g. notification center, control center)
/// and should not interrupt training.
struct IOSBackgroundPolicy: BackgroundPolicy {
    func shouldStopTraining(newPhase: AppScenePhase) -> Bool {
        newPhase == .background
    }

    func shouldClearNavigation(oldPhase: AppScenePhase, newPhase: AppScenePhase) -> Bool {
        newPhase == .active && (oldPhase == .background || oldPhase == .inactive)
    }
}

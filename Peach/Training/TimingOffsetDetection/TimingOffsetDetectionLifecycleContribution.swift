extension TimingOffsetDetectionSession {
    /// TOD owns `todUserSettings` as a feature-local port and consumes it
    /// directly here, rather than threading it through the lifecycle
    /// coordinator.
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings,
        todUserSettings: any TimingOffsetDetectionUserSettings
    ) {
        builder.register(
            destination: .timingOffsetDetection,
            session: self
        ) {
            self.start(settings: .from(userSettings, todUserSettings: todUserSettings))
        }
    }
}

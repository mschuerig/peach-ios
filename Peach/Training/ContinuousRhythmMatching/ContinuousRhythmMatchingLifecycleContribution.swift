extension ContinuousRhythmMatchingSession {
    /// CRM owns `crmUserSettings` as a feature-local port and consumes it
    /// directly here, rather than threading it through the lifecycle
    /// coordinator.
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings,
        crmUserSettings: any ContinuousRhythmMatchingUserSettings
    ) {
        builder.register(
            destination: .continuousRhythmMatching,
            session: self
        ) {
            self.start(settings: .from(userSettings, crmUserSettings: crmUserSettings))
        }
    }
}

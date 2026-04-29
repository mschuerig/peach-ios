extension PitchMatchingSession {
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings
    ) {
        builder.register(
            destination: .pitchMatching(isIntervalMode: false),
            session: self
        ) {
            self.start(settings: .from(userSettings, intervals: [.prime]))
        }
        builder.register(
            destination: .pitchMatching(isIntervalMode: true),
            session: self
        ) {
            self.start(settings: .from(userSettings, intervals: userSettings.intervals))
        }
    }
}

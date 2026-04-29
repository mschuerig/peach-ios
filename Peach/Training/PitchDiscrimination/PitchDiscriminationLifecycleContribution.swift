extension PitchDiscriminationSession {
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings
    ) {
        builder.register(
            destination: .pitchDiscrimination(isIntervalMode: false),
            session: self
        ) {
            self.start(settings: .from(userSettings, intervals: [.prime]))
        }
        builder.register(
            destination: .pitchDiscrimination(isIntervalMode: true),
            session: self
        ) {
            self.start(settings: .from(userSettings, intervals: userSettings.intervals))
        }
    }
}

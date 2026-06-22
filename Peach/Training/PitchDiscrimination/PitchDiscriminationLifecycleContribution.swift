extension PitchDiscriminationSession {
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings
    ) {
        builder.register(
            destination: .pitchDiscrimination(isIntervalMode: false),
            session: self,
            start: {
                self.start(settings: .from(userSettings, intervals: [.prime]))
            },
            reconcile: { self.resume() }
        )
        builder.register(
            destination: .pitchDiscrimination(isIntervalMode: true),
            session: self,
            start: {
                self.start(settings: .from(userSettings, intervals: userSettings.intervals))
            },
            reconcile: { self.resume() }
        )
    }
}

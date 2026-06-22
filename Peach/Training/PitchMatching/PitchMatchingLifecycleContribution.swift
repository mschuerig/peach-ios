extension PitchMatchingSession {
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings
    ) {
        builder.register(
            destination: .pitchMatching(isIntervalMode: false),
            session: self,
            start: {
                self.start(settings: .from(userSettings, intervals: [.prime]))
            },
            resume: { self.resume() }
        )
        builder.register(
            destination: .pitchMatching(isIntervalMode: true),
            session: self,
            start: {
                self.start(settings: .from(userSettings, intervals: userSettings.intervals))
            },
            resume: { self.resume() }
        )
    }
}

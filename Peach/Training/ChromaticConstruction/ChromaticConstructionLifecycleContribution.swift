extension ChromaticConstructionSession {
    /// Registers the Chromatic Construction session with the lifecycle
    /// builder. The discipline has no persistent settings in the experimental
    /// cut — `start(settings:)` carries default values that **must match** the
    /// screen's view-local defaults (`MIDINote(60)`,
    /// `ChromaticDirectionMode.mix.outerIntervals(for: .perfectFifth)`). Same
    /// defaults on both ends means the screen's `onAppear` reconciliation
    /// detects an exact match and skips the no-flash stop+restart. When the
    /// user has changed a view-local control before first appearance, the
    /// screen detects the mismatch and restarts with view-local values.
    func contribute(
        to builder: TrainingLifecycleRegistry.Builder,
        userSettings: any UserSettings
    ) {
        builder.register(
            destination: .chromaticConstruction,
            session: self
        ) {
            self.start(settings: ChromaticConstructionSettings.from(
                userSettings,
                lowerAnchor: MIDINote(60),
                outerIntervals: ChromaticDirectionMode.mix.outerIntervals(for: .perfectFifth)
            ))
        }
    }
}

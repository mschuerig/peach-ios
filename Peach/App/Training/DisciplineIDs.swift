nonisolated extension TrainingDisciplineID {
    static let unisonPitchDiscrimination    = TrainingDisciplineID("pitch-discrimination")
    static let intervalPitchDiscrimination  = TrainingDisciplineID("interval-discrimination")
    static let unisonPitchMatching          = TrainingDisciplineID("pitch-matching")
    static let intervalPitchMatching        = TrainingDisciplineID("interval-matching")
    static let timingOffsetDetection        = TrainingDisciplineID("timing-offset-detection")
    static let continuousRhythmMatching     = TrainingDisciplineID("continuous-rhythm-matching")
    static let chromaticConstruction        = TrainingDisciplineID("chromatic-construction")

    /// All discipline IDs declared by the App. Iterate this only when a structural
    /// invariant of the catalog itself is being asserted (e.g. tests). Production
    /// code should iterate `TrainingDisciplineRegistry.shared.all`, which reflects
    /// what is actually registered and may be a strict subset of this list when
    /// registration is conditional on build configuration.
    static let canonicalIDs: [TrainingDisciplineID] = [
        .unisonPitchDiscrimination,
        .intervalPitchDiscrimination,
        .unisonPitchMatching,
        .intervalPitchMatching,
        .timingOffsetDetection,
        .continuousRhythmMatching,
        .chromaticConstruction,
    ]
}

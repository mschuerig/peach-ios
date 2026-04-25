nonisolated extension TrainingDisciplineID {
    static let unisonPitchDiscrimination    = TrainingDisciplineID("pitch-discrimination")
    static let intervalPitchDiscrimination  = TrainingDisciplineID("interval-discrimination")
    static let unisonPitchMatching          = TrainingDisciplineID("pitch-matching")
    static let intervalPitchMatching        = TrainingDisciplineID("interval-matching")
    static let timingOffsetDetection        = TrainingDisciplineID("timing-offset-detection")
    static let continuousRhythmMatching     = TrainingDisciplineID("continuous-rhythm-matching")

    /// All discipline IDs currently declared by the App. This is the historical
    /// `allCases` set; production code should prefer iterating `TrainingDisciplineRegistry.shared.all`
    /// since that reflects what is actually registered (which becomes build-conditional in 76.4).
    static let canonicalIDs: [TrainingDisciplineID] = [
        .unisonPitchDiscrimination,
        .intervalPitchDiscrimination,
        .unisonPitchMatching,
        .intervalPitchMatching,
        .timingOffsetDetection,
        .continuousRhythmMatching,
    ]
}

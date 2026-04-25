import Foundation

/// Concrete catalog of training disciplines registered with
/// ``TrainingDisciplineRegistry`` at app startup. Core defines the registry
/// shape; the App layer owns this list.
enum DisciplineBootstrap {
    static let allDisciplines: [any TrainingDiscipline] = [
        UnisonPitchDiscriminationDiscipline(),
        IntervalPitchDiscriminationDiscipline(),
        UnisonPitchMatchingDiscipline(),
        IntervalPitchMatchingDiscipline(),
        TimingOffsetDetectionDiscipline(),
        ContinuousRhythmMatchingDiscipline(),
    ]
}

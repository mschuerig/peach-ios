import Foundation

/// Concrete catalog of training disciplines registered with
/// ``TrainingDisciplineRegistry`` at app startup. Core defines the registry
/// shape; the App layer owns this list.
///
/// Registration of the timing disciplines is gated on the `PEACH_RESEARCH`
/// Swift compilation flag, defined by the two `(Research)` build
/// configurations (`Debug (Research)` and `Release (Research)`). The plain
/// `Debug` and `Release` configurations register the pitch disciplines only
/// (the App Store cut); the `(Research)` configurations additionally register
/// the timing disciplines.
enum DisciplineBootstrap {
    static let allDisciplines: [any TrainingDiscipline] = {
        var disciplines: [any TrainingDiscipline] = [
            UnisonPitchDiscriminationDiscipline(),
            IntervalPitchDiscriminationDiscipline(),
            UnisonPitchMatchingDiscipline(),
            IntervalPitchMatchingDiscipline(),
        ]
        #if PEACH_RESEARCH
        disciplines.append(TimingOffsetDetectionDiscipline())
        disciplines.append(ContinuousRhythmMatchingDiscipline())
        #endif
        return disciplines
    }()
}

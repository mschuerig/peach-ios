import Foundation

/// Concrete catalog of training disciplines registered with
/// ``TrainingDisciplineRegistry`` at app startup. Core defines the registry
/// shape; the App layer owns this list.
///
/// # Single source of truth for discipline activation
///
/// This file is the **only** place a developer edits to enable or disable an
/// individual training discipline. Activation is **per-discipline**,
/// **compile-time only**, and lives in one list. There is no runtime toggle,
/// no `UserDefaults` flag, and no debug menu — toggling a discipline always
/// requires a rebuild. To disable a discipline locally, comment out its
/// line in the appropriate block (the always-on block for pitch
/// disciplines, the `#if PEACH_RESEARCH` block for timing disciplines).
///
/// ## The `PEACH_RESEARCH` envelope
///
/// The two `(Research)` build configurations (`Debug (Research)` and
/// `Release (Research)`) define the `PEACH_RESEARCH` Swift compilation flag.
/// The pitch disciplines are active in every configuration; the timing
/// rows are wrapped in `#if PEACH_RESEARCH` so their types are not even
/// referenced — and therefore not linked — in the App Store cut.
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

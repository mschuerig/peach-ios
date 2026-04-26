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
/// requires a rebuild.
///
/// ## How to disable a discipline locally
///
/// Flip the discipline's `active` flag in ``candidates`` to `false`. Inactive
/// candidates are not constructed and not registered, so every aggregating
/// screen renders without that discipline's UI on the next launch.
///
/// ## The `PEACH_RESEARCH` envelope
///
/// The two `(Research)` build configurations (`Debug (Research)` and
/// `Release (Research)`) define the `PEACH_RESEARCH` Swift compilation flag.
/// The pitch disciplines are active in every configuration; the timing
/// disciplines default to `active: isResearchBuild` so they ship in the
/// Research cut and are compiled out of the App Store cut. The per-discipline
/// flag here lets a developer override that envelope locally without
/// touching the project's build configuration matrix.
enum DisciplineBootstrap {

    #if PEACH_RESEARCH
    private static let isResearchBuild = true
    #else
    private static let isResearchBuild = false
    #endif

    static let allDisciplines: [any TrainingDiscipline] = {
        let candidates: [(active: Bool, factory: () -> any TrainingDiscipline)] = [
            (true,             { UnisonPitchDiscriminationDiscipline() }),
            (true,             { IntervalPitchDiscriminationDiscipline() }),
            (true,             { UnisonPitchMatchingDiscipline() }),
            (true,             { IntervalPitchMatchingDiscipline() }),
            (isResearchBuild,  { TimingOffsetDetectionDiscipline() }),
            (isResearchBuild,  { ContinuousRhythmMatchingDiscipline() }),
        ]
        return candidates.compactMap { $0.active ? $0.factory() : nil }
    }()
}

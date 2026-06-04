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
/// line in the appropriate block (the always-on block for pitch and timing
/// offset disciplines, the `#if PEACH_RESEARCH` block for the rhythm-matching
/// discipline).
///
/// ## The `PEACH_RESEARCH` envelope
///
/// The two `(Research)` build configurations (`Debug (Research)` and
/// `Release (Research)`) define the `PEACH_RESEARCH` Swift compilation flag.
/// The pitch disciplines and Timing Offset Detection are active in every
/// configuration; Continuous Rhythm Matching is wrapped in
/// `#if PEACH_RESEARCH` so it is not registered — and therefore not surfaced
/// in the UI — in the App Store cut.
enum DisciplineBootstrap {

    static let allDisciplines: [any TrainingDiscipline] = {
        var disciplines: [any TrainingDiscipline] = [
            UnisonPitchDiscriminationDiscipline(),
            IntervalPitchDiscriminationDiscipline(),
            UnisonPitchMatchingDiscipline(),
            IntervalPitchMatchingDiscipline(),
            TimingOffsetDetectionDiscipline(),
        ]
        #if PEACH_RESEARCH
        disciplines.append(ContinuousRhythmMatchingDiscipline())
        #endif
        return disciplines
    }()

    /// CSV histories for every discipline known to the codebase, including
    /// disciplines that are not active in the current build.
    ///
    /// The migration runner must be able to migrate rows belonging to any
    /// historical discipline regardless of build configuration: a v2 CSV
    /// containing `rhythmMatching` rows imported into a non-research build
    /// must still be transformed to v3 shape, even though the discipline that
    /// would parse the migrated rows is not registered. Active-discipline
    /// gating happens later, at row dispatch.
    static let allCSVHistories: [CSVHistory] = [
        PitchDiscriminationCSVHistory.history,
        PitchMatchingCSVHistory.history,
        TimingOffsetDetectionCSVHistory.history,
        ContinuousRhythmMatchingCSVHistory.history,
    ]
}

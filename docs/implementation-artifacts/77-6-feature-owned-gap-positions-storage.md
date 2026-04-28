# Story 77.6: Feature-owned storage for enabledGapPositions

Status: done

## Story

As **a developer maintaining the central `UserSettings` port**,
I want the `enabledGapPositions` setting — the only entry that exists for exactly one discipline — moved out of `Peach/Core/Ports/UserSettings.swift` and `Peach/Settings/SettingsKeys.swift` into the ContinuousRhythmMatching feature directory,
so that the central settings port no longer implicitly enumerates discipline-specific concerns and adding a new discipline with feature-local settings doesn't require editing any central type.

## Background

The architect/dev discussion preceding this story established that:

1. Most settings in `UserSettings` (note range, reference pitch, sound source, tuning system, intervals, vary-loudness, tempo, note gap, note duration, velocity, autoStartTraining) are genuinely shared by ≥2 disciplines and belong in the central port. `varyLoudness` is read by `PitchMatchingSession` and `PitchDiscriminationSession`. `tempoBPM` is read by both rhythm disciplines. These are not the problem.
2. `enabledGapPositions: Set<StepPosition>` is the single feature-local outlier: only `ContinuousRhythmMatchingSession` reads it.
3. `StepPosition` itself is a legitimate type in the step-sequencer abstraction (`Peach/Core/Audio/SequencerTypes.swift`) and stays where it is. The musical interpretation ("beat 1 of a measure has the gap") is layered on by CRM at the training level, not encoded in the type.
4. There is no need for a new `ContinuousRhythmMatchingUserSettings` port in Core — that would just replace one Core leak with another (Core would then implicitly know about CRM specifically). The fix is to push storage end-to-end into the feature directory.

After this story, `UserSettings.swift` and `SettingsKeys.swift` contain only entries used by ≥2 disciplines or by app-wide infrastructure. A grep for any specific discipline name in `Peach/Core/Ports/UserSettings.swift` returns zero hits.

## Acceptance Criteria

### AC 1: enabledGapPositions removed from central settings

**Given** `Peach/Core/Ports/UserSettings.swift`, `Peach/Settings/SettingsKeys.swift`, and `Peach/Settings/AppUserSettings.swift`
**When** inspected after this story
**Then** `enabledGapPositions` (and the `defaultEnabledGapPositions` constant) are absent from all three files. The three files no longer reference `StepPosition` either.

### AC 2: CRM feature owns the storage

**Given** `Peach/Training/ContinuousRhythmMatching/`
**When** inspected
**Then** it contains:

- The UserDefaults key string (`"enabledGapPositions"` — preserved verbatim).
- The default `Set<StepPosition>` value (preserved verbatim from `SettingsKeys.defaultEnabledGapPositions`).
- The `GapPositionEncoding` helper (moved from `Peach/Settings/`).

These may live in a single new file (e.g. `ContinuousRhythmMatchingSettingsKeys.swift`) or be folded into existing feature files — dev's call.

### AC 3: CRM session reads via the feature

**Given** `ContinuousRhythmMatchingSettings.from(_:)` (or its successor)
**When** producing the feature settings struct
**Then** it composes shared values from `UserSettings` (e.g., `tempoBPM`) and reads `enabledGapPositions` from the feature-owned key. The mechanism is dev's choice:

- Pass `UserDefaults` as a second parameter to `from(_:_:)`, and the feature reads its own key directly.
- Define a feature-local `ContinuousRhythmMatchingUserSettings` port **inside** `Peach/Training/ContinuousRhythmMatching/` (App-layer infrastructure, **not** in `Peach/Core/Ports/`), which the CRM session takes alongside the Core `UserSettings` port. The App composition root provides the implementation.
- Any equivalent that keeps the storage end-to-end inside the feature directory.

Document the chosen mechanism in Completion Notes.

### AC 4: Section view binds to the feature key

**Given** `RhythmGapPositionsSettingsSection` (since 77.2 it lives in the feature directory)
**When** inspected
**Then** its `@AppStorage` binds to a feature-owned key constant, not to `SettingsKeys.enabledGapPositions`.

### AC 5: UserDefaults key and encoding preserved

**Given** an existing user with `"enabledGapPositions"` set in UserDefaults from a pre-77.6 build
**When** they launch a post-77.6 build
**Then** their selection is read correctly. The UserDefaults key string and `GapPositionEncoding` format are byte-identical to before this story (no migration code required).

### AC 6: No central type enumerates discipline-specific settings

**Given** `Peach/Core/Ports/UserSettings.swift` and `Peach/Settings/SettingsKeys.swift`
**When** inspected
**Then** every entry corresponds to a value used by ≥2 disciplines or by app-wide infrastructure. Document the surviving entries in Completion Notes with one-line notes on which disciplines or subsystems each serves, so reviewers can confirm the audit. Specifically out of scope:

- `varyLoudness` stays (used by both pitch sessions).
- `tempoBPM` stays (used by both rhythm sessions).
- `noteRange`, `tuningSystem`, `intervals`, `noteGap`, `noteDuration` stay (shared by pitch family).
- `referencePitch`, `soundSource`, `velocity` stay (app-wide audio configuration).
- `autoStartTraining` stays (app-wide UX preference).

### AC 7: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all tests pass under all four configurations.

`bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

## Tasks / Subtasks

- [x] Task 1: Move feature-owned storage (AC: 1, 2)
  - [x] 1.1 Create the feature-owned settings keys file under `Peach/Training/ContinuousRhythmMatching/` (path is dev's call).
  - [x] 1.2 Move the key string constant, default value, and `GapPositionEncoding` into that location.
  - [x] 1.3 Remove `enabledGapPositions` and `defaultEnabledGapPositions` from `SettingsKeys.swift`, `UserSettings.swift`, and `AppUserSettings.swift`. Remove any remaining `StepPosition` import from those three files.

- [x] Task 2: Wire the CRM session (AC: 3)
  - [x] 2.1 Pick a mechanism (UserDefaults parameter, feature-local port, or equivalent). Document the choice.
  - [x] 2.2 Update `ContinuousRhythmMatchingSettings.from(_:)` accordingly.
  - [x] 2.3 Update App-layer composition root if a new dependency is introduced.

- [x] Task 3: Update the section view (AC: 4)
  - [x] 3.1 Rebind `RhythmGapPositionsSettingsSection`'s `@AppStorage` to the feature-owned key constant.

- [x] Task 4: Verify backwards-compatibility (AC: 5)
  - [x] 4.1 Confirm the UserDefaults key string is byte-identical (`"enabledGapPositions"`).
  - [x] 4.2 Confirm the encoding format produced by `GapPositionEncoding` is unchanged.
  - [x] 4.3 Optional: write a small test that round-trips a legacy-format string through the new feature-owned reader.

- [x] Task 5: Audit (AC: 6)
  - [x] 5.1 Review the surviving entries in `UserSettings.swift` and `SettingsKeys.swift`. For each, write a one-line note in Completion Notes identifying which disciplines or subsystems consume it.
  - [x] 5.2 If any entry has only a single feature consumer that wasn't anticipated, flag it for follow-up rather than expanding this story's scope.

- [x] Task 6: Build/test (AC: 7)
  - [x] 6.1 All four test configurations green.
  - [x] 6.2 Build: zero new warnings.

## Dev Notes

### Why no new Core port

A Core-level `ContinuousRhythmMatchingUserSettings` port would just replace one Core leak with another (now Core knows about CRM specifically). The cleaner answer is to push the entire storage chain — key string, default, encoding, reader — into the feature directory. If a port abstraction is useful for testing, define it inside `Peach/Training/ContinuousRhythmMatching/`, **not** in `Peach/Core/Ports/`.

### Why `StepPosition` stays where it is

`StepPosition` lives in `Peach/Core/Audio/SequencerTypes.swift` and serves the step-sequencer abstraction in Core/Audio. It is named correctly in that context (the sequencer cares about step indices, not musical beats). The musical interpretation — "beat 1 of a measure has the gap" — happens at the CRM level as an interpretation of the sequencer's output, not a separate type. Replacing `StepPosition` with a musical type would force the Core/Audio layer to import musical vocabulary it doesn't need.

### What about other settings that look almost feature-local?

Some entries are used by exactly two of the six disciplines (e.g., `varyLoudness` is read by both pitch sessions). These are shared by the pitch family and belong in the central port. Out of scope for this story.

If a future story finds that the pitch family wants its own scope type for shared pitch settings, that would be a separate decision driven by concrete coupling pain — not anticipated here.

### What this story is NOT

- Not a redesign of `UserSettings` more broadly.
- Not a UserDefaults migration.
- Not a `StepPosition` rename or relocation.
- Not a new abstraction layer for "discipline-scoped settings" in Core.

### References

- `Peach/Core/Ports/UserSettings.swift` — `var enabledGapPositions: Set<StepPosition> { get }` is the entry to remove.
- `Peach/Settings/SettingsKeys.swift` — key string and default to move.
- `Peach/Settings/AppUserSettings.swift` — concrete reader to remove or relocate.
- `Peach/Settings/GapPositionEncoding.swift` — encoding helper to move into the feature directory.
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSettings.swift` — feature settings struct to update.
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — consumer to update if the signature changes.

## Dev Agent Record

### Completion Notes

**Mechanism chosen (AC 3): feature-local port `ContinuousRhythmMatchingUserSettings`.**

A new protocol `ContinuousRhythmMatchingUserSettings` lives inside the feature directory (`Peach/Training/ContinuousRhythmMatching/Settings/ContinuousRhythmMatchingUserSettings.swift`) — *not* in `Peach/Core/Ports/`. The concrete `AppContinuousRhythmMatchingUserSettings` reads from `UserDefaults` using the feature-owned key. `ContinuousRhythmMatchingSettings.from(_:_:)` now takes both the central `UserSettings` (for `tempoBPM`) and the feature-local port. The App composition root constructs both, and `TrainingLifecycleCoordinator` accepts the feature port alongside `userSettings`. Rationale: matches the existing `UserSettings` adapter pattern, keeps the storage chain end-to-end inside the feature directory, and gives tests a focused mock.

**Backwards compatibility (AC 5).** The UserDefaults key string is byte-identical (`"enabledGapPositions"`). `GapPositionEncoding` was already moved into the feature directory in story 77.2; only its single reference to the central default constant was redirected to `ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions`. The encoding format is unchanged. Existing users' `@AppStorage` values are read correctly by the new feature-owned reader (`AppContinuousRhythmMatchingUserSettings`); a round-trip test in `AppContinuousRhythmMatchingUserSettingsTests` exercises the legacy-format string explicitly.

**Audit of surviving central settings (AC 6).** Each entry in `Peach/Core/Ports/UserSettings.swift` and `Peach/Settings/SettingsKeys.swift` after this story:

- `noteRange` — used by PitchMatching and PitchDiscrimination (≥2 disciplines).
- `noteDuration` — used by PitchMatching and PitchDiscrimination (≥2 disciplines).
- `referencePitch` — used by PitchMatching, PitchDiscrimination, and `SettingsCoordinator` (app-wide audio configuration).
- `soundSource` — used by `PeachApp` to resolve the active preset (app-wide audio configuration).
- `varyLoudness` — used by PitchMatching and PitchDiscrimination (≥2 disciplines).
- `intervals` — used by PitchMatching and PitchDiscrimination (≥2 disciplines).
- `tuningSystem` — used by PitchMatching and PitchDiscrimination (≥2 disciplines).
- `tempoBPM` — used by ContinuousRhythmMatching and TimingOffsetDetection (≥2 disciplines).
- `velocity` — used by PitchMatching, PitchDiscrimination, and `SettingsCoordinator` (app-wide audio configuration).
- `autoStartTraining` — used by `TrainingLifecycleCoordinator` (app-wide UX preference).
- `noteGap` — **single consumer** (PitchDiscrimination only). The story Dev Notes anticipated `noteGap` as shared by the pitch family, but PitchMatching does not consume it. Flagged for follow-up per Task 5.2; not expanded into this story's scope. A future story may either move it into the PitchDiscrimination feature directory or surface it in PitchMatching if the product wants to inherit gap behaviour there.

A grep for `enabledGapPositions` or `defaultEnabledGapPositions` under `Peach/Core` and `Peach/Settings` returns zero hits.

**Test results (AC 7).** All four configurations green:

- iOS Debug: 1455 tests passed (3 new tests added).
- macOS Debug: 1449 tests passed.
- iOS Debug (Research): 1799 tests passed.
- macOS Debug (Research): 1793 tests passed.

`bin/build.sh` and `bin/build.sh -p mac` succeed with the single pre-existing AppIntents framework-extraction warning (not introduced by this story).

### File List

**New:**

- `Peach/Training/ContinuousRhythmMatching/Settings/ContinuousRhythmMatchingSettingsKeys.swift`
- `Peach/Training/ContinuousRhythmMatching/Settings/ContinuousRhythmMatchingUserSettings.swift`
- `PeachTests/Mocks/MockContinuousRhythmMatchingUserSettings.swift`
- `PeachTests/Training/ContinuousRhythmMatching/AppContinuousRhythmMatchingUserSettingsTests.swift`

**Modified:**

- `Peach/App/PeachApp.swift` (composition root constructs `AppContinuousRhythmMatchingUserSettings`, threads it through `buildCoordinators`)
- `Peach/App/TrainingLifecycleCoordinator.swift` (accepts the feature port; `start(.continuousRhythmMatching)` calls `from(userSettings, crmUserSettings)`)
- `Peach/App/PreviewDefaults.swift` (new `StubContinuousRhythmMatchingUserSettings`; coordinator stub wires it; `StubUserSettings` no longer carries `enabledGapPositions`)
- `Peach/Core/Ports/UserSettings.swift` (removed `enabledGapPositions` requirement)
- `Peach/Settings/AppUserSettings.swift` (removed `enabledGapPositions` reader)
- `Peach/Settings/SettingsKeys.swift` (removed `enabledGapPositions` key and `defaultEnabledGapPositions`)
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSettings.swift` (`from(_:_:)` takes the feature port)
- `Peach/Training/ContinuousRhythmMatching/Settings/GapPositionEncoding.swift` (default fallback now references the feature-owned constant)
- `Peach/Training/ContinuousRhythmMatching/Settings/RhythmGapPositionsSettingsSection.swift` (`@AppStorage` binds to feature-owned key constant)
- `PeachTests/Mocks/MockUserSettings.swift` (removed `enabledGapPositions`)
- `PeachTests/Settings/AppUserSettingsTests.swift` (removed `enabledGapPositionsDefault` test)
- `PeachTests/Core/Training/ContinuousRhythmMatchingSettingsTests.swift` (uses `MockContinuousRhythmMatchingUserSettings`; `from` calls take both ports)
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` (`makeCoordinator` helper accepts the feature port)
- `docs/implementation-artifacts/77-6-feature-owned-gap-positions-storage.md`
- `docs/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-04-27: Drafted as Story 77.4. Status → ready-for-dev.
- 2026-04-28: Renumbered to 77.6 to reflect post-architecture-session work order (envelope storage and CSV migration plugin take 77.4 and 77.5). Story content is unchanged; this work is independent of the envelope/CSV redesign.
- 2026-04-28: Implemented. `enabledGapPositions` storage moved end-to-end into `Peach/Training/ContinuousRhythmMatching/`. New feature-local port `ContinuousRhythmMatchingUserSettings` introduced (in the feature directory, not Core). Status → review.
- 2026-04-28: Review complete. Acceptance Auditor found zero AC violations. Two patches applied: (1) `ContinuousRhythmMatchingSettings.from(_:_:)` adopted project convention (`from(_ userSettings:, crmUserSettings:)`) to match sibling factories `PitchDiscriminationSettings.from(_:intervals:)` etc.; (2) renamed two test display strings + functions (`fromComposesSharedAndFeatureSettings`, `fromUsesFeaturePortDefaultGapPositions`) to accurately describe shared-vs-feature-port composition. All four configurations remained green (1455 / 1449 / 1799 / 1793 passed). One architectural concern deferred as story 77.12: the central `TrainingLifecycleCoordinator` accumulates per-discipline session and per-discipline settings dependencies, which runs counter to Epic 77's plugin-style direction. Other 13 review findings rejected as noise (verified against existing project conventions: `var defaults` pattern in `AppUserSettings`, non-Sendable `UserSettings` protocol, stub placement in `App/PreviewDefaults.swift`). Status → done.

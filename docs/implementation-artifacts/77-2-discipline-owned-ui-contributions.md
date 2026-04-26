# Story 77.2: Discipline-owned UI contributions and feature-directory colocation

Status: ready-for-dev

## Story

As **a developer adding, removing, or modifying a training discipline**,
I want each discipline to own its own UI surfaces (settings sections, profile card, scoped help) by implementing them directly in its feature directory,
so that adding a new discipline is purely a new-directory + one-line bootstrap-edit operation, with no central enums, central dispatchers, or screen-level switches to update.

## Background

Story 77.1 introduced enum-typed UI contributions (`SettingsSectionKind`, `ProfileCardKind`, `ProfileHelpKind`) as a pragmatic intermediate step. The kinds-enum + central-dispatcher pair is a closed-set indirection: every new contribution forces a central enum case + a central switch branch + a central section-view-struct, and feature-specific UI ends up in folders named for the screen (`Peach/Settings/SettingsContributions.swift` hosts rhythm-specific section structs as `private struct`s) rather than for the feature.

The deflationary plugin model: each discipline owns its own UI in its feature directory, declares it via a SwiftUI-aware protocol, and the screens become pure aggregators. No kinds enum, no central dispatcher, no feature-named code outside feature directories.

The Core/App layering rule is preserved by splitting the protocol along the seam: `TrainingDiscipline` (Core, Foundation only) keeps the data and lifecycle requirements that Core/Data services depend on; a new `TrainingDisciplineUI: TrainingDiscipline` (App, imports SwiftUI) adds the view-producing requirements. Since concrete discipline conformance files already live outside Core (`Peach/Training/<Feature>/Discipline/<Feature>Discipline.swift`), they can `import SwiftUI` without breaking Core's no-SwiftUI rule.

## Acceptance Criteria

### AC 1: Two-protocol split along the Core/App seam

**Given** Core's no-SwiftUI rule
**When** disciplines need to declare view-producing UI
**Then** the protocol splits cleanly:

- `TrainingDiscipline` (Core, Foundation only) keeps `id`, `category`, `config`, `statisticsKeys`, `recordType`, `csvTrainingType`, `csvColumns`, `parseCSVRow`, `feedRecords`, and any other Foundation-level requirements present today.
- A new `TrainingDisciplineUI: TrainingDiscipline` lives in the App layer, imports SwiftUI, and adds:
  - `var profileCard: AnyView { get }` — default `AnyView(ProgressChartView(mode: id))`
  - `var settingsSections: AnyView { get }` — default `AnyView(EmptyView())`
  - `var settingsHelp: [HelpSection] { get }` — default `[]`
  - `var profileHelp: [HelpSection] { get }` — default `[]`

Concrete disciplines conform to `TrainingDisciplineUI` in their feature directory and override only the requirements they need.

### AC 2: Feature-directory colocation of UI

**Given** a discipline with feature-specific section views, profile cards, or help text
**When** that code is inspected after this story
**Then** every feature-specific view, struct, and help body lives under `Peach/Training/<Feature>/`. Specifically:

- `RhythmTempoSettingsSection`, `RhythmGapPositionsSettingsSection`, and the `GapPositionEncoding` helper move from `Peach/Settings/` into `Peach/Training/ContinuousRhythmMatching/Settings/` (path is dev's call as long as it is under the feature directory).
- `RhythmProfileCardView` moves from `Peach/Profile/` into `Peach/Training/ContinuousRhythmMatching/Profile/`.
- Per-feature help bodies (rhythm tempo, gap positions, spectrogram overview/colors) move from `Peach/App/HelpContent.swift` into `Peach/Training/<Feature>/Help/<Feature>Help.swift` (or equivalent), exposed as functions returning `[HelpSection]`.

Shared visualizations (`ProgressChartView`, sparklines, etc.) stay in their shared location; disciplines reuse them by calling them from their `profileCard` builder.

### AC 3: Central deletions

**Given** the central kinds + dispatcher infrastructure introduced in 77.1
**When** this story is complete
**Then** the following are deleted:

- `Peach/Core/Training/Discipline/UIContributions.swift` (the three kinds enums).
- `Peach/Settings/SettingsContributions.swift`.
- `Peach/Profile/ProfileContributions.swift`.
- `TrainingDisciplineRegistry`'s aggregated `settingsSectionContributions` and `profileHelpContributions` lets and the `deduplicate(_:)` helper.
- The `settingsContributions` and `profileHelpContributions` requirements on `TrainingDiscipline` (subsumed by `TrainingDisciplineUI`'s view-producing methods).
- All per-feature help routing in `HelpContent.swift`. What remains in `HelpContent` is common (cross-cutting) help only, plus the aggregating helpers (`settingsHelpSections()`, `profileHelpSections()`) which now iterate the registry's UI list.

### AC 4: Screens iterate via the UI-typed list

**Given** the new UI protocol
**When** `SettingsScreen`, `ProfileScreen`, and `HelpContent` render
**Then** they iterate `[any TrainingDisciplineUI]` and call `discipline.settingsSections`, `discipline.profileCard`, `discipline.settingsHelp`, `discipline.profileHelp` directly. No screen contains any switch on a kind enum.

The mechanism for screens to access the UI-typed list is dev's choice. Acceptable shapes:

- An App-layer extension on `TrainingDisciplineRegistry` providing `var allUI: [any TrainingDisciplineUI] { all.compactMap { $0 as? any TrainingDisciplineUI } }`. The cast always succeeds because every concrete discipline conforms to UI; document the contract.
- `DisciplineBootstrap` exposes a typed `static let allUI: [any TrainingDisciplineUI]` alongside the existing list it passes to `bootstrap(disciplines:)`. Two parallel lists, but mechanically simple.
- Move the registry to App and store the UI-typed list directly. Most architecturally clean (the registry is App-layer policy anyway). Largest disruption; only adopt if the dev sees a clear win.

Document the choice in Completion Notes.

### AC 5: Audit test extended

**Given** the existing `CategoryLiteralAuditTests`
**When** updated for this story
**Then** its forbidden-substring list also blocks the deleted symbol names: `SettingsSectionKind`, `ProfileCardKind`, `ProfileHelpKind`, `contributedSettingsSection(`, `contributedProfileCard(`. Naming the deleted symbols in the audit defends against careless re-introduction.

### AC 6: Tests pin the new contracts

**Given** the new protocol surface
**When** the test suite runs
**Then** at minimum:

- A test asserts each registered discipline's `profileCard` returns a non-`EmptyView` view for disciplines that override it, and the default chart for disciplines that do not.
- A test constructs a registry from a synthetic single-discipline subset and asserts that `SettingsScreen` / `ProfileScreen` / help-aggregating helpers render only that discipline's contributions.
- A test asserts contribution iteration order matches discipline registration order.
- The 77.1-era `RegistryContributionsTests` is replaced or rewritten to test the new contract.

### AC 7: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all tests pass under all four configurations (Debug, Debug Research, Release, Release Research × iOS, macOS).

`bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

### AC 8: Adding a new discipline = directory + one line

**Given** a developer adding a hypothetical new discipline
**When** they create `Peach/Training/<NewDiscipline>/` with the discipline conformance to `TrainingDisciplineUI` and add one factory line to `DisciplineBootstrap.candidates`
**Then** the discipline appears on every aggregating screen (Settings, Profile, Help) at next render with **no other source files touched**. This is the core deliverable; demonstrate by reasoning in Completion Notes (no need to actually build a stub discipline).

## Tasks / Subtasks

- [ ] Task 1: Define `TrainingDisciplineUI` and split the protocol (AC: 1)
  - [ ] 1.1 Create `Peach/App/Training/TrainingDisciplineUI.swift` (or analogous App-layer location). Refine `TrainingDiscipline`. Provide default implementations for all four view-producing requirements.
  - [ ] 1.2 Decide and document the registry-access mechanism (AC 4 shapes). Default recommendation: App-layer extension on the registry with `compactMap` cast.
  - [ ] 1.3 Update App-layer call sites that need view-producing methods to refer to `TrainingDisciplineUI`.

- [ ] Task 2: Migrate each discipline to declare its own UI (AC: 2)
  - [ ] 2.1 `ContinuousRhythmMatchingDiscipline` overrides `profileCard`, `settingsSections`, `settingsHelp`, `profileHelp`.
  - [ ] 2.2 `TimingOffsetDetectionDiscipline` overrides only what it currently contributes (likely just `settingsHelp` / `profileHelp` for shared rhythm sections; tempo section may stay shared via the rhythm category).
  - [ ] 2.3 The four pitch/intervals disciplines inherit the protocol defaults; verify nothing currently rendered for them is silently lost.

- [ ] Task 3: Move feature-specific UI files into feature directories (AC: 2)
  - [ ] 3.1 Move `RhythmTempoSettingsSection`, `RhythmGapPositionsSettingsSection`, `GapPositionEncoding` into `Peach/Training/ContinuousRhythmMatching/Settings/`.
  - [ ] 3.2 Move `RhythmProfileCardView` into `Peach/Training/ContinuousRhythmMatching/Profile/`.
  - [ ] 3.3 Move per-feature help bodies into `Peach/Training/<Feature>/Help/<Feature>Help.swift`. Each returns `[HelpSection]`.

- [ ] Task 4: Delete central infrastructure (AC: 3)
  - [ ] 4.1 Delete `UIContributions.swift`, `SettingsContributions.swift`, `ProfileContributions.swift`.
  - [ ] 4.2 Remove `settingsSectionContributions`, `profileHelpContributions`, `deduplicate(_:)` from `TrainingDisciplineRegistry`.
  - [ ] 4.3 Remove `settingsContributions` and `profileHelpContributions` requirements (and their default implementations) from `TrainingDiscipline`.
  - [ ] 4.4 Delete per-feature help routing from `HelpContent`. Keep only common help and the aggregating helpers (which now iterate the registry's UI list).

- [ ] Task 5: Update aggregating screens (AC: 4)
  - [ ] 5.1 `SettingsScreen` iterates UI list and renders `discipline.settingsSections`.
  - [ ] 5.2 `ProfileScreen` iterates UI list and renders `discipline.profileCard`.
  - [ ] 5.3 `HelpContent.settingsHelpSections()` and `profileHelpSections()` aggregate via the registry's UI list.

- [ ] Task 6: Update audit + functional tests (AC: 5, 6)
  - [ ] 6.1 Extend `CategoryLiteralAuditTests`'s forbidden list to include the deleted enum names and dispatcher symbols.
  - [ ] 6.2 Replace `RegistryContributionsTests` with tests for the new protocol contract (default vs. overridden contributions, registration-order preservation).
  - [ ] 6.3 Add a synthetic single-discipline registry test asserting only that discipline's contributions render.

- [ ] Task 7: Build/test sweep + smoke documentation (AC: 7, 8)
  - [ ] 7.1 `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research` all green.
  - [ ] 7.2 `bin/build.sh && bin/build.sh -p mac` — zero new warnings.
  - [ ] 7.3 Document in Completion Notes how adding a hypothetical new discipline now reduces to "new directory + one bootstrap line."

## Dev Notes

### Why split the protocol instead of merging UI methods into `TrainingDiscipline`

Core's no-SwiftUI rule isn't load-bearing for portability (the project has no cross-platform plans beyond iOS/macOS, both SwiftUI). It is load-bearing for hygiene: Core/Data services (`TrainingDataExporter`, `CSVImportParser`, `TrainingDataImporter`, `TrainingDataStore`) consume the registry today and must continue to do so without pulling SwiftUI into the data layer. Splitting into a Core base protocol + App refinement protocol keeps the data layer decoupled from view code while still letting disciplines (which already live outside Core in `Peach/Training/<Feature>/`) declare their UI directly.

### Why `AnyView` is acceptable

The view-producing requirements return `AnyView`, not `some View`. Using opaque types here forces `[any TrainingDisciplineUI]` into a heterogeneous collection of incompatible existential types — Swift's existentials don't compose with associated-`some` returns ergonomically. `AnyView` is the right hammer for top-level dispatch into screen sections; it is not used in render-hot inner views, so the perf cost is negligible.

### Reuse of shared visualizations

Disciplines that want the standard chart get it for free via the protocol's default `profileCard`: `AnyView(ProgressChartView(mode: id))`. Disciplines that want a custom card override and call any shared view they like — sharing is a function call, not a kind enum lookup. Shared visualizations (`ProgressChartView`, sparklines) stay where they are.

### Per-category-shared contributions

Some contributions are naturally per-category (e.g., the rhythm tempo section applies to both rhythm disciplines). After this story, both rhythm disciplines override `settingsSections` to include the tempo section, and the aggregating screen renders the tempo section once because of how the registry orders disciplines and how SwiftUI handles repeated keys. (Investigate during implementation: if duplicate sections actually render twice, fold the dedupe into the screen-level aggregation rather than re-introducing kinds.)

An alternative is to attach contributions to `TrainingCategory` rather than to disciplines; this story leaves that decision to the dev based on what feels cleanest after the per-discipline overrides are written.

### Registry-access mechanism — three viable shapes

The Core registry stores `[any TrainingDiscipline]`. Screens need `[any TrainingDisciplineUI]`. Three mechanisms (dev's choice):

1. **App-layer extension** on `TrainingDisciplineRegistry`: `var allUI: [any TrainingDisciplineUI] { all.compactMap { $0 as? any TrainingDisciplineUI } }`. Lowest disruption.
2. **Parallel typed list in `DisciplineBootstrap`**: bootstrap returns both the upcast list (passed to the registry) and a typed App-side `static let allUI`. Two sources of truth, but mechanically simple.
3. **Move the registry to App**: the registry is App-layer policy after all. Largest disruption; only adopt if there's a clear win.

Recommend (1) unless ugliness is in the eye of the implementer.

### What this story is NOT

- Not a runtime UI for activation — 77.1's per-discipline compile-time switch stands.
- Not a CSV/SwiftData refactor — that's 77.3.
- Not a `UserSettings` refactor — that's 77.4.
- Not a SwiftData migration — pure protocol/struct/view changes.

### References

- Story 77.1 — established the kinds-enum + dispatcher contributions pattern; this story removes that indirection.
- `Peach/Settings/SettingsContributions.swift`, `Peach/Profile/ProfileContributions.swift` — to be deleted.
- `Peach/Core/Training/Discipline/UIContributions.swift` — to be deleted.
- `Peach/App/HelpContent.swift` — to be slimmed.
- `Peach/Training/ContinuousRhythmMatching/` — destination for the rhythm-specific section views, profile card, encoding helper, and help bodies.

## Change Log

- 2026-04-27: Drafted following architect-led discussion of plugin-shaped contributions. Status → ready-for-dev.

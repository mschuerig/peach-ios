# Story 77.2: Discipline-owned UI contributions and feature-directory colocation

Status: done

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

- [x] Task 1: Define `TrainingDisciplineUI` and split the protocol (AC: 1)
  - [x] 1.1 Create `Peach/App/Training/TrainingDisciplineUI.swift` (or analogous App-layer location). Refine `TrainingDiscipline`. Provide default implementations for all four view-producing requirements.
  - [x] 1.2 Decide and document the registry-access mechanism (AC 4 shapes). Default recommendation: App-layer extension on the registry with `compactMap` cast.
  - [x] 1.3 Update App-layer call sites that need view-producing methods to refer to `TrainingDisciplineUI`.

- [x] Task 2: Migrate each discipline to declare its own UI (AC: 2)
  - [x] 2.1 `ContinuousRhythmMatchingDiscipline` overrides `profileCard`, `settingsSections`, `settingsHelp`, `profileHelp`.
  - [x] 2.2 `TimingOffsetDetectionDiscipline` overrides only what it currently contributes (likely just `settingsHelp` / `profileHelp` for shared rhythm sections; tempo section may stay shared via the rhythm category).
  - [x] 2.3 The four pitch/intervals disciplines inherit the protocol defaults; verify nothing currently rendered for them is silently lost.

- [x] Task 3: Move feature-specific UI files into feature directories (AC: 2)
  - [x] 3.1 Move `RhythmTempoSettingsSection`, `RhythmGapPositionsSettingsSection`, `GapPositionEncoding` into `Peach/Training/ContinuousRhythmMatching/Settings/`.
  - [x] 3.2 Move `RhythmProfileCardView` into `Peach/Training/ContinuousRhythmMatching/Profile/`.
  - [x] 3.3 Move per-feature help bodies into `Peach/Training/<Feature>/Help/<Feature>Help.swift`. Each returns `[HelpSection]`.

- [x] Task 4: Delete central infrastructure (AC: 3)
  - [x] 4.1 Delete `UIContributions.swift`, `SettingsContributions.swift`, `ProfileContributions.swift`.
  - [x] 4.2 Remove `settingsSectionContributions`, `profileHelpContributions`, `deduplicate(_:)` from `TrainingDisciplineRegistry`.
  - [x] 4.3 Remove `settingsContributions` and `profileHelpContributions` requirements (and their default implementations) from `TrainingDiscipline`.
  - [x] 4.4 Delete per-feature help routing from `HelpContent`. Keep only common help and the aggregating helpers (which now iterate the registry's UI list).

- [x] Task 5: Update aggregating screens (AC: 4)
  - [x] 5.1 `SettingsScreen` iterates UI list and renders `discipline.settingsSections`.
  - [x] 5.2 `ProfileScreen` iterates UI list and renders `discipline.profileCard`.
  - [x] 5.3 `HelpContent.settingsHelpSections()` and `profileHelpSections()` aggregate via the registry's UI list.

- [x] Task 6: Update audit + functional tests (AC: 5, 6)
  - [x] 6.1 Extend `CategoryLiteralAuditTests`'s forbidden list to include the deleted enum names and dispatcher symbols.
  - [x] 6.2 Replace `RegistryContributionsTests` with tests for the new protocol contract (default vs. overridden contributions, registration-order preservation).
  - [x] 6.3 Add a synthetic single-discipline registry test asserting only that discipline's contributions render.

- [x] Task 7: Build/test sweep + smoke documentation (AC: 7, 8)
  - [x] 7.1 `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research` all green.
  - [x] 7.2 `bin/build.sh && bin/build.sh -p mac` — zero new warnings.
  - [x] 7.3 Document in Completion Notes how adding a hypothetical new discipline now reduces to "new directory + one bootstrap line."

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

## Dev Agent Record

### Completion Notes

**Registry-access mechanism (AC 4):** Adopted Option 1 — App-layer extension on `TrainingDisciplineRegistry`. `Peach/App/Training/TrainingDisciplineUI.swift` defines the protocol *and* extends the Core registry with `var allUI: [any TrainingDisciplineUI] { all.compactMap { $0 as? any TrainingDisciplineUI } }`. The `compactMap` cast always succeeds for production disciplines (every concrete discipline conforms to UI). Synthetic test fixtures conforming only to `TrainingDiscipline` are silently filtered, which is the desired behaviour — registry tests asserting UI behaviour use a `SyntheticUIDiscipline` fixture instead.

**Why not move the registry to App?** The Core registry stays in Core because `TrainingDataExporter`, `CSVImportParser`, and `TrainingDataStore` already consume it from the data layer; moving the registry would either pull SwiftUI into Core (violates the no-SwiftUI rule) or split the registry into two parallel objects. The compactMap cast is a one-line workaround that keeps the data-layer consumer surface unchanged.

**Adding a new discipline (AC 8):** Reduced to two operations:
1. Create `Peach/Training/<NewDiscipline>/` containing a `<NewDiscipline>Discipline.swift` conforming to `TrainingDisciplineUI` (overriding only the surfaces that differ from the defaults — `profileCard` defaults to `ProgressChartView`, `settingsSections` to `EmptyView`, `settingsHelp` and `profileHelp` to `[]`).
2. Add one factory line to `DisciplineBootstrap.candidates`.

No central enum, no central switch, no help-routing branch, no aggregator edit. Every aggregating screen (`SettingsScreen`, `ProfileScreen`, `HelpContent.settingsHelpSections()`, `HelpContent.profileHelpSections()`) iterates `TrainingDisciplineRegistry.shared.allUI` and discovers the new discipline at next render.

**Per-category-shared contributions:** Both rhythm disciplines declare the rhythm tempo section themselves: `ContinuousRhythmMatchingDiscipline` declares tempo + gap-positions, `TimingOffsetDetectionDiscipline` declares tempo only. Each section is wrapped in `DisciplineSettingsSection(id:)`, and `SharedRhythmSectionID.tempo` (in `Peach/Training/ContinuousRhythmMatching/Settings/SharedRhythmSectionID.swift`) is the stable id both disciplines use. `SettingsScreen` aggregates the contributed sections via `DisciplineSettingsSection.aggregated(from:)`, which keeps the first declarer of each id in registration order — so when both rhythm disciplines are active the tempo section renders once, and disabling the fill-the-gap discipline does not silently strip a section that timing-offset training still depends on. Help mirrors the same shape: `ContinuousRhythmMatchingHelp.tempoSettingsHelp` / `gapPositionsSettingsHelp` are now declared separately, both rhythm disciplines reference the help that accompanies the sections they actually render, and `HelpContent.settingsHelpSections()` / `profileHelpSections()` dedupe by `(title, body)` so the duplicates collapse into a single entry. The pre-existing `enabledGapPositions` / `tempoBPM` `@AppStorage` keys are still shared between both rhythm disciplines, so timing-offset training picks up the same tempo configured for fill-the-gap.

**SwiftUI → AnyView at the dispatch boundary:** `TrainingDisciplineUI` returns `AnyView` for `profileCard` so `[any TrainingDisciplineUI]` is iterable in a heterogeneous collection. `settingsSections` returns `[DisciplineSettingsSection]` — each entry carries an id and an `AnyView`, so `SettingsScreen.body` iterates the deduped list with `ForEach(_, id: \.id)`. The wrappers exist only at the screen-aggregation boundary; render-hot subviews stay strongly typed.

**Boy Scout cleanup during simplify-code:** Removed unused `ownSettingsSections: AnyView?` and `ownProfileCard: AnyView?` properties (and their `??` getter overrides) from the test fixture `SyntheticUIDiscipline` — no test sets them, and the protocol defaults already cover the non-overriding case.

**Verification:** All four configurations green — `bin/test.sh` (1446 passed), `bin/test.sh -p mac` (1440), `bin/test.sh --research` (1805), `bin/test.sh -p mac --research` (1799). Both `bin/build.sh` and `bin/build.sh -p mac` succeed with no Swift warnings (the single warning surfaced is the unrelated `appintentsmetadataprocessor` Xcode tooling notice).

### File List

**Added:**

- `Peach/App/Training/TrainingDisciplineUI.swift` — App-layer protocol refinement + `TrainingDisciplineRegistry.allUI` extension
- `Peach/Training/ContinuousRhythmMatching/Settings/GapPositionEncoding.swift` (moved)
- `Peach/Training/ContinuousRhythmMatching/Settings/RhythmTempoSettingsSection.swift` (moved)
- `Peach/Training/ContinuousRhythmMatching/Settings/RhythmGapPositionsSettingsSection.swift` (moved)
- `Peach/Training/ContinuousRhythmMatching/Profile/RhythmProfileCardView.swift` (moved)
- `Peach/Training/ContinuousRhythmMatching/Help/ContinuousRhythmMatchingHelp.swift`
- `Peach/Training/PitchDiscrimination/Help/PitchDiscriminationHelp.swift`
- `Peach/Training/PitchMatching/Help/PitchMatchingHelp.swift`
- `Peach/Training/TimingOffsetDetection/Help/TimingOffsetDetectionHelp.swift`

**Deleted:**

- `Peach/Core/Training/Discipline/UIContributions.swift`
- `Peach/Settings/SettingsContributions.swift`
- `Peach/Settings/GapPositionEncoding.swift` (relocated)
- `Peach/Profile/ProfileContributions.swift`
- `Peach/Profile/RhythmProfileCardView.swift` (relocated)

**Modified — production:**

- `Peach/App/HelpContent.swift` — slimmed to common-only sections + aggregators
- `Peach/App/Training/DisciplineBootstrap.swift` — dropped the unused per-candidate `active: Bool` flag and the redundant factory closures; the bootstrap is now a plain `[any TrainingDiscipline]` array (with `#if PEACH_RESEARCH` appends inside an IIFE) and disabling a discipline locally means commenting its line out (post-review cleanup; the flag had been hard-coded `true` everywhere since 77.1, and the factory closures only existed to support it)
- `Peach/Core/Training/Discipline/TrainingDiscipline.swift` — removed UI requirements
- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` — removed aggregated contributions
- `Peach/Profile/ProfileScreen.swift` — iterates `allUI`, calls `discipline.profileCard`
- `Peach/Settings/SettingsScreen.swift` — iterates `allUI`, calls `discipline.settingsSections`
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift` — conforms to `TrainingDisciplineUI`, declares own UI
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` — references `ContinuousRhythmMatchingHelp.trainingScreen`
- `Peach/Training/PitchDiscrimination/Discipline/IntervalPitchDiscriminationDiscipline.swift` — conforms to `TrainingDisciplineUI`
- `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift` — conforms to `TrainingDisciplineUI`
- `Peach/Training/PitchDiscrimination/PitchDiscriminationScreen.swift` — references `PitchDiscriminationHelp.trainingScreen`
- `Peach/Training/PitchMatching/Discipline/IntervalPitchMatchingDiscipline.swift` — conforms to `TrainingDisciplineUI`
- `Peach/Training/PitchMatching/Discipline/UnisonPitchMatchingDiscipline.swift` — conforms to `TrainingDisciplineUI`
- `Peach/Training/PitchMatching/PitchMatchingScreen.swift` — references `PitchMatchingHelp.trainingScreen`
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — conforms to `TrainingDisciplineUI`
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` — references `TimingOffsetDetectionHelp.trainingScreen`
- `Peach/Resources/Localizable.xcstrings` — moved entries follow the moved files

**Modified — tests:**

- `PeachTests/App/CategoryLiteralAuditTests.swift` — extended forbidden list with `SettingsSectionKind`, `ProfileCardKind`, `ProfileHelpKind`, `contributedSettingsSection(`, `contributedProfileCard(`
- `PeachTests/App/HelpContentViewTests.swift` — uses `allUI.flatMap(\.settingsHelp/.profileHelp)`
- `PeachTests/Core/Training/RegistryActiveCategoriesTests.swift` — `SyntheticDiscipline` slimmed to `TrainingDiscipline`-only conformance
- `PeachTests/Core/Training/RegistryContributionsTests.swift` — replaced with new contract tests using `SyntheticUIDiscipline`
- `PeachTests/Settings/SettingsScreenAggregationTests.swift` — replaced with help-aggregation tests using `SyntheticUIDiscipline`
- `PeachTests/Settings/SettingsTests.swift` — uses `allUI.flatMap(\.settingsHelp)` for rhythm-help check
- `PeachTests/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreenTests.swift`, `PeachTests/Training/PitchDiscrimination/PitchDiscriminationScreenLayoutTests.swift`, `PeachTests/Training/PitchMatching/PitchMatchingScreenTests.swift`, `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionScreenLayoutTests.swift` — reference `<Feature>Help.trainingScreen`

## Change Log

- 2026-04-27: Drafted following architect-led discussion of plugin-shaped contributions. Status → ready-for-dev.
- 2026-04-27: Implementation complete. Protocol split landed at `Peach/App/Training/TrainingDisciplineUI.swift` with App-layer `allUI` extension on the Core registry. Per-feature UI moved into `Peach/Training/<Feature>/{Settings,Profile,Help}/`. Central kinds + dispatchers deleted. Aggregating screens iterate the UI-typed list. All four test configurations green. Status → review.
- 2026-04-27: Post-review cleanup — collapsed `DisciplineBootstrap` to a plain `[any TrainingDiscipline]` array (IIFE wrapping the `#if PEACH_RESEARCH` appends). The previous `(active: Bool, factory: () -> any TrainingDiscipline)` tuple shape and the closure indirection only existed to support a per-candidate kill switch that had been hard-coded `true` everywhere since 77.1; commenting out a line achieves the same local-disable effect with less ceremony. ADR-10 description in story 77.5 updated to match. Both Debug and Debug (Research) builds verified.
- 2026-04-27: Post-review cleanup (simplify-code) — replaced three hardcoded `"continuousRhythmMatching"` string literals in `ContinuousRhythmMatchingDiscipline.parsedRecords(_:)` and `mergeImportRecords(...)` with `csvTrainingType` (the property that already holds that string). Pre-existing single-source-of-truth violation; `TimingOffsetDetectionDiscipline` already used `csvTrainingType` correctly. iOS Research test sweep (1805 tests) green.
- 2026-04-27: Code-review fixes for adversarial review of this story. **Structural identity (P3):** `TrainingDisciplineUI.settingsSections` now returns `[DisciplineSettingsSection]` (id + AnyView) instead of an `AnyView` wrapping a `Group` of `Section`s; `SettingsScreen.body` iterates with `ForEach(_, id: \.id)` so SwiftUI's structural identity is per-section rather than per-discipline. **Silent coupling (P2):** `TimingOffsetDetectionDiscipline` now declares the rhythm tempo section, the matching tempo settings help (`ContinuousRhythmMatchingHelp.tempoSettingsHelp`, split out from the previously combined `settingsHelp`), and the rhythm spectrogram profile help. Both rhythm disciplines now declare every UI surface they actually render. `DisciplineSettingsSection.aggregated(from:)` dedupes by section id (first declarer wins); `HelpContent.settingsHelpSections()` / `profileHelpSections()` dedupe by `(title, body)`. **Localization (P1):** Restored German translations for the Tempo and Gap Positions help by populating the now-separated keys; pruned the stale combined entry. **Doc fix (P9):** `DisciplineBootstrap` doc clarifies that disabling a timing discipline means commenting its line in the `#if PEACH_RESEARCH` block. **Accessibility (P7):** `ProfileScreen.accessibilitySummary` now iterates `allUI` (matched to `body`) instead of `all`. **Audit hardening (P8):** Strengthened `CategoryLiteralAuditTests` patterns with word boundaries; added the new contributions/dispatcher names to the forbidden list. **New tests:** `TrainingDisciplineRegistryTests.everyDisciplineConformsToUI` (P4 — guards the `compactMap` cast against silent omission), `ProfileCardConformanceTests` (P5 — pins AC 6: defaults inherit `ProgressChartView`, overrides do not), `DisciplineSettingsSectionAggregationTests` (P6 — pins ordering and id-dedup of the contributed sections list). All four configurations green: iOS Debug 1453, macOS Debug 1447, iOS Research 1812, macOS Research 1806.

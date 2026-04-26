# Story 77.1: Plugin-style discipline UI contributions

Status: backlog

## Story

As **a developer adding or toggling a training discipline**,
I want each discipline to declare the UI surfaces it contributes (settings sections, profile card, scoped help, navigation),
so that adding a discipline is purely additive and toggling one on/off requires no edits to screens that aggregate the registry.

## Background

Story 76.3 made discipline iteration data-driven (registry → list of disciplines). Stories 76.4 and the 76.4 review further removed hardcoded counts and discipline-name leakage from docs, scripts, tests, and help copy. What remains is a smaller but architecturally significant class of issue: **screens still own category-specific UI fragments and gate them with literal category checks**.

Concretely, the current pattern in three places looks like:

- `Peach/Settings/SettingsScreen.swift` — `if activeCategories.contains(.rhythm) { rhythmSection; gapPositionsSection }` plus the section bodies declared inline in the screen.
- `Peach/App/HelpContent.swift` (`settings` closure) — `if registry.activeCategories.contains(.rhythm) { append rhythm section }`.
- `Peach/App/HelpContent.swift` (`profile` closure, after story 77.0 / I1 fix) — same pattern, gating spectrogram help on `.rhythm`.
- `Peach/Profile/ProfileScreen.swift` — `switch discipline.category { case .rhythm: …; case .pitch, .intervals: … }` to choose between `RhythmProfileCardView` and `ProgressChartView`.

Each surface manually decides what's category-gated. Adding a new toggleable discipline (or category) requires hunting all three call sites; per-discipline activation breaks `if .contains(.rhythm)` entirely (the rhythm section appears even when only one of two rhythm disciplines is active, or vice versa).

Conceive of training disciplines as **statically-compiled plugins**: each plugin contributes new functionality to several places in the app. The protocol already accepts contributions for `helpSections` (per-screen discipline help) and `navigationDestination`. This story extends the contribution model to settings sections, profile cards, and scoped help so that screens become pure aggregators of contributions.

This is a prerequisite for the planned **central activation** feature (a UI to enable/disable individual categories or individual disciplines without rebuilding). Once contributions live with the discipline, toggling activation rebuilds the registry differently and every aggregating screen reacts automatically — no per-screen literal gates to update.

## Acceptance Criteria

### AC 1: Settings section contributions

**Given** a `TrainingDiscipline` (or `TrainingCategory`) registered with the registry
**When** the discipline (or its category) needs Settings UI specific to it
**Then** it declares those sections via a protocol contribution rather than inline code in `SettingsScreen`. `SettingsScreen` iterates contributions in a stable order and renders them between the always-on common sections.

Concretely after this story:
- `SettingsScreen.swift` contains zero `.contains(.rhythm)` literals and zero category-specific section bodies.
- `rhythmSection` and `gapPositionsSection` move out of `SettingsScreen` and into the rhythm domain (per-discipline or per-category — dev's call, document choice).
- Adding a new discipline that needs its own settings requires only adding a new contribution; `SettingsScreen` is not edited.

### AC 2: Profile card contributions

**Given** a `TrainingDiscipline` registered with the registry
**When** the Profile screen renders progress for that discipline
**Then** the discipline declares which card type to use (e.g., line chart vs. spectrogram) via the protocol, and `ProfileScreen` dispatches without `switch discipline.category`.

The discipline owns enough information for `ProfileScreen` to pick the right view without category-literal branching. Two reasonable shapes (dev's call):
- An enum-typed `profileCard: ProfileCardKind` that `ProfileScreen` maps to a concrete view.
- A view-builder closure on the discipline (couples Core/App to SwiftUI helpers — likely too tight; favor the enum).

### AC 3: Scoped help contributions

**Given** the existing `HelpContent.profile` and `HelpContent.settings`
**When** a category or discipline contributes UI that needs explanatory help (e.g., spectrogram help for the rhythm category)
**Then** that help lives with the contributor, not in a global `HelpContent.swift` closure with a `.contains(.rhythm)` gate.

After this story, `HelpContent.profile` and `HelpContent.settings` either disappear entirely or shrink to their always-on common sections; per-category and per-discipline help is supplied by the contributors and assembled by the screen at render time.

### AC 4: Central-activation compatibility

**Given** the registry can in future be bootstrapped from a runtime activation set (per-category or per-discipline)
**When** the activation set changes and a new `TrainingDisciplineRegistry` is constructed
**Then** every aggregating screen and help surface reflects the new set on next render, with no further code changes — no `if .rhythm` literals to keep in sync.

This AC is verified by the absence of category literals in screens and HelpContent (a `grep` check), not by implementing the central-activation UI. That UI is a separate story.

### AC 5: Both platforms green, all four configurations

**Given** `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all tests pass under all four configurations (Debug, Debug (Research), and the macOS variants of each).

### AC 6: New tests pin the contribution invariants

**Given** the new contribution protocol additions
**When** the test suite is run
**Then** at minimum:
- A test asserts `SettingsScreen` renders the union of common sections plus contributions from `registry.activeCategories` (or `registry.all`) — verified by reading the section list, not by snapshot.
- A test asserts that for every registered discipline, its declared profile card type maps to a concrete view in `ProfileScreen` (no unmapped enum cases, no fall-through).
- A test asserts no `.contains(.rhythm)` (or any category literal) remains in `SettingsScreen.swift`, `ProfileScreen.swift`, or the post-refactor `HelpContent.swift` by source-level scan or by structural test.

## Tasks / Subtasks

- [ ] Task 1: Design the contribution protocol additions (AC: 1, 2, 3)
  - [ ] 1.1 Decide whether contributions attach to `TrainingDiscipline`, `TrainingCategory`, or both. Rhythm tempo/gap-positions are category-scoped (apply to all rhythm disciplines); spectrogram help is also category-scoped. Per-discipline help already exists.
  - [ ] 1.2 Sketch the protocol additions: `settingsSections`, `profileCard`, optional scoped help. Keep Core decoupled from SwiftUI — use enum-typed contributions (e.g., `ProfileCardKind`) that the App layer maps to views.
  - [ ] 1.3 Document the design choice in `docs/architecture-decisions/` if substantial.

- [ ] Task 2: Move rhythm settings into the rhythm domain (AC: 1)
  - [ ] 2.1 Extract `rhythmSection` and `gapPositionsSection` from `SettingsScreen.swift` into a contribution owned by the rhythm category (or the rhythm disciplines).
  - [ ] 2.2 Update `SettingsScreen` to render contributions in a stable order between the always-on common sections.
  - [ ] 2.3 Verify the section state (AppStorage bindings) remains correct after the move.

- [ ] Task 3: Move scoped help into contributors (AC: 3)
  - [ ] 3.1 Extract spectrogram help sections from `HelpContent.profile` into the rhythm category.
  - [ ] 3.2 Extract rhythm settings help from `HelpContent.settings` into the rhythm category.
  - [ ] 3.3 `HelpContent.profile` and `HelpContent.settings` shrink to common-only sections; screens append contributor sections at render time.

- [ ] Task 4: Move profile card dispatch onto the discipline (AC: 2)
  - [ ] 4.1 Add `profileCard: ProfileCardKind` (or equivalent) to the protocol with a default for pitch/intervals.
  - [ ] 4.2 Update `ProfileScreen` to read the kind from the discipline and dispatch via a single mapping table — no `switch discipline.category`.

- [ ] Task 5: Verify category-literal removal (AC: 4)
  - [ ] 5.1 `grep` for `.rhythm`, `.pitch`, `.intervals` in `Peach/Settings/SettingsScreen.swift`, `Peach/Profile/ProfileScreen.swift`, `Peach/App/HelpContent.swift`. Expected: zero hits in screen/help code (legitimate hits remain in Core / Training where each discipline declares its own category).

- [ ] Task 6: Tests and regression sweep (AC: 5, 6)
  - [ ] 6.1 Add the structural tests outlined in AC 6.
  - [ ] 6.2 `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research` — all green.
  - [ ] 6.3 `bin/build.sh && bin/build.sh -p mac` — zero new warnings.

## Dev Notes

### Plugin framing

Disciplines are statically-compiled plugins: each one contributes functionality and content to multiple places. Today the protocol already accepts contributions for help (`helpSections`) and navigation (`navigationDestination`). This story extends the same pattern to settings sections, profile cards, and scoped help. Once that's in place, adding a discipline is purely additive and toggling one on/off (manually via build config today, via a UI later) requires no screen edits.

### Per-category vs per-discipline contributions

Some surfaces are naturally per-category (rhythm tempo applies to both rhythm disciplines; spectrogram help describes the shared visualization). Others are per-discipline (already-existing `helpSections`). The contribution protocol should accept both granularities — either by attaching them to both types, or by having categories aggregate from disciplines. Document the choice in Task 1.3.

### Coupling Core to SwiftUI

The discipline protocol lives in Core (Sendable, no UI deps). Settings/profile contributions must not pull SwiftUI into Core. Use enum-typed contributions (e.g., `ProfileCardKind`, `SettingsSectionContent` as a value-type description) that the App layer maps to concrete views. The mapping lives in the App layer, not in Core.

### Why this is a prerequisite for central activation

The planned central-activation feature lets a user enable/disable categories or individual disciplines from a single UI. The activation set feeds into `DisciplineBootstrap.allDisciplines`, which constructs the registry. With contributions owned by the discipline, every aggregating screen reflects the live set automatically. With today's literal `.contains(.rhythm)` gates scattered across screens, central activation would either require updating each gate or yield inconsistent UI when an individual discipline (not a whole category) is toggled.

### What this story is NOT

- Not the central-activation UI itself — that's a separate story (call it 77.2 or whatever epic ends up containing it).
- Not a port of every cross-cutting setting (loudness, tuning system, etc.) into discipline contributions — those remain common settings, shared across all disciplines.
- Not a SwiftData migration — contribution protocol additions are pure protocol/struct, no persistence change.

### References

- 76.3 review (deferred items I1, P10, P14) — the original observations that motivated this story.
- 76.4 review (this story is the agreed deferral path for I1 + P10/P14 follow-up).
- Story 76.3 — established the data-driven iteration pattern this story extends.
- `Peach/Settings/SettingsScreen.swift` lines ~60, 217–227 — current literal-gated sections.
- `Peach/App/HelpContent.swift` (after I1 fix) — current literal-gated help closures.
- `Peach/Profile/ProfileScreen.swift` lines 21–31 — current category-switch dispatch.

## Change Log

- 2026-04-26: Drafted from 76.4 review deferred items I1 / P10 / P14 plus user direction toward a "plugin-style" contribution model and a future central-activation feature. Status → backlog.

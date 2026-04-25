# Story 76.3: Data-driven discipline iteration by category

Status: ready-for-dev

## Story

As a Peach contributor preparing for build-gated timing disciplines,
I want every UI consumer of the discipline list — `StartScreen`, `PeachCommands`, `ProfileScreen`, `HelpContent` — to iterate the registry by category instead of hardcoding the six disciplines,
so that when story 76.4 stops registering the two timing disciplines, the rhythm category disappears from every surface automatically with no per-view change.

## Context

After story 76.2, `TrainingDisciplineRegistry` is constructed from an App-provided list and each discipline declares its `TrainingCategory`. The registry is the single source of truth for which disciplines exist, but the UI doesn't ask it — every consumer hardcodes the list:

- `StartScreen.swift:80-164` — three hardcoded sections (`pitchSection`, `intervalsSection`, `rhythmSection`), each with explicit `NavigationLink` cards per discipline.
- `PeachCommands.swift:41-73` — same three hardcoded sections in the macOS Training menu.
- `PeachCommands.swift:117-138` and `:164-197` — `helpCommands` hardcodes four help buttons; the `HelpSheetContent` enum hardcodes five cases.
- `ProfileScreen.swift:21-30` — iterates `TrainingDisciplineID.canonicalIDs` (post-76.1) then switches on IDs to pick `RhythmProfileCardView` vs. `ProgressChartView`.
- `ProfileScreen.swift:60` — `accessibilitySummary` iterates `TrainingDisciplineID.canonicalIDs` to query `.config.displayName`.
- `HelpContent.swift:154` — `trainingDisciplinesDescription` is a single hardcoded localized string listing all six discipline names.

In a build that registers only four disciplines, every one of these surfaces would still try to display six (and crashes are likely once `TrainingDisciplineID.config` is accessed for an unregistered ID — see Dev Notes).

This story removes those hardcoded enumerations and routes every UI consumer through the registry. Behavior is unchanged in this story (all six disciplines are still registered after 76.2); the visible change ships in 76.4.

## Scope Boundaries

- **In scope:** `activeCategories: [TrainingCategory]` and `disciplines(in:)` API on `TrainingDisciplineRegistry`. Refactors to `StartScreen`, `PeachCommands`, `ProfileScreen`, `HelpContent` so each iterates the registry. App-layer extension on `TrainingDisciplineID` providing the `NavigationDestination` for each discipline (so views don't need a switch).
- **In scope:** small additions to the `TrainingDisciplineConfig` (or equivalent) so each discipline carries the SF Symbol name and short label that StartScreen and PeachCommands need today as hardcoded strings. Goal: views render from data, not literals.
- **In scope:** generating `HelpContent.trainingDisciplinesDescription` from registry contents at runtime, grouped by category; removing the hardcoded six-discipline string.
- **In scope:** category-section title and intro localization (one localized title and one optional intro per `TrainingCategory`), so a category absent from `activeCategories` contributes no header text.
- **Out of scope:** the `PEACH_RESEARCH` build flag (deferred to 76.4). All six disciplines are still registered; the rhythm category is still active.
- **Out of scope:** removing or changing `NavigationDestination` cases or the static `TrainingDisciplineID` declarations (both keep all six entries).
- **Out of scope:** removing the `(isIntervalMode: Bool)` parameter on `NavigationDestination.pitchDiscrimination/.pitchMatching` — internal naming cleanup is a separate concern (cf. story 71.5 dev notes).
- **Out of scope:** active-doc updates (bundled into 76.4 with the build-flag change).

## Acceptance Criteria

### AC 1: Registry exposes `activeCategories` and `disciplines(in:)`

**Given** `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift`
**When** inspected
**Then** it exposes:

```swift
/// Categories that have at least one registered discipline, in `TrainingCategory.allCases` order.
var activeCategories: [TrainingCategory] { get }

/// Disciplines registered under the given category, preserving registration order.
func disciplines(in category: TrainingCategory) -> [any TrainingDiscipline]
```

`activeCategories` returns a deduplicated, ordered list — preserving `TrainingCategory.allCases` declaration order — of categories present in `all`. A category whose `disciplines(in:)` would return an empty array MUST NOT appear in `activeCategories`.

### AC 2: `TrainingDisciplineID` has an App-side `navigationDestination`

**Given** a new file in `Peach/App/` (e.g. `TrainingDisciplineNavigation.swift`)
**When** inspected
**Then** it defines an extension:

```swift
extension TrainingDisciplineID {
    var navigationDestination: NavigationDestination {
        switch self {
        case .unisonPitchDiscrimination:    .pitchDiscrimination(isIntervalMode: false)
        case .intervalPitchDiscrimination:  .pitchDiscrimination(isIntervalMode: true)
        case .unisonPitchMatching:          .pitchMatching(isIntervalMode: false)
        case .intervalPitchMatching:        .pitchMatching(isIntervalMode: true)
        case .timingOffsetDetection:        .timingOffsetDetection
        case .continuousRhythmMatching:     .continuousRhythmMatching
        }
    }
}
```

This extension lives in App because `NavigationDestination` is App-layer. Core gets no new dependency.

### AC 3: Disciplines carry their display icon and short label

**Given** the discipline display metadata (`TrainingDisciplineConfig` or a sibling type at the dev's discretion)
**When** inspected
**Then** each discipline contributes:

- **`displayName`** — already exists, no change. Used in menus, accessibility labels, profile cards.
- **`shortLabel`** — new. Localized short string used as the StartScreen card title and PeachCommands button title. Examples: `"Compare"`, `"Match"`, `"Fill the Gap"`.
- **`systemImageName`** — new. SF Symbol name for the StartScreen card icon. Examples: `"ear"`, `"target"`, `"metronome"`, `"hand.tap"`.
- **`isHero`** — new (boolean). `true` for the discipline that should render as the prominent first card in its category. Today the hero is `unisonPitchDiscrimination`; the dev may choose to set it on the first discipline of each category, or only on the unison pitch discipline — both behaviors are acceptable. Document the choice in the story's Completion Notes.

The exact placement (extending `TrainingDisciplineConfig`, adding a sibling `TrainingDisciplineDisplay` struct, or returning a tuple) is at the dev's discretion. The constraint: **StartScreen and PeachCommands must not contain any literal SF Symbol name or short label string after this story.**

### AC 4: `StartScreen` iterates the registry by category

**Given** `Peach/Start/StartScreen.swift`
**When** inspected
**Then**:

1. The three hardcoded section views (`pitchSection`, `intervalsSection`, `rhythmSection`) are replaced by a single section-rendering helper that takes a `TrainingCategory` and renders the section header + a `NavigationLink` per discipline returned by `registry.disciplines(in: category)`.
2. The portrait and landscape layouts iterate `registry.activeCategories` and render the section helper for each.
3. The card builder (`trainingCard`) reads icon and short label from the discipline's display metadata (per AC 3), not from hardcoded literals.
4. The `navigationDestination` value is obtained from `TrainingDisciplineID.navigationDestination` (per AC 2).
5. The accessibility label for each `NavigationLink` is derived from the discipline's `displayName`, not a literal.
6. The category section header text (e.g. "Pitch", "Intervals", "Rhythm") is sourced from a localized lookup keyed on `TrainingCategory` (see AC 6), not a literal in the view.
7. The `.navigationDestination(for:)` switch on lines 54-69 remains as-is. It is exhaustive over `NavigationDestination` cases and unaffected by registry contents; if a destination is unreachable in a given build, the case is simply not invoked.

### AC 5: `PeachCommands` iterates the registry by category and for help

**Given** `Peach/App/Platform/PeachCommands.swift`
**When** inspected
**Then**:

1. The training menu (`trainingMenu`) renders one `Section` per `category` in `registry.activeCategories`, with one `trainingButton` per discipline in that category. The hardcoded `Section("Pitch")` / `Section("Intervals")` / `Section("Rhythm")` blocks (lines 61-72) are gone.
2. The section title is the localized category title (per AC 6).
3. The `trainingButton` title is the discipline's `displayName` (or a longer label appropriate to a menu — dev's call, must come from data not literal).
4. The `destination` parameter is obtained from `TrainingDisciplineID.navigationDestination`.
5. The `helpCommands` block (lines 117-138) renders one help button per registered discipline (iterating `registry.all`), with the button title derived from the discipline's display metadata, not a hardcoded `"Pitch Compare Help"` string. The "About Peach" button stays as-is.
6. The `HelpSheetContent` enum (lines 164-197) is replaced or rewritten so it carries a `TrainingDisciplineID` payload (e.g. `case discipline(TrainingDisciplineID)`) and resolves `title` and `sections` by looking up via the registry. The `case .about` stays. After this story, `HelpSheetContent` does not enumerate disciplines case-by-case.

### AC 6: Category titles and intros are data-driven

**Given** a new App-side or Core-side source of localized strings keyed by `TrainingCategory`
**When** inspected
**Then** there is a single function or property mapping each `TrainingCategory` case to:

- `localizedTitle: String` — used as the StartScreen and PeachCommands section header. Today's values: "Pitch", "Intervals", "Rhythm".
- `localizedIntro: String?` — optional. Used by `HelpContent` to introduce a category section in the discipline description (see AC 7). May be `nil` if no intro is desired.

Place this mapping where it best fits the project (App if it ties to UI, Core if shared). All `String(localized:)` keys for category titles live in this single place — `StartScreen` and `PeachCommands` must not duplicate them.

### AC 7: `HelpContent.trainingDisciplinesDescription` is generated from the registry

**Given** `Peach/App/HelpContent.swift`
**When** inspected
**Then**:

1. The hardcoded six-discipline string at line 154 is replaced by a computed property (or function) that walks `registry.activeCategories.flatMap { registry.disciplines(in: $0) }` and produces a localized markdown-formatted description by emitting **one paragraph per discipline**, in the same `**Name** – Description.\n\n` shape as today.
2. Each discipline contributes its own `helpDescription: String` (or equivalent) — a new localized property on the discipline's display metadata. Existing prose from line 154 (e.g. `"Listen to two notes and decide which one is higher."`) is migrated into per-discipline `helpDescription` strings, preserving wording and German translations.
3. If `registry.activeCategories` does not contain `.rhythm`, the generated description naturally omits both rhythm-discipline paragraphs — no per-string `if` needed.
4. If a category has a non-nil `localizedIntro` (per AC 6), the generated description includes one intro paragraph per category before its disciplines. The decision to include intros is the dev's; if not adopted in this story, leave `localizedIntro` returning `nil` for all categories.
5. The legacy `trainingDisciplinesDescription` localized key is removed from `Localizable.xcstrings`, and its German translation is migrated into the per-discipline `helpDescription` German translations.

### AC 8: `ProfileScreen` iterates the registry, not the enum

**Given** `Peach/Profile/ProfileScreen.swift`
**When** inspected
**Then**:

1. Line 21's `ForEach(TrainingDisciplineID.canonicalIDs, id: \.self)` (post-76.1 form) becomes `ForEach(registry.all, id: \.id)` (or `ForEach(registry.all.map(\.id), id: \.self)` — dev's call).
2. Line 23's `switch mode { case .timingOffsetDetection, .continuousRhythmMatching: ... default: ... }` becomes `switch discipline.category { case .rhythm: RhythmProfileCardView(mode: discipline.id); default: ProgressChartView(mode: discipline.id) }` or equivalent — selection is by **category**, not by static-ID identity.
3. Line 60's `accessibilitySummary` static function iterates `registry.all` (or accepts the registry as a parameter — dev's call) instead of `TrainingDisciplineID.canonicalIDs`.
4. `accessibilitySummary` continues to filter by `progressTimeline.state(for:) != .noData` and continues to join `displayName`s with `, `.

### AC 9: No remaining `TrainingDisciplineID.canonicalIDs` usages query metadata

**Given** the codebase
**When** searched with `grep -rn "TrainingDisciplineID.canonicalIDs" Peach/ PeachTests/`
**Then** every remaining usage either:

- Iterates purely for the identifier catalog's own structural integrity (e.g. a test that exercises every declared static independently of registration), **or**
- Is documented in a comment explaining why iterating registered disciplines via the registry would be wrong here.

Calls of the form `TrainingDisciplineID.canonicalIDs.map { $0.config.displayName }` or any access to `.config` / `.statisticsKeys` on canonical IDs that may not be registered are NOT acceptable — these would crash in a build that registers fewer than all canonical IDs (see Dev Notes).

### AC 10: All six disciplines still appear in this build

**Given** a built and launched app on iOS or macOS
**When** the user navigates the StartScreen, training menus, profile, settings, help, and runs each of the six disciplines
**Then** observable behavior is identical to before this story. Six disciplines, three categories, all help text intact, German translations intact.

### AC 11: Both platforms green

**Given** the full test suite
**When** run via `bin/test.sh` and `bin/test.sh -p mac`
**Then** all tests pass with zero regressions, and `bin/build.sh && bin/build.sh -p mac` emits zero new warnings. Tests that previously asserted `TrainingDisciplineID.canonicalIDs` invariants on metadata are migrated to assert against `registry.all` instead.

## Tasks / Subtasks

- [ ] Task 1: Extend registry with `activeCategories` and `disciplines(in:)` (AC: 1)
  - [ ] 1.1 Implement `disciplines(in:)` as a filter over `all`
  - [ ] 1.2 Implement `activeCategories` preserving `TrainingCategory.allCases` order, deduplicated, omitting empty categories
  - [ ] 1.3 Add Core unit tests using synthetic discipline fixtures (parameterized over generated input — see Dev Notes)
- [ ] Task 2: Add App-side `TrainingDisciplineID.navigationDestination` (AC: 2)
  - [ ] 2.1 Create `Peach/App/TrainingDisciplineNavigation.swift` with the extension
  - [ ] 2.2 Add to both iOS and macOS targets
- [ ] Task 3: Add display metadata (`shortLabel`, `systemImageName`, `isHero`, `helpDescription`) (AC: 3, 7)
  - [ ] 3.1 Decide placement (extend `TrainingDisciplineConfig` or sibling type)
  - [ ] 3.2 Populate values for each of the six disciplines, migrating from current StartScreen/PeachCommands literals and `HelpContent.trainingDisciplinesDescription`
  - [ ] 3.3 Add localized strings to `Localizable.xcstrings` with German translations (preserve existing tone — `du` / imperative per `feedback_german_informal.md`)
- [ ] Task 4: Add category title/intro mapping (AC: 6)
  - [ ] 4.1 Place mapping function/property in App (or Core if used in both)
  - [ ] 4.2 Add `Pitch` / `Intervals` / `Rhythm` localized titles (already in catalog — likely just a reference)
  - [ ] 4.3 Decide on intros (AC 7); if not used, leave `nil` returns
- [ ] Task 5: Refactor `StartScreen` (AC: 4)
  - [ ] 5.1 Replace `pitchSection`/`intervalsSection`/`rhythmSection` with a single `categorySection(_ category:)` helper
  - [ ] 5.2 Iterate `registry.activeCategories` in both portrait and landscape layouts
  - [ ] 5.3 Update `trainingCard` to consume display metadata
  - [ ] 5.4 Source `NavigationLink` destination from `TrainingDisciplineID.navigationDestination`
  - [ ] 5.5 Source accessibility label from `displayName`
- [ ] Task 6: Refactor `PeachCommands` training menu (AC: 5)
  - [ ] 6.1 Replace hardcoded sections with iteration over `registry.activeCategories`
  - [ ] 6.2 Source destinations and titles from registry data
- [ ] Task 7: Refactor `PeachCommands` help and `HelpSheetContent` (AC: 5)
  - [ ] 7.1 Iterate `registry.all` to produce help buttons
  - [ ] 7.2 Refactor `HelpSheetContent` to carry a `TrainingDisciplineID` payload, drop per-discipline cases
  - [ ] 7.3 Resolve title and sections via the registry
- [ ] Task 8: Refactor `HelpContent.trainingDisciplinesDescription` (AC: 7)
  - [ ] 8.1 Replace static string with computed property generating from `registry`
  - [ ] 8.2 Migrate per-discipline descriptions to `helpDescription` strings (English + German)
  - [ ] 8.3 Remove the legacy `trainingDisciplinesDescription` localization key + German translation from `Localizable.xcstrings`
  - [ ] 8.4 Verify `bin/add-localization.swift --missing` shows no new orphans
- [ ] Task 9: Refactor `ProfileScreen` (AC: 8)
  - [ ] 9.1 Switch `ForEach` to iterate `registry.all`
  - [ ] 9.2 Switch on `discipline.category` instead of enum cases
  - [ ] 9.3 Update `accessibilitySummary` to iterate registry
  - [ ] 9.4 Rename local variables in this file: loop binding `mode` → `discipline`, `activeModes` → `activeDisciplines`, `modeNames` → `disciplineNames` (per `feedback_disciplines_not_modes.md`). Scope is `ProfileScreen.swift` only — call-site parameter names like `RhythmProfileCardView(mode:)` and `ProgressChartView(mode:)` stay unchanged here; renaming them would propagate across the Profile module and is a separate concern.
- [ ] Task 10: Audit remaining `TrainingDisciplineID.canonicalIDs` usages (AC: 9)
  - [ ] 10.1 `grep -rn "TrainingDisciplineID.canonicalIDs" Peach/ PeachTests/`
  - [ ] 10.2 For each hit, determine if it queries metadata (replace) or asserts identifier-catalog structure (keep with comment)
  - [ ] 10.3 Migrate metadata-querying tests to iterate `registry.all`
- [ ] Task 11: Build & test both platforms (AC: 10, 11)
  - [ ] 11.1 `bin/build.sh && bin/build.sh -p mac` — zero new warnings
  - [ ] 11.2 `bin/test.sh && bin/test.sh -p mac` — all tests green
  - [ ] 11.3 Manual smoke: launch app, verify StartScreen still shows six disciplines in three sections, profile cards still render correctly, both German and English UI

## Dev Notes

### Why empty categories must vanish

If StartScreen iterated `TrainingCategory.allCases` and rendered a section per case, an empty category (e.g. rhythm in a build with no rhythm disciplines registered) would produce a section header with no cards underneath — visually broken. The contract for `activeCategories` is that **a category appears in the list iff at least one discipline in that category is registered.** This makes the consumer code simple (`ForEach(activeCategories) { categorySection($0) }`) and means no `if` checks at the call site.

The same applies to help content: if the rhythm category has no disciplines, the discipline description must not include "Rhythm:" with nothing under it. The generator produces only paragraphs that have content.

### Why `TrainingDisciplineID.canonicalIDs` is dangerous after this work

`TrainingDisciplineID.config` and `.statisticsKeys` lookup via `TrainingDisciplineRegistry.shared[self].config` — and the subscript force-unwraps `byID[id]!`. Once registration becomes build-conditional (story 76.4), calling `.config` on an unregistered ID will crash. The fix is to iterate `registry.all` everywhere — never `TrainingDisciplineID.canonicalIDs` — when the goal is "do something for each currently-available discipline."

The static factory list itself keeps all six entries (we want the code to compile in all configurations and `NavigationDestination` to remain stable for restoration). The IDs simply aren't referenced from the registry in the gated build.

### Data-driven testing per Quinn

Per the party-mode discussion and the user's stated preference for data-driven tests:

- **Core registry tests** for `activeCategories` and `disciplines(in:)` should use synthetic discipline fixtures, not the real `DisciplineBootstrap.allDisciplines`. Generate disciplines at varying counts and category mixes; assert structural invariants (deduplication, order preservation, empty-category exclusion).
- **App-level tests** that touch real disciplines (e.g. a snapshot test of StartScreen) iterate `registry.all` to drive their assertions instead of hardcoding lists.
- No test in this story should assert `registry.all.count == 6`. The existing such assertion in `TrainingDisciplineRegistryTests` is left for story 76.4 to remove.

### Localization tone

German translations follow `feedback_german_informal.md` (informal `du` / imperative). Per-discipline `helpDescription` German strings should match the tone of the existing `trainingDisciplinesDescription` German translation; do not re-translate from English if the existing German is acceptable — extract the per-discipline paragraphs from it.

### Preserving `(isIntervalMode: Bool)` parameter on NavigationDestination

The `(isIntervalMode: Bool)` parameter on `NavigationDestination.pitchDiscrimination` and `.pitchMatching` is internal naming (cf. story 71.5 dev notes). Do not rename it in this story. The discipline-side knowledge that "Unison maps to `false`, Interval maps to `true`" is encoded in `TrainingDisciplineID.navigationDestination`.

### What if `isHero` styling needs more nuance?

If hero styling on the first card per category produces a worse visual than hero only on `unisonPitchDiscrimination`, prefer the latter and document the choice. Visual hierarchy is not a goal of this story.

### References

- `MEMORY.md → feedback_design_by_contract_and_separation.md` — UI consumes data, doesn't enumerate
- `MEMORY.md → feedback_disciplines_not_modes.md` — terminology for any new strings
- `MEMORY.md → feedback_german_informal.md` — German tone
- `StartScreen.swift:80-164`, `PeachCommands.swift:41-138, 164-197`, `ProfileScreen.swift:21-66`, `HelpContent.swift:154-156` — current call sites being refactored
- Story 76.1 — relocated `TrainingDisciplineID`'s named instances to `App/Training/DisciplineIDs.swift`
- Story 76.2 — provides `TrainingCategory` and the bootstrap pattern this story consumes

## Change Log

- 2026-04-25: Story drafted as Story 76.3 of Epic 76. Renumbered from original 76.2 when a new 76.1 (relocate `TrainingDisciplineID` to App) was inserted. Status → ready-for-dev. Depends on Stories 76.1 and 76.2.

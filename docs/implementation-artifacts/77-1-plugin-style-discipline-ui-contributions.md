# Story 77.1: Plugin-style discipline UI contributions and per-discipline compile-time activation

Status: backlog

## Story

As **a developer adding, removing, or toggling a training discipline**,
I want each discipline to declare the UI surfaces it contributes (settings sections, profile card, scoped help, navigation) **and** I want to be able to enable or disable any individual discipline at compile time from a single file,
so that adding a discipline is purely additive, removing or muting one is a one-line change in one place, and screens that aggregate the registry need no edits when the active set changes.

## Background

Story 76.3 made discipline iteration data-driven (registry → list of disciplines). Stories 76.4 and the 76.4 review further removed hardcoded counts and discipline-name leakage from docs, scripts, tests, and help copy. What remains is a smaller but architecturally significant class of issue: **screens still own category-specific UI fragments and gate them with literal category checks**, and the only build-time activation switch is category-grained (the `PEACH_RESEARCH` flag toggles both timing disciplines together).

Concretely, the current pattern in three places looks like:

- `Peach/Settings/SettingsScreen.swift` — `if activeCategories.contains(.rhythm) { rhythmSection; gapPositionsSection }` plus the section bodies declared inline in the screen.
- `Peach/App/HelpContent.swift` (`settings` closure) — `if registry.activeCategories.contains(.rhythm) { append rhythm section }`.
- `Peach/App/HelpContent.swift` (`profile` closure, after story 77.0 / I1 fix) — same pattern, gating spectrogram help on `.rhythm`.
- `Peach/Profile/ProfileScreen.swift` — `switch discipline.category { case .rhythm: …; case .pitch, .intervals: … }` to choose between `RhythmProfileCardView` and `ProgressChartView`.

Each surface manually decides what's category-gated. Adding a new toggleable discipline (or category) requires hunting all three call sites; per-discipline activation breaks `if .contains(.rhythm)` entirely (e.g., a build that registers only one of the two rhythm disciplines would still hit `activeCategories.contains(.rhythm)` and render a section that includes UI for the absent discipline).

Conceive of training disciplines as **statically-compiled plugins**: each plugin contributes new functionality to several places in the app. The protocol already accepts contributions for `helpSections` (per-screen discipline help) and `navigationDestination`. This story extends the contribution model to settings sections, profile cards, and scoped help so that screens become pure aggregators of contributions.

This story also introduces a **single-place, compile-time, per-discipline activation switch**. Today `DisciplineBootstrap.allDisciplines` is the registry's only source of truth, and the only granularity available is the `PEACH_RESEARCH` flag, which toggles both timing disciplines as a unit. After this story, a developer can flip any individual discipline on or off by editing one line in one file — without altering the public `Debug` / `Debug (Research)` / `Release` / `Release (Research)` build configurations established by 76.4. This is a developer-ergonomics feature, not a runtime feature; there is no user-facing activation UI planned now or later.

The two changes are complementary: per-discipline activation is what makes `if activeCategories.contains(.rhythm)` actively misleading (a category may be active with only some of its disciplines registered), and plugin-style contributions are what let the screen render the correct subset automatically once activation is per-discipline.

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

### AC 4: Single-place per-discipline compile-time activation

**Given** a developer who wants to compile out (or back in) any individual training discipline for a build
**When** they open the project's single activation source-of-truth (e.g., `Peach/App/Training/DisciplineBootstrap.swift`, or a sibling `DisciplineActivation.swift` that `DisciplineBootstrap` reads from — dev's call)
**Then** they can flip one declaration per discipline (a `#if` guard, a `Bool` literal, or a commented-out factory line — dev's call) to control whether that discipline is registered, with **no other source files touched**.

Constraints:
- All per-discipline toggles live in **one file**. A dev grepping for "where do I disable a discipline?" finds exactly one location.
- Granularity is **per-discipline**, not per-category. A build may register `UnisonPitchMatching` while excluding `IntervalPitchMatching`; or register `TimingOffsetDetection` without `ContinuousRhythmMatching`.
- The existing `PEACH_RESEARCH` build flag continues to drive the App Store / Research split established by 76.4 — the four pitch disciplines remain on by default in every configuration; the two timing disciplines remain gated on `PEACH_RESEARCH` by default. The new mechanism gives the *developer* per-discipline override capability inside that envelope; it does not change which disciplines ship in the public build.
- The mechanism is compile-time only. There is no `UserDefaults`-backed runtime override, no debug menu, no remote config. Toggling a discipline always requires a rebuild.

Acceptable shapes (any one of these — dev picks; document the choice in Completion Notes):

```swift
// Shape A: list with explicit per-discipline activation booleans
enum DisciplineBootstrap {
    static let allDisciplines: [any TrainingDiscipline] = {
        let candidates: [(active: Bool, factory: () -> any TrainingDiscipline)] = [
            (true,  { UnisonPitchDiscriminationDiscipline() }),
            (true,  { IntervalPitchDiscriminationDiscipline() }),
            (true,  { UnisonPitchMatchingDiscipline() }),
            (true,  { IntervalPitchMatchingDiscipline() }),
            #if PEACH_RESEARCH
            (true,  { TimingOffsetDetectionDiscipline() }),
            (true,  { ContinuousRhythmMatchingDiscipline() }),
            #endif
        ]
        return candidates.compactMap { $0.active ? $0.factory() : nil }
    }()
}
```

```swift
// Shape B: dedicated activation enum that DisciplineBootstrap reads
enum DisciplineActivation {
    static let unisonPitchDiscrimination = true
    static let intervalPitchDiscrimination = true
    static let unisonPitchMatching = true
    static let intervalPitchMatching = true
    #if PEACH_RESEARCH
    static let timingOffsetDetection = true
    static let continuousRhythmMatching = true
    #else
    static let timingOffsetDetection = false
    static let continuousRhythmMatching = false
    #endif
}
```

```swift
// Shape C: per-discipline #if blocks all in one file (lowest-ceremony)
enum DisciplineBootstrap {
    static let allDisciplines: [any TrainingDiscipline] = {
        var disciplines: [any TrainingDiscipline] = []
        #if !PEACH_DISABLE_UNISON_PITCH_DISCRIMINATION
        disciplines.append(UnisonPitchDiscriminationDiscipline())
        #endif
        // … one block per discipline …
        return disciplines
    }()
}
```

The constraint is shape-agnostic: one file, per-discipline, compile-time, with the `PEACH_RESEARCH` envelope preserved.

### AC 5: Activation invariance — no literal category gates anywhere

**Given** the active discipline set may legitimately be any subset of `DisciplineBootstrap`'s catalog (after AC 4)
**When** the registry is constructed with that subset and any aggregating screen renders
**Then** every aggregating screen and help surface reflects the registered set on next render, with **no `.contains(.rhythm)`, `.contains(.pitch)`, or `.contains(.intervals)` literals and no `switch discipline.category` blocks** in `SettingsScreen.swift`, `ProfileScreen.swift`, or `HelpContent.swift`.

This AC is verified by the absence of category literals in those files (a `grep` check or a structural test), not by adding a UI to flip activation. The only legitimate category-literal usages remain in Core / Training where each discipline declares its own category, and in `TrainingCategory`'s own enum machinery.

### AC 6: Both platforms green, all four configurations

**Given** `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all tests pass under all four configurations (Debug, Debug (Research), Release, Release (Research) on both iOS and macOS).

Additionally, a one-off developer-only verification: temporarily disable one pitch discipline using the AC 4 mechanism, build and launch, confirm the app starts and the disabled discipline's UI surface is absent, then revert. (Not a permanent test; documented in Completion Notes as a manual smoke test.)

### AC 7: New tests pin the contribution and activation invariants

**Given** the new contribution protocol additions and the new per-discipline activation mechanism
**When** the test suite is run
**Then** at minimum:
- A test asserts `SettingsScreen` renders the union of common sections plus contributions from `registry.all` (or `registry.activeCategories`) — verified by reading the section list, not by snapshot.
- A test asserts that for every registered discipline, its declared profile card type maps to a concrete view in `ProfileScreen` (no unmapped enum cases, no fall-through).
- A test asserts no `.contains(.rhythm)` (or any category literal) and no `switch discipline.category` remains in `SettingsScreen.swift`, `ProfileScreen.swift`, or the post-refactor `HelpContent.swift` by source-level scan or by structural test.
- A test exercises the activation mechanism's value-correctness without flipping the production toggles: e.g., construct a `TrainingDisciplineRegistry` from a synthesized subset of `DisciplineBootstrap.allDisciplines` and assert every aggregating helper (settings sections, help sections, profile card mapping) yields exactly the contributions for that subset and nothing more.

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

- [ ] Task 5: Implement per-discipline compile-time activation (AC: 4)
  - [ ] 5.1 Pick one of Shape A / B / C (or an equivalent) and refactor `DisciplineBootstrap.swift` accordingly. Document the choice and rationale in Completion Notes.
  - [ ] 5.2 Preserve the `PEACH_RESEARCH` envelope: in default configurations, the active set is unchanged from today (4 in `Debug`/`Release`, 6 in `Debug (Research)`/`Release (Research)`).
  - [ ] 5.3 Confirm that the activation file is the **only** place a developer needs to edit to disable a discipline. Audit any other source location that might short-circuit registration (there should be none after 76.4, but verify).
  - [ ] 5.4 Add a brief comment block at the top of the activation file explaining the convention (per-discipline, compile-time, single source of truth).

- [ ] Task 6: Verify category-literal and category-switch removal (AC: 5)
  - [ ] 6.1 `grep` for `.rhythm`, `.pitch`, `.intervals` and for `switch.*\.category` in `Peach/Settings/SettingsScreen.swift`, `Peach/Profile/ProfileScreen.swift`, `Peach/App/HelpContent.swift`. Expected: zero hits in screen/help code (legitimate hits remain in Core / Training where each discipline declares its own category).

- [ ] Task 7: Tests and regression sweep (AC: 6, 7)
  - [ ] 7.1 Add the structural and value-correctness tests outlined in AC 7.
  - [ ] 7.2 `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research` — all green.
  - [ ] 7.3 `bin/build.sh && bin/build.sh -p mac` — zero new warnings.
  - [ ] 7.4 Manual smoke test: temporarily disable one pitch discipline via the AC 4 mechanism, build, launch, confirm absence of its UI; revert. Note in Completion Notes.

## Dev Notes

### Plugin framing

Disciplines are statically-compiled plugins: each one contributes functionality and content to multiple places. Today the protocol already accepts contributions for help (`helpSections`) and navigation (`navigationDestination`). This story extends the same pattern to settings sections, profile cards, and scoped help. Once that's in place, adding a discipline is purely additive and toggling one on or off (via the AC 4 activation mechanism) requires no screen edits.

### Per-category vs per-discipline contributions

Some surfaces are naturally per-category (rhythm tempo applies to both rhythm disciplines; spectrogram help describes the shared visualization). Others are per-discipline (already-existing `helpSections`). The contribution protocol should accept both granularities — either by attaching them to both types, or by having categories aggregate from disciplines. Document the choice in Task 1.3.

### Coupling Core to SwiftUI

The discipline protocol lives in Core (Sendable, no UI deps). Settings/profile contributions must not pull SwiftUI into Core. Use enum-typed contributions (e.g., `ProfileCardKind`, `SettingsSectionContent` as a value-type description) that the App layer maps to concrete views. The mapping lives in the App layer, not in Core.

### Why per-discipline activation is compile-time only

A `UserDefaults`-backed or remote-configurable runtime activation switch was considered and explicitly rejected by the user. Rationale, in order of weight:

1. **No user-facing need.** The user has not requested and does not plan a UI for end users to enable or disable disciplines. The set a user sees is the set the build ships.
2. **App Review surface.** A runtime-toggleable feature in the App Store binary is reviewable functionality; compile-time gating leaves no dormant code path that needs disclosure (see story 76.4 Dev Notes for the same reasoning applied to `PEACH_RESEARCH`).
3. **Honesty of the binary.** A `Release` build that compiles out a discipline genuinely cannot construct it; users cannot stumble into half-finished features via debug menus or URL schemes.
4. **Lower implementation cost.** No persistence layer, no migration story, no "discipline disabled mid-session" edge case, no observability into activation drift.

The compile-time mechanism is a developer-ergonomics improvement: it makes per-discipline experiments and bisection cheaper. It is not an architectural step toward any runtime feature.

### Why the `PEACH_RESEARCH` envelope is preserved

Story 76.4 established `PEACH_RESEARCH` as the single externally-visible build-configuration knob that distinguishes the App Store cut (4 disciplines) from the TestFlight Research cut (6 disciplines). Per-discipline activation lives **inside** that envelope: by default, every discipline's activation expression respects `PEACH_RESEARCH`, so the public configurations behave exactly as today. The new mechanism gives the developer a one-line override capability for local builds without touching the project's build configuration matrix.

### Coupling between contributions and activation

Per-discipline activation makes `if activeCategories.contains(.rhythm)` not just verbose but **wrong**: a build that registers only `ContinuousRhythmMatching` (not `TimingOffsetDetection`) still has `.rhythm` in `activeCategories`, so the literal-gated section appears — but the gated section may include UI for the absent discipline. Plugin-style contributions resolve this structurally: each registered discipline contributes its own UI; the screen iterates registered contributions, never categories. This is why AC 4 (activation) and ACs 1–3, 5 (contributions) belong in the same story.

### What this story is NOT

- **Not a runtime activation feature.** No UI, no `UserDefaults` flag, no debug menu. Compile-time only.
- **Not a follow-up story for runtime activation.** There is no planned Story 77.2 for a "central activation UI". If one is ever wanted, it would be a separate epic with separate justification.
- **Not a port of every cross-cutting setting** (loudness, tuning system, etc.) into discipline contributions — those remain common settings, shared across all disciplines.
- **Not a SwiftData migration** — contribution protocol additions are pure protocol/struct, no persistence change.
- **Not a change to the public build-configuration matrix.** The four configurations from 76.4 (`Debug`, `Debug (Research)`, `Release`, `Release (Research)`) and their default discipline sets are unchanged.

### References

- 76.3 review (deferred items I1, P10, P14) — the original observations that motivated this story.
- 76.4 review (this story is the agreed deferral path for I1 + P10/P14 follow-up).
- Story 76.3 — established the data-driven iteration pattern this story extends.
- Story 76.4 — established `PEACH_RESEARCH` as the single externally-visible build envelope; this story preserves that envelope.
- `Peach/App/Training/DisciplineBootstrap.swift` — current activation source-of-truth (category-grained today, per-discipline after this story).
- `Peach/Settings/SettingsScreen.swift` lines ~60, 217–227 — current literal-gated sections.
- `Peach/App/HelpContent.swift` (after I1 fix) — current literal-gated help closures.
- `Peach/Profile/ProfileScreen.swift` lines 21–31 — current category-switch dispatch.

## Change Log

- 2026-04-26: Drafted from 76.4 review deferred items I1 / P10 / P14 plus user direction toward a "plugin-style" contribution model. Status → backlog.
- 2026-04-26: Reframed. Removed false claim that a runtime "central activation" feature is planned (it is not). Expanded scope to include a single-place, compile-time, per-discipline activation mechanism (new AC 4). Renumbered subsequent ACs (5–7) and tasks (5–7). Story title and user-story updated to reflect the dual scope. Status remains backlog.

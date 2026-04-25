# Story 76.1: Relocate TrainingDisciplineID's concrete cases to the App layer

Status: ready-for-dev

## Story

As a Peach contributor preparing the registry refactor for build-gated timing disciplines,
I want `TrainingDisciplineID` in `Core/` reduced to a slug-wrapping struct with no concrete-feature knowledge, and the named instances (`.unisonPitchDiscrimination`, `.intervalPitchMatching`, `.timingOffsetDetection`, …) declared in an App-side extension,
so that Core defines only the **identifier shape** while App owns the **identity catalog** — completing the Core/App separation that stories 76.2, 76.3, and 76.4 build on.

## Context

Today `TrainingDisciplineID` is an `enum String, CaseIterable, Sendable` in `Peach/Core/Training/TrainingDisciplineID.swift` whose six cases name concrete training features. That makes Core know about pitch, intervals, and rhythm by name — a layering inversion that was acceptable while the discipline list was fixed but blocks the upcoming work:

- Story 76.2 introduces `TrainingCategory` and relocates the concrete bootstrap to App. With the enum still in Core, Core continues to dictate the catalog shape.
- Story 76.4 conditionally registers the timing disciplines on a build flag. The two timing cases would still exist in Core (loud `static let timingOffsetDetection = TrainingDisciplineID(...)` references in App would be dead in `Release`, but the Core enum couldn't be trimmed without breaking the type).

Converting the enum to a struct that wraps the slug — with named static factories living next to the discipline conformances in App — pushes all concrete-feature knowledge out of Core in a single touch. The slug stays string-stable (the existing raw values become the struct's `slug` payload), so persisted data, CSV imports, and the registry's string lookups are unaffected.

This is a pure layering refactor with **zero observable behavior change**. It is the foundation for stories 76.2–76.4.

## Scope Boundaries

- **In scope:** rewriting `Core/Training/TrainingDisciplineID.swift` as a struct wrapping `slug: String`, with `Hashable`, `Sendable`, and `Codable` conformances; preserving `var slug: String { rawValue }` semantics under the new shape.
- **In scope:** new file `Peach/App/Training/DisciplineIDs.swift` (location is dev's call as long as it sits under `App/`) containing the `extension TrainingDisciplineID { static let unisonPitchDiscrimination = ...; ... }` declarations for all six current IDs.
- **In scope:** call-site migration — every exhaustive `switch` over `TrainingDisciplineID` cases gains a `default:` (or is restructured to dispatch via the registry / category / polymorphism) so the codebase compiles without `CaseIterable`.
- **In scope:** test migration where tests reference `TrainingDisciplineID.allCases` directly. They become iteration over a small static collection or `registry.all.map(\.id)` (per-test dev's call).
- **In scope:** preserving the singleton `TrainingDisciplineRegistry.shared` access pattern. `TrainingDisciplineID.config` and `.statisticsKeys` continue to delegate to the registry exactly as they do today.
- **Out of scope:** introducing `TrainingCategory` or moving concrete discipline construction out of `TrainingDisciplineRegistry.private init()` (that's story 76.2). The hardcoded six-discipline list remains inside the registry's private init for this story.
- **Out of scope:** any UI iteration changes (deferred to 76.3). `StartScreen`, `PeachCommands`, `ProfileScreen`, `HelpContent` keep their hardcoded discipline references.
- **Out of scope:** the `PEACH_RESEARCH` build flag (deferred to 76.4). All six static IDs are declared in this story.
- **Out of scope:** documenting the new layering in `arc42.md` / `glossary.md` / `project-context.md` (bundled into 76.4 with the user-visible change).

## Acceptance Criteria

### AC 1: `TrainingDisciplineID` is a slug-wrapping struct in Core with no concrete-feature knowledge

**Given** `Peach/Core/Training/TrainingDisciplineID.swift`
**When** the file is opened
**Then** it defines:

```swift
import Foundation

/// Stable identifier for a training discipline.
///
/// Identity is the `slug` string. Named instances (`.unisonPitchDiscrimination`,
/// `.timingOffsetDetection`, …) are declared in `App/Training/DisciplineIDs.swift`
/// — Core owns only the identifier shape; App owns the identity catalog.
struct TrainingDisciplineID: Hashable, Sendable, Codable {
    let slug: String

    init(_ slug: String) {
        self.slug = slug
    }

    var config: TrainingDisciplineConfig {
        TrainingDisciplineRegistry.shared[self].config
    }

    var statisticsKeys: [StatisticsKey] {
        TrainingDisciplineRegistry.shared[self].statisticsKeys
    }
}
```

The file contains **no string literal naming a concrete discipline** (no `"pitch-discrimination"`, no `"timing-offset-detection"`, etc.) and **no reference to a concrete `*Discipline` type**. A grep for `pitch|interval|timing|continuous|rhythm` in this file matches only the doc comment.

`Codable` is included so any future direct serialization (e.g. CSV header introspection) works without retrofitting. Today's CSV layer keys on the discipline's `csvTrainingType`, not on `TrainingDisciplineID` directly, so adding `Codable` is precautionary, not load-bearing.

### AC 2: App-side `DisciplineIDs.swift` declares the six static factories

**Given** the new file `Peach/App/Training/DisciplineIDs.swift`
**When** inspected
**Then** it defines:

```swift
extension TrainingDisciplineID {
    static let unisonPitchDiscrimination    = TrainingDisciplineID("pitch-discrimination")
    static let intervalPitchDiscrimination  = TrainingDisciplineID("interval-discrimination")
    static let unisonPitchMatching          = TrainingDisciplineID("pitch-matching")
    static let intervalPitchMatching        = TrainingDisciplineID("interval-matching")
    static let timingOffsetDetection        = TrainingDisciplineID("timing-offset-detection")
    static let continuousRhythmMatching     = TrainingDisciplineID("continuous-rhythm-matching")
}
```

The slug strings exactly match the current enum's raw values — this is the single point of behavior preservation for CSV import, registry lookup, and any persisted data.

The `App/Training/` directory is created if it does not already exist. The file is added to both iOS and macOS targets.

### AC 3: A canonical-list helper exists for tests and other "all known IDs" needs

**Given** that `CaseIterable.allCases` no longer exists on `TrainingDisciplineID`
**When** something needs the full set of currently-known IDs (predominantly tests today, possibly the registry's bootstrap in story 76.2)
**Then** there is one canonical source declared alongside the static factories in `App/Training/DisciplineIDs.swift`:

```swift
extension TrainingDisciplineID {
    /// All discipline IDs currently declared by the App. This is the historical
    /// `allCases` set; production code should prefer iterating `TrainingDisciplineRegistry.shared.all`
    /// since that reflects what is actually registered (which becomes build-conditional in 76.4).
    static let canonicalIDs: [TrainingDisciplineID] = [
        .unisonPitchDiscrimination,
        .intervalPitchDiscrimination,
        .unisonPitchMatching,
        .intervalPitchMatching,
        .timingOffsetDetection,
        .continuousRhythmMatching,
    ]
}
```

The doc comment makes the intent explicit: this list **is** the identifier catalog (so tests of structural invariants can iterate it), but it is **not** the right collection for "do something for each available discipline" — that's `registry.all`.

### AC 4: Each discipline conformance still references its ID symbolically

**Given** the six concrete `TrainingDiscipline` conforming structs in `Peach/Training/.../Discipline/`
**When** inspected
**Then** each `id` property continues to read like `var id: TrainingDisciplineID { .unisonPitchDiscrimination }` (or the equivalent for that discipline). No concrete discipline file constructs `TrainingDisciplineID(...)` from a string literal.

The conformances live under `Peach/Training/...` (App-layer feature code), so they can see the App-side extension on `TrainingDisciplineID` without any new dependency.

### AC 5: Exhaustive switches over IDs gain a `default` branch (or are restructured)

**Given** the production call sites that today switch exhaustively on `TrainingDisciplineID` cases — known instances:

- `Peach/Profile/ProfileScreen.swift:23` — `switch mode { case .timingOffsetDetection, .continuousRhythmMatching: ... default: ... }`
- `Peach/Start/StartScreen.swift:64` — switch on `mode` for icon/label assignment
- `Peach/App/Platform/PeachCommands.swift:178, 191` — switch on `mode` for help labels and sheet content
- `Peach/App/TrainingLifecycleCoordinator.swift:66, 162` — switch on `mode` for session dispatch
- `Peach/Core/Profile/StatisticalSummary.swift` — switch on `mode` for statistics layout

**When** the codebase is built after this story
**Then** each of these compiles. The minimum acceptable change is to add `default:` (matching today's behavior — typically the pitch-comparison branch). Where the switch can be restructured to dispatch via the registry or the discipline polymorphically (e.g. `coordinator.session(for: id)` looking up via a `[TrainingDisciplineID: any TrainingSession]`), prefer that — but **do not let scope creep**: the goal is "compile and behave identically." Larger restructures belong in 76.3.

For each switch updated, a brief inline comment explaining why a `default:` (or which dispatch path) is acceptable is welcome but not required — the upcoming refactors will revisit these sites.

### AC 6: Tests that reference `TrainingDisciplineID.allCases` are migrated

**Given** the test files known to reference `.allCases`:

- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift:15, 27`
- `PeachTests/Core/Profile/TrainingDisciplineConfigTests.swift:49, 51`
- `PeachTests/Core/Profile/ProgressTimelineTests.swift:76`
- `PeachTests/Profile/ProgressChartViewTests.swift:550, 557`

**When** inspected after this story
**Then** each `.allCases` reference is replaced with `TrainingDisciplineID.canonicalIDs` (per AC 3). Tests asserting structural invariants of the identifier catalog (e.g. "every config has a non-empty displayName") iterate `canonicalIDs`. Tests asserting registry behavior (e.g. "every canonical ID is registered") may equivalently iterate `registry.all.map(\.id)` — dev's call per test.

The semantics are unchanged in this story (canonicalIDs has six entries and the registry still registers all six).

### AC 7: No behavior change

**Given** a built and launched app on iOS or macOS
**When** the user navigates the StartScreen, training menus, profile, settings, help, and runs each of the six disciplines
**Then** observable behavior is identical to before this story:

- Six disciplines appear in StartScreen and PeachCommands menus.
- Profile screen lists profiles for all six disciplines.
- Help content shows all six disciplines.
- CSV export and import produce and accept the same `trainingType` strings as before (`pitch-discrimination`, `interval-discrimination`, `pitch-matching`, `interval-matching`, `timing-offset-detection`, `continuous-rhythm-matching` — note: these are the `slug` values via `TrainingDiscipline.csvTrainingType`; verify in the conformances).
- Localization is unchanged.

### AC 8: Both platforms green

**Given** the full test suite
**When** run via `bin/test.sh` and `bin/test.sh -p mac`
**Then** all tests pass with zero regressions, and `bin/build.sh && bin/build.sh -p mac` emits zero new warnings.

## Tasks / Subtasks

- [ ] Task 1: Convert `TrainingDisciplineID` to a struct in Core (AC: 1)
  - [ ] 1.1 Replace the enum with the struct shape per AC 1
  - [ ] 1.2 Preserve `Hashable`, `Sendable`, add `Codable`
  - [ ] 1.3 Keep `config` and `statisticsKeys` computed properties unchanged
  - [ ] 1.4 Confirm grep for concrete-feature names in this file matches only doc comments
- [ ] Task 2: Create `App/Training/DisciplineIDs.swift` with the six static factories (AC: 2)
  - [ ] 2.1 Create directory if missing; add file to iOS and macOS targets
  - [ ] 2.2 Declare all six static `TrainingDisciplineID` instances with the historical slug strings
- [ ] Task 3: Add `canonicalIDs` collection (AC: 3)
  - [ ] 3.1 Add to the same App-side extension
  - [ ] 3.2 Include the doc comment that distinguishes catalog vs. registry semantics
- [ ] Task 4: Verify each discipline conformance compiles unchanged (AC: 4)
  - [ ] 4.1 Build the project — each `*Discipline` conformance should resolve `.unisonPitchDiscrimination` etc. via the new extension
  - [ ] 4.2 No conformance constructs `TrainingDisciplineID(...)` from a literal slug
- [ ] Task 5: Add `default:` (or restructure) on exhaustive switches (AC: 5)
  - [ ] 5.1 `Peach/Profile/ProfileScreen.swift` — line 23 switch
  - [ ] 5.2 `Peach/Start/StartScreen.swift` — line 64 switch
  - [ ] 5.3 `Peach/App/Platform/PeachCommands.swift` — lines 178, 191 switches
  - [ ] 5.4 `Peach/App/TrainingLifecycleCoordinator.swift` — lines 66, 162 switches
  - [ ] 5.5 `Peach/Core/Profile/StatisticalSummary.swift` — any switch over IDs
  - [ ] 5.6 Any other `case .unisonPitchDiscrimination` / `case .intervalPitchMatching` / etc. that grep surfaces
- [ ] Task 6: Migrate `.allCases` test references (AC: 6)
  - [ ] 6.1 `TrainingDisciplineRegistryTests.swift` lines 15 and 27 → `canonicalIDs`
  - [ ] 6.2 `TrainingDisciplineConfigTests.swift` lines 49 and 51 → `canonicalIDs`
  - [ ] 6.3 `ProgressTimelineTests.swift` line 76 → `canonicalIDs`
  - [ ] 6.4 `ProgressChartViewTests.swift` lines 550 and 557 → `canonicalIDs`
  - [ ] 6.5 Final grep `TrainingDisciplineID\.allCases` returns zero hits in `Peach/` and `PeachTests/`
- [ ] Task 7: Build & test both platforms (AC: 7, 8)
  - [ ] 7.1 `bin/build.sh && bin/build.sh -p mac` — zero new warnings
  - [ ] 7.2 `bin/test.sh && bin/test.sh -p mac` — all tests green
  - [ ] 7.3 Manual smoke: launch app, verify all six disciplines visible and runnable; verify CSV export/import round-trips a small dataset

## Dev Notes

### Why a struct, not a typealias to `String`

`String` is too permissive — every `String`-typed value would silently satisfy `TrainingDisciplineID`-typed parameters, defeating the type's role as a domain identifier. A single-field struct preserves call-site clarity (`registry[.unisonPitchDiscrimination]` reads as before) while removing the concrete-case enumeration from Core.

### Why the named instances live in `App/Training/`, not `Core/Training/`

The named instances **are** the App's identity catalog — declaring "Peach knows these six disciplines exist." Putting them in Core would re-introduce the layering inversion this story exists to fix. `App/Training/` was chosen so the catalog sits next to the upcoming `DisciplineBootstrap.swift` (story 76.2), keeping the policy together.

### Why the conformance files (e.g. `UnisonPitchDiscriminationDiscipline.swift`) work without changes

Those files live under `Peach/Training/PitchDiscrimination/Discipline/` — App-feature code, not Core. They already reference `TrainingDisciplineID.unisonPitchDiscrimination` symbolically. After this story, that symbol resolves to the App-side extension's static rather than the Core enum's case. No code change in those files; only the type's shape changes underneath.

### Why losing `CaseIterable` is acceptable

Three reasons:

1. The semantically-correct iteration target for production code is `registry.all` (what's *currently* registered), which we already have.
2. The remaining "iterate every known ID" needs are predominantly tests, which get `canonicalIDs` (per AC 3).
3. Build-gating timing disciplines in 76.4 would make `allCases.contains(...)` lie about what the app actually exposes. Removing `CaseIterable` now prevents future call sites from using it incorrectly.

### What about the `case .timingOffsetDetection, .continuousRhythmMatching` pair switch in `ProfileScreen`?

`ProfileScreen.swift:23` switches on the discipline ID to decide between `RhythmProfileCardView` and `ProgressChartView`. After this story it becomes:

```swift
switch mode {
case .timingOffsetDetection, .continuousRhythmMatching:
    RhythmProfileCardView(...)
default:
    ProgressChartView(...)
}
```

— still exhaustive against the *known* set, with `default:` matching the pitch-comparison branch. Story 76.3 replaces this with a switch over `discipline.category`, which is the structurally correct dispatch. Don't pre-empt that here.

### What about `StatisticsKey`?

`StatisticsKey.pitch(TrainingDisciplineID)` and `.rhythm(TrainingDisciplineID, …)` already accept the type by value — no change needed in the enum. If any switch over a `StatisticsKey` payload exhaustively enumerates `TrainingDisciplineID` cases, treat it like the AC 5 sites.

### Why no doc updates

Active docs (`arc42.md`, `glossary.md`, `project-context.md`) describe the discipline registry pattern and where the catalog lives. Those updates are bundled into story 76.4 (the user-visible change) so all four stories' doc impact is consolidated — saves three rounds of doc churn.

### References

- `MEMORY.md → feedback_design_by_contract_and_separation.md` — concrete-feature knowledge belongs in the layer that owns the policy, not the mechanism
- `MEMORY.md → feedback_symmetric_protocol_design.md` — the struct-with-slug shape mirrors how other domain identifiers (e.g. `SoundSourceID`) are typically expressed
- `Peach/Core/Training/TrainingDisciplineID.swift` — current enum being relocated
- `Peach/Core/Data/PeachSchema.swift` — confirmed `TrainingDisciplineID` is **not** a SwiftData stored property; CSV uses `csvTrainingType` strings, so the slug-wrapping struct is binary-compatible with all persisted data
- Story 76.2 — adds `TrainingCategory` and relocates the bootstrap; this story is its prerequisite

## Change Log

- 2026-04-25: Story drafted as new Story 76.1 of Epic 76. Existing 76.1/76.2/76.3 renumbered to 76.2/76.3/76.4. Status → ready-for-dev.

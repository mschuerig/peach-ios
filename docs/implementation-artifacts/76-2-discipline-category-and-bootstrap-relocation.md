# Story 76.2: Add discipline category and relocate concrete bootstrap to App layer

Status: review

## Story

As a Peach contributor preparing to gate timing disciplines per build,
I want a `TrainingCategory` partition on `TrainingDiscipline` and the concrete discipline list moved out of `Core/Training/Discipline/TrainingDisciplineRegistry.swift` and into a new `App/Training/DisciplineBootstrap.swift`,
so that Core defines the registry **mechanism** while App owns the **policy** of which concrete disciplines exist — preparing the seam where stories 76.3 and 76.4 can drop in data-driven UI iteration and a build flag.

## Context

After story 76.1 relocated `TrainingDisciplineID`'s named instances to App, Core no longer dictates the catalog of identifiers. But `TrainingDisciplineRegistry.shared` (still in Core) hardcodes a private initializer that constructs all six concrete discipline instances directly. That puts policy (which disciplines exist) inside the mechanism (the registry implementation), and the registry's Core location pulls every concrete discipline implementation into the dependency graph of code that should know only the protocol.

Story 76.4 needs to gate two of those instantiations on a build flag. Doing that inside Core would push build-configuration policy into the mechanism layer too. The clean answer — established in `MEMORY.md → feedback_design_by_contract_and_separation.md` ("business rules localized by purpose, not scattered") — is to relocate the concrete list to App and let Core hold only the type. This story does that move with **zero behavior change**, preparing the foundation for 76.3 and 76.4.

The category enum is introduced now (rather than in 76.3) because the bootstrap relocation is the natural place for each discipline to declare its category alongside its construction, and because adding `category` to the protocol forces every discipline conformance to be updated in the same touch.

## Scope Boundaries

- **In scope:** `TrainingCategory` enum (Core), `category` property on the `TrainingDiscipline` protocol, category declarations on each of the six discipline conformances, `TrainingDisciplineRegistry.init(disciplines:)` constructor, `App/Training/DisciplineBootstrap.swift` containing the concrete list, bootstrap wiring in `PeachApp` so `TrainingDisciplineRegistry.shared` resolves correctly at app startup.
- **In scope:** updating `TrainingDisciplineRegistryTests` so it constructs registries directly via `init(disciplines:)` (using either real or synthetic disciplines) instead of relying on `.shared`'s contents.
- **Out of scope:** any UI iteration changes (deferred to 76.3). `StartScreen`, `PeachCommands`, `ProfileScreen`, `HelpContent` keep their hardcoded discipline lists for now.
- **Out of scope:** the `PEACH_RESEARCH` build flag and any conditional compilation (deferred to 76.4). All six disciplines remain registered after this story.
- **Out of scope:** removing the `TrainingDisciplineRegistry.shared` singleton. The singleton remains the access pattern; only its initialization moves.
- **Out of scope:** changing the shape of `TrainingDisciplineID` (story 76.1 already converted it to a slug-wrapping struct with its named instances declared in `App/Training/DisciplineIDs.swift`). All six static IDs remain declared.

## Acceptance Criteria

### AC 1: `TrainingCategory` enum exists in Core

**Given** `Peach/Core/Training/TrainingCategory.swift`
**When** the file is opened
**Then** it defines:

```swift
enum TrainingCategory: String, CaseIterable, Sendable {
    case pitch
    case intervals
    case rhythm
}
```

The enum lives next to `TrainingDisciplineID.swift` in `Core/Training/` (not under `Core/Training/Discipline/`, which is reserved for protocol/registry types). `String` raw values keep it stable for any future serialization needs without forcing a use today.

### AC 2: `TrainingDiscipline` protocol declares `category`

**Given** `Peach/Core/Training/Discipline/TrainingDiscipline.swift`
**When** inspected
**Then** the protocol has a new requirement: `var category: TrainingCategory { get }`, placed alongside `id` and `config` near the top of the protocol body. A doc comment explains the property: "Display partition for grouping in lists and menus. Each discipline belongs to exactly one category."

### AC 3: Each of the six discipline conformances declares its category

**Given** the six concrete `TrainingDiscipline` conforming structs
**When** inspected
**Then** each declares its category:

| Discipline | Category |
|---|---|
| `UnisonPitchDiscriminationDiscipline` | `.pitch` |
| `UnisonPitchMatchingDiscipline` | `.pitch` |
| `IntervalPitchDiscriminationDiscipline` | `.intervals` |
| `IntervalPitchMatchingDiscipline` | `.intervals` |
| `TimingOffsetDetectionDiscipline` | `.rhythm` |
| `ContinuousRhythmMatchingDiscipline` | `.rhythm` |

The category is a stored or computed property on each conformance; either is acceptable as long as the value matches the table above.

### AC 4: `TrainingDisciplineRegistry` accepts disciplines via init

**Given** `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift`
**When** inspected
**Then**:

1. The hardcoded list inside `private init()` (lines 19–47 of the current file) is **removed**. The body of `init` no longer mentions any concrete `*Discipline()` constructor.
2. A new initializer `init(disciplines: [any TrainingDiscipline])` exists. It performs the same setup the old `private init()` did (building `byID`, `csvParsers`, `csvDisciplineColumns`) using the `disciplines` parameter as input.
3. The init's existing assertions (no discipline declares a common column) are preserved.
4. Core has no remaining knowledge of any concrete discipline type — `grep -rn "PitchDiscriminationDiscipline\|PitchMatchingDiscipline\|TimingOffsetDetectionDiscipline\|ContinuousRhythmMatchingDiscipline" Peach/Core/` returns no matches in production code (test files are out of scope here).

### AC 5: `TrainingDisciplineRegistry.shared` is initialized from App-provided disciplines

**Given** that `TrainingDisciplineID.config` and `TrainingDisciplineID.statisticsKeys` (in `TrainingDisciplineID.swift`) reference `TrainingDisciplineRegistry.shared`
**When** the app launches
**Then** `TrainingDisciplineRegistry.shared` resolves to a fully populated registry containing all six disciplines, **before** any view code accesses `.shared`.

The exact mechanism is the dev's call. Two reasonable options:

- **Option A (preferred):** `TrainingDisciplineRegistry.shared` becomes `static var shared: TrainingDisciplineRegistry { _shared! }` backed by a private `static var _shared: TrainingDisciplineRegistry?`, with a `static func bootstrap(disciplines: [any TrainingDiscipline])` that asserts `_shared == nil` and assigns. App calls `TrainingDisciplineRegistry.bootstrap(disciplines: DisciplineBootstrap.allDisciplines)` as the **first line** of `PeachApp.init()`, before any session/coordinator construction.
- **Option B:** keep `static let shared` but make it lazy and call into a hook the App layer registers. More fragile under static-init ordering — only choose if A doesn't fit cleanly.

Whichever path, accessing `.shared` before bootstrap must trap (precondition or force-unwrap is acceptable; the failure should be loud and immediate).

### AC 6: `App/Training/DisciplineBootstrap.swift` exists and owns the concrete list

**Given** the new file `Peach/App/Training/DisciplineBootstrap.swift`
**When** inspected
**Then** it defines:

```swift
enum DisciplineBootstrap {
    static let allDisciplines: [any TrainingDiscipline] = [
        UnisonPitchDiscriminationDiscipline(),
        IntervalPitchDiscriminationDiscipline(),
        UnisonPitchMatchingDiscipline(),
        IntervalPitchMatchingDiscipline(),
        TimingOffsetDetectionDiscipline(),
        ContinuousRhythmMatchingDiscipline(),
    ]
}
```

The `App/Training/` directory already exists from story 76.1 (`DisciplineIDs.swift` lives there). Order matches the current `TrainingDisciplineRegistry.private init` ordering exactly (do not reorder in this story — that's a 76.3 concern at the latest). The file is added to both iOS and macOS targets.

### AC 7: `TrainingDisciplineRegistryTests` constructs registries directly

**Given** `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift`
**When** inspected
**Then**:

1. The test suite no longer accesses `TrainingDisciplineRegistry.shared` for setup. Each test that needs a registry constructs one via `TrainingDisciplineRegistry(disciplines: DisciplineBootstrap.allDisciplines)` (or a smaller fixture list where appropriate).
2. The existing tests continue to assert the same invariants they assert today (all IDs registered, no common-column overlap, parser dispatch correctness, distinct record types).
3. The hardcoded `registry.all.count == 6` assertion in `registryContainsSixDisciplines()` is left unchanged for this story (its replacement with data-driven invariants is part of story 76.4 where the count actually becomes build-dependent).
4. All tests pass on iOS and macOS.

### AC 8: No behavior change

**Given** a built and launched app on iOS or macOS
**When** the user navigates the StartScreen, training menus, profile, settings, help, and runs each of the six disciplines
**Then** observable behavior is identical to before this story:

- Six disciplines appear in StartScreen and PeachCommands menus.
- Profile screen lists profiles for all six disciplines.
- Help content shows all six disciplines in `HelpContent.trainingDisciplinesDescription`.
- Localization is unchanged.
- CSV export and import handle all six disciplines identically.

### AC 9: Both platforms green

**Given** the full test suite
**When** run via `bin/test.sh` and `bin/test.sh -p mac`
**Then** all tests pass with zero regressions, and `bin/build.sh && bin/build.sh -p mac` emits zero new warnings.

## Tasks / Subtasks

- [x] Task 1: Add `TrainingCategory` enum (AC: 1)
  - [x] 1.1 Create `Peach/Core/Training/TrainingCategory.swift`
  - [x] 1.2 Add to both iOS and macOS targets
- [x] Task 2: Extend protocol with `category` (AC: 2)
  - [x] 2.1 Add `var category: TrainingCategory { get }` to `TrainingDiscipline.swift`
  - [x] 2.2 Add the doc comment described in AC 2
- [x] Task 3: Update each conformance with its category (AC: 3)
  - [x] 3.1 Locate each of the six conformance files (e.g. via `grep -rn "TrainingDiscipline {" Peach/`)
  - [x] 3.2 Add `let category: TrainingCategory = .pitch | .intervals | .rhythm` per the AC 3 table
  - [x] 3.3 Build iOS and macOS — confirm protocol conformance is satisfied
- [x] Task 4: Refactor `TrainingDisciplineRegistry` init (AC: 4)
  - [x] 4.1 Rename `private init()` to `init(disciplines: [any TrainingDiscipline])`
  - [x] 4.2 Replace the hardcoded `disciplines` array with the `disciplines` parameter
  - [x] 4.3 Verify `byID`, `csvParsers`, `csvDisciplineColumns` setup is unchanged
  - [x] 4.4 Confirm no concrete discipline references remain in `Core/`
- [x] Task 5: Wire `.shared` bootstrap (AC: 5)
  - [x] 5.1 Implement Option A (or Option B) for `.shared` initialization
  - [x] 5.2 Add `TrainingDisciplineRegistry.bootstrap(disciplines:)` (or chosen equivalent)
  - [x] 5.3 Document the access contract in a doc comment on `.shared` ("must call `bootstrap` before access")
- [x] Task 6: Create `DisciplineBootstrap` (AC: 6)
  - [x] 6.1 Create `Peach/App/Training/` directory
  - [x] 6.2 Create `DisciplineBootstrap.swift` with `allDisciplines` static
  - [x] 6.3 Add the file to both iOS and macOS targets
- [x] Task 7: Wire bootstrap from `PeachApp.init` (AC: 5, 8)
  - [x] 7.1 Add `TrainingDisciplineRegistry.bootstrap(disciplines: DisciplineBootstrap.allDisciplines)` as the first line of `PeachApp.init()`
  - [x] 7.2 Confirm via launch on iOS Simulator and macOS that no precondition fails
- [x] Task 8: Update tests (AC: 7)
  - [x] 8.1 Refactor `TrainingDisciplineRegistryTests` to construct registries via `init(disciplines:)`
  - [x] 8.2 Confirm all existing assertions still pass
  - [x] 8.3 Check whether any other test files relied on `.shared` being pre-bootstrapped via `private init()` — bootstrap them in test setup if needed
- [x] Task 9: Build & test both platforms (AC: 8, 9)
  - [x] 9.1 `bin/build.sh && bin/build.sh -p mac` — zero new warnings
  - [x] 9.2 `bin/test.sh && bin/test.sh -p mac` — all tests green
  - [ ] 9.3 Manual smoke: launch app, verify all six disciplines appear in StartScreen, navigate into one of each category, confirm no crash

## Dev Notes

### Why category goes on the protocol, not the registry

Two designs were considered:

1. **Protocol property** (chosen) — each discipline declares its own category. Symmetric with existing `id`, `config`, `statisticsKeys`. Scales naturally to per-discipline metadata. Aligns with `MEMORY.md → feedback_symmetric_protocol_design.md`.
2. **Registry-side metadata** — pass `(discipline, category)` tuples into the registry. Keeps the protocol smaller but creates a parallel structure to maintain.

Option 1 was chosen because (a) the registry no longer constructs concretes itself, so a richer protocol carries no cost there, and (b) future stories may want to query category from a discipline directly without going through the registry.

### Why the `.shared` singleton stays

`TrainingDisciplineID.config` and `.statisticsKeys` are value-type accessors on an enum and would otherwise need a registry parameter at every call site (every view that displays a discipline name). That's a much larger refactor than this story needs. The bootstrap pattern preserves the existing API surface while moving concrete construction to App.

If a future story wants to remove the singleton in favor of full DI (e.g. via `@Environment`), that's a separate concern and not blocked by this story.

### Why doc updates are deferred

Active docs (`arc42.md`, `glossary.md`, `project-context.md`) describe the registry pattern and where the canonical discipline list lives. Those updates are bundled into story 76.4 (which is the user-visible change), so all four stories' doc impact is consolidated at the end of the epic and we don't churn docs three times.

### References

- `MEMORY.md → feedback_design_by_contract_and_separation.md` — mechanism/policy separation
- `MEMORY.md → feedback_symmetric_protocol_design.md` — protocol additions follow existing splits
- `MEMORY.md → feedback_disciplines_not_modes.md` — `TrainingCategory` cases use `pitch`/`intervals`/`rhythm` (no "mode")
- Story 76.1 — relocated `TrainingDisciplineID`'s named instances to `App/Training/DisciplineIDs.swift`; this story consumes that work
- Story `cleanup-rename-discrimination-to-pitch-comparison` — prior pattern for centralized refactor
- `TrainingDisciplineRegistry.swift:19-47` — current hardcoded init being relocated

## Change Log

- 2026-04-25: Story drafted as Story 76.2 of Epic 76 (Soft Launch — Build-Gated Timing Disciplines). Renumbered from original 76.1 when a new 76.1 (relocate `TrainingDisciplineID` to App) was inserted. Status → ready-for-dev.
- 2026-04-25: Implementation complete. `TrainingCategory` enum added in Core; `TrainingDiscipline` protocol gained `category` requirement; six conformances declare their category. Registry refactored to `init(disciplines:)` plus `static func bootstrap(disciplines:)` backed by `Synchronization.Mutex`. New `Peach/App/Training/DisciplineBootstrap.swift` owns the concrete six-discipline list; `PeachApp.init()` calls bootstrap as its first line. Status → review.

## Dev Agent Record

### Implementation Plan

**Bootstrap mechanism (AC 5, Option A)**

Chose Option A (`static var shared` backed by `static var _shared`) for the `.shared` bootstrap pattern. Implemented with `Synchronization.Mutex<TrainingDisciplineRegistry?>(nil)` (matching the existing precedent in `Peach/Core/Audio/SoundFontEngine.swift`) rather than `nonisolated(unsafe)` storage:

- `static var shared` reads the mutex; `preconditionFailure` if unset (loud + immediate per AC).
- `static func bootstrap(disciplines:)` writes the mutex; `precondition` traps on second call.
- `init(disciplines:)` is reachable for tests that want their own registry without affecting `.shared`.

Rationale: `Mutex` provides a real concurrency barrier (defense in depth) without `nonisolated(unsafe)`. Read cost is small (single uncontended lock) and the `_shared` access is invariant after bootstrap.

**Test bootstrap (AC 7)**

Tests are hosted in `Peach.app` via `TEST_HOST` (see `Peach.xcodeproj/project.pbxproj`). When the test bundle loads, the host's `PeachApp.init()` runs first and bootstraps the registry, so every test sees a populated `.shared` from the start. No test-side bootstrap shim is required. `TrainingDisciplineRegistryTests` instantiates its own registry via `init(disciplines: DisciplineBootstrap.allDisciplines)` per AC 7.

### Completion Notes

- All nine ACs implemented. Both platforms green: iOS 1765 tests, macOS 1758 tests, zero warnings.
- Two `/simplify-code` follow-ups applied (high-confidence, behavior-preserving):
  1. `recordTypes` precomputed in `init` and stored as `let` (was a computed property allocating a fresh `Set` per call; called from `TrainingDataStore` deletion/replacement loops).
  2. `subscript(_ id:)` now traps with `preconditionFailure("No discipline registered for id \(id)")` instead of force-unwrap.
- Manual smoke test (Task 9.3) deferred to user verification on iOS Simulator and macOS hardware.

### File List

**Added**

- `Peach/Core/Training/TrainingCategory.swift`
- `Peach/App/Training/DisciplineBootstrap.swift`

**Modified**

- `Peach/Core/Training/Discipline/TrainingDiscipline.swift` — added `category` protocol requirement
- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` — replaced `private init()` with `init(disciplines:)`, added `bootstrap(disciplines:)`/`shared`, precomputed `recordTypes`, improved subscript trap
- `Peach/App/PeachApp.swift` — added `TrainingDisciplineRegistry.bootstrap(disciplines: DisciplineBootstrap.allDisciplines)` as first line of `init()`
- `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift` — added `category = .pitch`
- `Peach/Training/PitchDiscrimination/Discipline/IntervalPitchDiscriminationDiscipline.swift` — added `category = .intervals`
- `Peach/Training/PitchMatching/Discipline/UnisonPitchMatchingDiscipline.swift` — added `category = .pitch`
- `Peach/Training/PitchMatching/Discipline/IntervalPitchMatchingDiscipline.swift` — added `category = .intervals`
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — added `category = .rhythm`
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift` — added `category = .rhythm`
- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift` — constructs registry via `init(disciplines: DisciplineBootstrap.allDisciplines)`
- `docs/implementation-artifacts/sprint-status.yaml` — story 76.2 status updated

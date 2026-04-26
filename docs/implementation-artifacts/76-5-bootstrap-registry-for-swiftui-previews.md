# Story 76.5: Bootstrap `TrainingDisciplineRegistry` for SwiftUI previews

Status: done

## Story

As **a developer iterating on screens that read `TrainingDisciplineRegistry.shared`** (StartScreen, PeachCommands, ProfileScreen, HelpContent, …),
I want every `#Preview` for those screens to obtain a registry without crashing,
so that previewing those views works without manually wiring bootstrap into every preview block and without diverging the `Release` invariant that bootstrap-before-access is mandatory.

## Background

After story 76.2 the registry is bootstrapped from `Peach/App/Training/DisciplineBootstrap.swift` during app launch (`PeachApp.init` or equivalent). Anything that reads `TrainingDisciplineRegistry.shared` before bootstrap traps with `preconditionFailure("TrainingDisciplineRegistry.shared accessed before bootstrap(disciplines:)")`.

After story 76.3 several screens read `registry.shared` directly to enumerate active categories and disciplines (StartScreen, PeachCommands, HelpContent, ProfileScreen). This is correct in the running app — bootstrap has already happened — but a SwiftUI `#Preview` constructs the view in isolation, *outside* the app launch path. The registry has not been bootstrapped, so the preview crashes the moment the view body reads `TrainingDisciplineRegistry.shared.activeCategories`.

The 76.3 review surfaced this as deferred item D5. Today the project may have no failing previews simply because nobody runs them, but the trap is real and growing — every new screen that reads the registry inherits it. Fix it once, in one place, with one helper that previews can call.

This is a Quick Spec, not a full BMAD story: the change is small (one helper file plus a one-line call in each preview) and well-scoped.

## Acceptance Criteria

### AC 1: Registry bootstrap is idempotent

**Given** `TrainingDisciplineRegistry.bootstrap(disciplines:)`
**When** called more than once in the same process
**Then** subsequent calls are a no-op (or replace the registry — dev's choice; document the chosen semantics in Completion Notes). The first call wins by default; calling again with the same or a different list does not trap.

Rationale: previews can be re-rendered in the same Xcode session, and a `bootstrapIfNeeded()` helper must be safe to call repeatedly. A `precondition(_alreadyBootstrapped == false)` would crash the second preview render.

### AC 2: A DEBUG-only preview helper exists

**Given** a new file `Peach/App/PreviewSupport.swift` (location is dev's call, but it MUST be App-layer and DEBUG-gated)
**When** built in `Debug` (the only configuration that builds previews)
**Then** the file declares one helper, e.g.:

```swift
#if DEBUG
import Foundation

/// Idempotent registry bootstrap for SwiftUI previews. Calls `bootstrap(disciplines:)`
/// with the same `DisciplineBootstrap.allDisciplines` the live app uses, so previews
/// see the same registry contents as a running app would.
enum PreviewSupport {
    static func bootstrapRegistryIfNeeded() {
        TrainingDisciplineRegistry.bootstrap(disciplines: DisciplineBootstrap.allDisciplines)
    }
}
#endif
```

The `#if DEBUG` guard ensures the helper does not bloat the `Release`/`Research` binary.

### AC 3: All `#Preview` blocks that touch the registry call the helper first

**Given** SwiftUI preview blocks in `StartScreen`, `PeachCommands`-related views, `ProfileScreen`, `HelpContentView` (and any other view that reads `TrainingDisciplineRegistry.shared`)
**When** inspected
**Then** each `#Preview` block invokes `PreviewSupport.bootstrapRegistryIfNeeded()` before constructing the view. Example:

```swift
#Preview {
    PreviewSupport.bootstrapRegistryIfNeeded()
    return StartScreen(...)
}
```

A `grep` for `TrainingDisciplineRegistry.shared` across files containing `#Preview` confirms each such file's previews are wired.

### AC 4: Previews render without crashing

**Given** Xcode's preview canvas
**When** opened on each touched screen
**Then** the preview renders without trapping. Visual fidelity to the live app is not required — `DisciplineBootstrap.allDisciplines` provides real disciplines, but real `ModelContainer`/audio/MIDI dependencies are typically faked elsewhere; this story does not touch those.

### AC 5: Both platforms green

**Given** `bin/test.sh && bin/test.sh -p mac` and `bin/build.sh && bin/build.sh -p mac`
**When** run after the changes
**Then** all tests pass and the build is clean. (Previews don't run during test/build, so this AC is mainly a regression check on the bootstrap idempotency change.)

## Tasks / Subtasks

- [x] Task 1: Make `bootstrap(disciplines:)` idempotent (AC: 1)
  - [x] 1.1 Inspect `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` to see how `_shared` is currently set
  - [x] 1.2 Add a guard so the second call is a no-op (or document the replace-on-second-call semantics)
  - [x] 1.3 Add a unit test that calls bootstrap twice and asserts no trap, with the first list winning (or whichever semantics the dev chose)
- [x] Task 2: Create `Peach/App/PreviewSupport.swift` (AC: 2)
  - [x] 2.1 Wrap entire file in `#if DEBUG` / `#endif`
  - [x] 2.2 Define `enum PreviewSupport { static func bootstrapRegistryIfNeeded() }`
- [x] Task 3: Wire every relevant `#Preview` (AC: 3)
  - [x] 3.1 `grep -rn "TrainingDisciplineRegistry.shared" Peach/` → list of files
  - [x] 3.2 In each file with `#Preview` blocks, prepend `PreviewSupport.bootstrapRegistryIfNeeded()` to the preview body
  - [x] 3.3 Spot-check the preview canvas in Xcode for each touched view (deferred to user — preview canvas not runnable from CLI)
- [x] Task 4: Build and test both platforms (AC: 5)
  - [x] 4.1 `bin/test.sh && bin/test.sh -p mac`
  - [x] 4.2 `bin/build.sh && bin/build.sh -p mac` — zero new warnings

## Dev Notes

### Why a helper, not a global side effect

A tempting alternative is to bootstrap the registry from a `static let` initializer somewhere always-loaded — but Swift gives no guarantee about when statics initialize, and tests should *not* see preview bootstrap pollution. A named, opt-in helper called from `#Preview` makes the dependency explicit and keeps test isolation intact.

### Why DEBUG-only

Previews only build under `Debug`. Putting `PreviewSupport` behind `#if DEBUG` keeps the `Release`/`Research` binary unaffected and avoids confusing future readers about whether the helper is reachable in production.

### Why bootstrap with the real list

Some previews could conceivably want a curated registry (e.g., "preview StartScreen with only pitch disciplines"). This story keeps the helper trivially uniform — same list as the running app — to minimize churn. If a future preview needs a different list, it can call `TrainingDisciplineRegistry.bootstrap(disciplines: [...])` directly with its own list (idempotent semantics from AC 1 keep this safe).

### Why idempotency, not a "isAlreadyBootstrapped" check at every call site

A `bootstrapIfNeeded` outside the type would have to peek at internal state, which the registry doesn't expose. Putting the check inside `bootstrap(disciplines:)` keeps the policy in one place and makes every call site a one-liner.

### References

- Story 76.2 — relocated bootstrap; introduced the trap (`accessed before bootstrap`)
- Story 76.3 — added several `registry.shared` callers in screens; surfaced D5 in review
- Story 76.4 — does not depend on this story; this is a follow-on cleanup that can land in any order

## Dev Agent Record

### Completion Notes

- **Idempotency semantics chosen: first call wins.** `TrainingDisciplineRegistry.bootstrap(disciplines:)` now uses `guard registry == nil else { return }`; a second call with the same or a different list is a no-op. Doc comment updated to explain the rationale (safe under repeated SwiftUI preview renders).
- **`PreviewSupport.bootstrapRegistryIfNeeded()`** lives at `Peach/App/PreviewSupport.swift` wrapped in `#if DEBUG`. Calls `bootstrap` with `DisciplineBootstrap.allDisciplines` — same list as the live app.
- **Preview blocks wired:** every `#Preview` whose view body (directly or transitively) reads `TrainingDisciplineRegistry.shared` prepends `PreviewSupport.bootstrapRegistryIfNeeded()` and uses an explicit `return` for the view expression. Files: `StartScreen`, `ProfileScreen` (both previews), `SettingsScreen`, `ContentView+iOS`, `ContentView+macOS`, `InfoScreen` (transitive read via `HelpContent.about` → `HelpContent.info` → `trainingDisciplinesDescription`). `HelpContentView`'s preview takes pre-built sections so no bootstrap needed.
- **Test:** `TrainingDisciplineRegistryTests.bootstrapIsIdempotent` calls `bootstrap` twice with different lists and asserts `firstShared === secondShared`, working regardless of any other test that already bootstrapped.
- **Validation:** `bin/test.sh` (1427 passed) and `bin/test.sh -p mac` (1422 passed); `bin/build.sh` (1 pre-existing AppIntents metadata warning, unrelated) and `bin/build.sh -p mac` (0 warnings).

### File List

- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` — replaced precondition with idempotent guard; updated doc comment
- `Peach/App/PreviewSupport.swift` — new DEBUG-only preview helper
- `Peach/Start/StartScreen.swift` — preview prepends bootstrap call
- `Peach/Profile/ProfileScreen.swift` — both previews prepend bootstrap call
- `Peach/Settings/SettingsScreen.swift` — preview prepends bootstrap call
- `Peach/App/Platform/ContentView+iOS.swift` — preview prepends bootstrap call
- `Peach/App/Platform/ContentView+macOS.swift` — preview prepends bootstrap call
- `Peach/Info/InfoScreen.swift` — preview prepends bootstrap call (transitive registry read via `HelpContent.about`)
- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift` — added `bootstrapIsIdempotent` test
- `docs/implementation-artifacts/sprint-status.yaml` — story status: ready-for-dev → in-progress → review

## Change Log

- 2026-04-26: Quick Spec drafted from 76.3 review deferred item D5. Status → ready-for-dev.
- 2026-04-26: Implementation complete. Idempotent bootstrap with first-call-wins semantics; `PreviewSupport` helper wired into 7 preview blocks across 6 files. iOS + macOS tests green (1427 / 1422 passed). Status → review.
- 2026-04-26: Code review complete. P1/S1 fixed (production `bootstrap` precondition restored; DEBUG-gated `_replaceSharedForTesting` added for previews/tests). D1 fixed (per-suite `init()` declares canonical-registry dependency in 7 test suites; `_withSharedReplacedForTesting` scope helper added in `PeachTests/Helpers/RegistryTestSupport.swift`). D2 reclassified to reject (preview-environment asymmetry correctly reflects actual environment usage in StartScreen/ProfileScreen/InfoScreen). iOS + macOS tests green (1428 / 1422 passed). Status → done.

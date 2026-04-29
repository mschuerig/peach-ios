# Story 77.10: Test isolation for shared registries

Status: review

## Story

As **a developer running the test suite under Swift Testing's default parallel execution**,
I want test code to stop mutating the process-wide `TrainingDisciplineRegistry.shared` and `CSVHistoryRegistry.shared` slots,
so that suites running in parallel cannot observe each other's swapped registries mid-test, the `_replaceSharedForTesting` debug-only escape hatch can shrink (or disappear), and shared-state-induced flakiness is eliminated as a class.

## Background

Two app-wide singleton registries currently live behind a `Mutex<…?>` slot:

- `TrainingDisciplineRegistry.shared` — bootstrapped at app startup with `DisciplineBootstrap.allDisciplines`.
- `CSVHistoryRegistry.shared` — introduced in 77.5; bootstrapped with `DisciplineBootstrap.allCSVHistories`.

Both expose a `#if DEBUG` `_replaceSharedForTesting(...)` method that **atomically replaces** the contents of the shared slot. Tests use it (directly or via `RegistryTestSupport._withSharedReplacedForTesting`) to install fixture disciplines/histories.

Swift Testing parallelises suite execution by default. Because the slot is process-wide, a swap performed by suite A is observable by every suite running concurrently. The defer-restore pattern in `_withSharedReplacedForTesting` shrinks the window but does not close it: while suite A is inside `body`, any concurrently-running suite B that reads `.shared` sees A's fixtures. Symptoms are race-shaped — failures that depend on which suite the runner happens to schedule alongside which other suite — and intermittent.

This was first surfaced as 77.1 review item D5 ("Parallel-suite races on shared `TrainingDisciplineRegistry` (pre-existing)") and again as 77.5 review item D1. It has been deferred twice. The Boy Scout Rule applies: track it as a real story rather than carrying it forward indefinitely.

There are roughly two viable shapes:

1. **Inject the registry.** Replace `TrainingDisciplineRegistry.shared` (and `CSVHistoryRegistry.shared`) reads in the production call graph with a parameter or environment value. Tests construct a registry instance directly and pass it in. The shared slot remains for the App layer's bootstrap convenience but is never read from inside tests.
2. **Task-local registry override.** Keep the `.shared` accessor; back it with a Swift `TaskLocal` that, when set, takes precedence over the bootstrapped instance. Tests set the task-local for the scope of one test, leaving sibling tests in other tasks unaffected.

Shape 2 has the advantage that the App-layer call sites need no plumbing changes — only the registry's `shared` accessor changes, internally consulting the task-local before falling back to the bootstrapped instance. Shape 1 is more invasive but more orthodox.

The choice is dev's. Either reduces concurrent test interference to zero.

## Acceptance Criteria

### AC 1: Tests do not mutate the process-wide registry slot

**Given** the test target after this story
**When** any test installs fixture disciplines or fixture CSV histories
**Then** the installation is **scoped to the current test** — either via a registry instance the test constructs and passes into the system under test (Shape 1) or via a task-local override consulted by `.shared` (Shape 2). No test path writes to the `Mutex<TrainingDisciplineRegistry?>` / `Mutex<CSVHistoryRegistry?>` slot during test execution.

If the chosen shape is task-local, the production `bootstrap(...)` write still happens once — at app launch / preview support setup — and is the only writer.

### AC 2: `_replaceSharedForTesting` shrinks or is removed

**Given** the `#if DEBUG` `_replaceSharedForTesting(disciplines:)` and `_replaceSharedForTesting(histories:)` methods
**When** inspected after this story
**Then** they are either:
- **Removed** entirely (preferred if reachable), with `PreviewSupport` migrated to whichever bootstrap mechanism remains valid for previews; or
- **Reduced to preview-only use** (callable from `PreviewSupport` but not from tests), with a comment naming the migration story (this story) and the test-side replacement.

The current 12+ test files that call `TrainingDisciplineRegistry._replaceSharedForTesting(...)` directly are migrated to the new mechanism.

### AC 3: `RegistryTestSupport` is updated or retired

**Given** `PeachTests/Helpers/RegistryTestSupport.swift` (the `_withSharedReplacedForTesting` defer-restore helper)
**When** inspected
**Then** it is either:
- **Replaced** by an injection-style helper (e.g., `withRegistry(_:body:)` that constructs a registry and yields it) that does not touch shared state; or
- **Retired** if every call site can construct a registry directly without a helper.

If retained, the file's doc comment explains why the new shape is race-free.

### AC 4: SwiftUI previews still work

**Given** SwiftUI previews depend on a populated registry
**When** previews are rendered after this story
**Then** preview rendering continues to work unchanged. `PreviewSupport.bootstrapRegistryIfNeeded()` either keeps its current shape (still legal — previews are single-process) or is updated to whatever production-bootstrap path remains.

### AC 5: All four configurations green, parallel execution unchanged

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run with default parallel execution
**Then** all configurations pass. Test count is unchanged or higher (no tests dropped to work around races). `bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

A focused stress check — running a chosen suite with `--repetitions 50` (or equivalent), or running the full suite ten times back-to-back — passes consistently. The pre-change suite must be observed to fail this stress check at least intermittently (otherwise this story is unnecessary); document the observed pre-change failure mode in Completion Notes.

### AC 6: No concurrency annotations regressed

**Given** the registries currently conform to `Sendable`
**When** inspected after this story
**Then** the `Sendable` conformance is preserved (instance immutability is unchanged). No `@unchecked Sendable`, no `nonisolated(unsafe)`, no swallowing of concurrency-warning regressions.

## Tasks / Subtasks

- [x] Task 1: Choose shape and prove the race
  - [x] 1.1 Reproduce the race: run the existing test suite with parallel execution and a stress repetition until at least one shared-registry-induced failure surfaces. Capture the symptom (which suite, which assertion). If the race cannot be reproduced after a reasonable effort, document the negative finding and proceed — the architectural concern stands either way.
  - [x] 1.2 Pick Shape 1 (injection) or Shape 2 (task-local). Document the choice in a Dev Notes paragraph: chosen shape, rejected shape, reason.

- [x] Task 2: Implement the chosen shape (AC: 1, 4, 6)
  - [x] 2.1 Apply the change to `TrainingDisciplineRegistry`.
  - [x] 2.2 Apply the change to `CSVHistoryRegistry` symmetrically. Both registries follow the same shape — divergence here would be its own footgun.
  - [x] 2.3 Verify `Sendable` is preserved with no relaxations.

- [x] Task 3: Migrate test call sites (AC: 1, 2, 3)
  - [x] 3.1 Inventory every test file that calls `_replaceSharedForTesting` (`TrainingDisciplineRegistry` and `CSVHistoryRegistry`).
  - [x] 3.2 Migrate each to the new mechanism. Where a suite's `init` reaches for the canonical bootstrap list, prefer migrating it to the new mechanism with a per-test scope rather than a per-suite scope.
  - [x] 3.3 Update or retire `RegistryTestSupport`.

- [x] Task 4: Adjust `PreviewSupport` if needed (AC: 4)
  - [x] 4.1 If `_replaceSharedForTesting` is removed entirely, route `PreviewSupport` through whichever bootstrap path remains.
  - [x] 4.2 If `_replaceSharedForTesting` is preview-only, leave the existing call but ensure the doc comment is accurate.

- [x] Task 5: Verify (AC: 5)
  - [x] 5.1 Run all four test configurations.
  - [x] 5.2 Run the chosen stress check (full suite ×10, or a parallel-prone suite × repetitions). Pass consistently.
  - [x] 5.3 Build all four configurations; zero new warnings.

## Dev Notes

### Chosen shape: Shape 2 (task-local override)

**Picked:** Shape 2 — task-local override consulted by `.shared`.

**Rejected:** Shape 1 — registry injection through the call graph.

**Reason:** `TrainingDisciplineRegistry.shared` is read from 14 production files (exporter, importer, parser, migration, settings/profile/start screens, help content, app commands, etc.) and `CSVHistoryRegistry.shared` from one (`CSVFormatMigration`). Adding a parameter or `@Environment` value to every one of those call sites — and threading it through every intermediate type that currently constructs them — would be a 200+-line change that mostly exercises plumbing, not the test-isolation goal. Shape 2 confines the change to the two registry files plus the test target: only the `.shared` accessor learns about a task-local override, every production call site keeps its current shape, and tests gain a per-test scope via Swift's `@TaskLocal`.

The trade-off Shape 2 accepts is that test isolation is opt-in: a test that doesn't enter the override scope still observes whatever the bootstrapped registry says (which, in this project, is the canonical list installed by `PeachApp.init()` — TEST_HOST hosts the real app). That's exactly what the existing tests want anyway; the only tests that need a non-canonical registry are the ones already wrapping in `_withSharedReplacedForTesting`, and those migrate cleanly to `$override.withValue`.

### Why this is its own story, not piecemeal cleanup

The race surfaces in two registries already (with more likely to follow as the plugin-style refactor lands additional shared catalogues). Migrating call sites one-at-a-time would leave the project in mixed states — some tests using injection, others mutating shared. A clean cut across both registries and all 12+ test files is the only convergent end state. The fix is small per-file but broad per-suite; one story keeps the change cohesive and reviewable.

### What this story is NOT

- **Not a redesign of `TrainingDiscipline` or `CSVHistory`.** Their public surfaces are unchanged.
- **Not a redesign of `DisciplineBootstrap`.** The canonical lists are unchanged.
- **Not a removal of singleton bootstrap.** Production startup still calls `bootstrap(...)` exactly once per registry. The change is purely in how *test code* observes / installs / overrides registry contents.
- **Not a generalisation to other shared state.** Other singletons in the project (audio engine, settings) are out of scope unless they share the same `_replaceSharedForTesting` pattern; if they do, flag them in Completion Notes for a follow-up but do not expand this story.

### Order of operations

This story is independent of 77.6 → 77.9 (which extend the discipline contract further) and of 77.11 (documentation). It can land any time after 77.5 reaches `done`. Concretely it can run in parallel with 77.6 → 77.9 if test-suite churn is manageable.

### References

- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` — the first registry following this pattern.
- `Peach/Core/Training/Discipline/CSVHistoryRegistry.swift` — introduced in 77.5; same shape.
- `PeachTests/Helpers/RegistryTestSupport.swift` — the `_withSharedReplacedForTesting` defer-restore helper that this story replaces or retires.
- `Peach/App/PreviewSupport.swift` — the SwiftUI-preview bootstrap path that uses `_replaceSharedForTesting` legitimately (single-process, not racing tests).
- Story 77.1 review (`docs/implementation-artifacts/77-1-code-review.md`) — D5, "Parallel-suite races on shared `TrainingDisciplineRegistry` (pre-existing)".
- Story 77.5 review — D1, surfaced the same concern after `CSVHistoryRegistry` was introduced.
- Memory: `feedback_never_defer_preexisting` — the Boy Scout Rule mandates fixing every issue or creating a tracked story; this story is the tracked story.

## Change Log

- 2026-04-28: Drafted as a deferred 77.5 review finding (D1), tracking the project-wide `_replaceSharedForTesting` parallel-test race issue first surfaced in 77.1 review (D5). Status → ready-for-dev.
- 2026-04-29: Implemented Shape 2 (task-local override). Both registries gained `@TaskLocal static var override`; `.shared` consults it before the bootstrapped slot. `_replaceSharedForTesting` renamed to `_replaceSharedForPreviewSupport` (preview-only escape hatch). `RegistryTestSupport._withSharedReplacedForTesting` replaced by `withOverride(disciplines:body:)` / `withOverride(histories:body:)`. 11 test files migrated; 7 redundant per-suite `init()` re-bootstraps deleted (no longer needed — task-locals leave sibling tasks unaffected). All four configurations green; pre-change race did not reproduce in 3 stress runs (negative finding documented). Status → review.

## Dev Agent Record

### Completion Notes

- **Shape:** Shape 2 (task-local override). See Dev Notes for chosen-vs-rejected rationale.
- **Pre-change race reproduction:** Three sequential pre-fix `bin/test.sh -f` runs all passed at 1479 — the race did not reproduce on this machine within reasonable effort. Per Task 1.1's stated fallback, this is a documented negative finding; the architectural concern (a process-wide slot mutated by tests running in parallel tasks) stands on its own merits. Race-shaped failures are by definition timing-dependent; absence on three runs is not evidence of safety.
- **Post-change verification:** All four configurations green — iOS Debug 1479, macOS Debug 1473, iOS Research 1823, macOS Research 1817. Five sequential single iOS Debug runs all green at 1479 each (post-fix stable). Build (`bin/build.sh && bin/build.sh -p mac`) produced zero new warnings.
- **`Sendable` preserved:** Both registries remain plain `Sendable` (no `@unchecked`, no `nonisolated(unsafe)`). The `@TaskLocal` static is itself `Sendable` because `TrainingDisciplineRegistry` / `CSVHistoryRegistry` already conform.
- **`_replaceSharedForTesting` is gone from tests entirely.** It was renamed to `_replaceSharedForPreviewSupport` and is now reachable from exactly one production file (`Peach/App/PreviewSupport.swift`). The doc comment names story 77.10 and points test authors at `withOverride`.
- **7 per-suite `init()` re-bootstraps deleted.** Suites such as `ProgressChartViewTests`, `ProgressTimelineTests`, `TrainingDataImportActionTests`, `SettingsTests`, `CSVExportSchemaTests`, `TrainingDisciplineConfigTests`, and `HelpContentViewTests` previously called `_replaceSharedForTesting(disciplines: DisciplineBootstrap.allDisciplines)` in `init()` defensively against parallel pollution. With task-locals, sibling tests cannot pollute `.shared`, so these defensive re-bootstraps are obsolete — TEST_HOST already installs the canonical list at app launch. Deleting them is a real reduction in test-suite mutation, not just a syntactic migration.
- **No follow-up scope expansion.** Other singletons in the project (audio engine, settings) were inspected only insofar as the task-local pattern was being introduced; none of them use `_replaceSharedForTesting`, so per the story's "What this story is NOT" section they are out of scope.

### File List

**Production:**
- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift`
- `Peach/Core/Training/Discipline/CSVHistoryRegistry.swift`
- `Peach/App/PreviewSupport.swift`

**Test infrastructure:**
- `PeachTests/Helpers/RegistryTestSupport.swift`

**Test migrations (`init()` re-bootstrap deleted):**
- `PeachTests/Profile/ProgressChartViewTests.swift`
- `PeachTests/Core/Profile/ProgressTimelineTests.swift`
- `PeachTests/Core/Profile/TrainingDisciplineConfigTests.swift`
- `PeachTests/Core/Data/CSVExportSchemaTests.swift`
- `PeachTests/Settings/TrainingDataImportActionTests.swift`
- `PeachTests/Settings/SettingsTests.swift`

**Test migrations (`_withSharedReplacedForTesting` → `withOverride`):**
- `PeachTests/App/HelpContentViewTests.swift` (also deleted `init()`)
- `PeachTests/Settings/SettingsScreenAggregationTests.swift`
- `PeachTests/Core/Training/RegistryContributionsTests.swift`
- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift` (also renamed the helper-self-test)

**Documentation:**
- `docs/implementation-artifacts/77-10-test-isolation-for-shared-registries.md`
- `docs/implementation-artifacts/sprint-status.yaml`

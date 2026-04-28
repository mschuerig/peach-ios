# Story 77.10: Test isolation for shared registries

Status: ready-for-dev

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

- [ ] Task 1: Choose shape and prove the race
  - [ ] 1.1 Reproduce the race: run the existing test suite with parallel execution and a stress repetition until at least one shared-registry-induced failure surfaces. Capture the symptom (which suite, which assertion). If the race cannot be reproduced after a reasonable effort, document the negative finding and proceed — the architectural concern stands either way.
  - [ ] 1.2 Pick Shape 1 (injection) or Shape 2 (task-local). Document the choice in a Dev Notes paragraph: chosen shape, rejected shape, reason.

- [ ] Task 2: Implement the chosen shape (AC: 1, 4, 6)
  - [ ] 2.1 Apply the change to `TrainingDisciplineRegistry`.
  - [ ] 2.2 Apply the change to `CSVHistoryRegistry` symmetrically. Both registries follow the same shape — divergence here would be its own footgun.
  - [ ] 2.3 Verify `Sendable` is preserved with no relaxations.

- [ ] Task 3: Migrate test call sites (AC: 1, 2, 3)
  - [ ] 3.1 Inventory every test file that calls `_replaceSharedForTesting` (`TrainingDisciplineRegistry` and `CSVHistoryRegistry`).
  - [ ] 3.2 Migrate each to the new mechanism. Where a suite's `init` reaches for the canonical bootstrap list, prefer migrating it to the new mechanism with a per-test scope rather than a per-suite scope.
  - [ ] 3.3 Update or retire `RegistryTestSupport`.

- [ ] Task 4: Adjust `PreviewSupport` if needed (AC: 4)
  - [ ] 4.1 If `_replaceSharedForTesting` is removed entirely, route `PreviewSupport` through whichever bootstrap path remains.
  - [ ] 4.2 If `_replaceSharedForTesting` is preview-only, leave the existing call but ensure the doc comment is accurate.

- [ ] Task 5: Verify (AC: 5)
  - [ ] 5.1 Run all four test configurations.
  - [ ] 5.2 Run the chosen stress check (full suite ×10, or a parallel-prone suite × repetitions). Pass consistently.
  - [ ] 5.3 Build all four configurations; zero new warnings.

## Dev Notes

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

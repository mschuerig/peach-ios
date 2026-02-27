# Story 20.9: Move MockHapticFeedbackManager to Test Target

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want `MockHapticFeedbackManager` moved from the production target to the test target,
So that mock types do not ship in the production binary and the project follows its own convention that mocks belong in `PeachTests/`.

## Acceptance Criteria

1. **Mock removed from production** -- `MockHapticFeedbackManager` (lines 59-83 of `Peach/Comparison/HapticFeedbackManager.swift`) is removed from the production target.

2. **Mock exists in test target** -- A new file `PeachTests/Comparison/MockHapticFeedbackManager.swift` contains the `MockHapticFeedbackManager` class with `@testable import Peach`.

3. **No production code references MockHapticFeedbackManager** -- After Story 20.5, the `@Entry` default in `EnvironmentKeys.swift` no longer uses `MockHapticFeedbackManager`. Verify this is the case; if the @Entry default still references it, update to use a different no-op stub.

4. **All tests using MockHapticFeedbackManager pass** -- Tests in `ComparisonTestHelpers.swift` and any other test files that reference `MockHapticFeedbackManager` continue to work via `@testable import Peach`.

5. **All existing tests pass** -- Full test suite passes with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Create mock in test target (AC: #2)
  - [x] Create `PeachTests/Comparison/MockHapticFeedbackManager.swift`
  - [x] Copy `MockHapticFeedbackManager` class
  - [x] Add `@testable import Peach` at top
  - [x] Ensure it conforms to `HapticFeedback` and `ComparisonObserver` protocols

- [x] Task 2: Remove mock from production (AC: #1)
  - [x] Remove lines 59-83 (the `// MARK: - Mock for Testing` section) from `Peach/Comparison/HapticFeedbackManager.swift`

- [x] Task 3: Verify no production references (AC: #3)
  - [x] Search production code for `MockHapticFeedbackManager`
  - [x] If `EnvironmentKeys.swift` references it, replace with a `private` no-op stub

- [x] Task 4: Run full test suite (AC: #4, #5)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **Mock follows project convention** -- Per `docs/project-context.md`: "Mock files live in test target -- `MockNotePlayer.swift`, `MockTrainingDataStore.swift`, etc." The `MockHapticFeedbackManager` was an oversight.
- **Dependencies on Story 20.5** -- The `@Entry` default for `comparisonSession` in `ComparisonScreen.swift` currently uses `MockHapticFeedbackManager()`. Story 20.5 moves this to `EnvironmentKeys.swift` with simplified stubs. This story must run after 20.5 to avoid breaking the @Entry default. If 20.5's simplified stubs already omit `MockHapticFeedbackManager`, this is a clean removal.

### Architecture & Integration

**New files:**
- `PeachTests/Comparison/MockHapticFeedbackManager.swift`

**Modified production files:**
- `Peach/Comparison/HapticFeedbackManager.swift` -- remove mock class

### Existing Code to Reference

- **`HapticFeedbackManager.swift:59-83`** -- `MockHapticFeedbackManager` class (production target). [Source: Peach/Comparison/HapticFeedbackManager.swift]
- **`ComparisonTestHelpers.swift:~13`** -- `let mockHaptic: MockHapticFeedbackManager?` usage in test helper. [Source: PeachTests/Comparison/ComparisonTestHelpers.swift]

### Testing Approach

- **No new tests** -- The mock is used by existing tests; moving it to the test target does not change test behavior.
- **Full suite run** confirms test target can still resolve the mock type.

### Risk Assessment

- **Low risk** -- The mock class is simple (~20 lines). The only risk is if production code still references it after 20.5. A grep search before removal confirms safety.

### Git Intelligence

Commit message: `Implement story 20.9: Move MockHapticFeedbackManager to test target`

### References

- [Source: docs/project-context.md -- "Mock files live in test target"]
- [Source: docs/planning-artifacts/epics.md -- Epic 20]

## Dev Agent Record

### Implementation Notes
- Verified no production code references `MockHapticFeedbackManager` after story 20.5 (grep confirmed `EnvironmentKeys.swift` is clean)
- Clean removal: mock class copied verbatim to test target, removed from production file
- All existing tests pass unchanged — `@testable import Peach` resolves the type from the new test-target location

### Completion Notes
- All 4 tasks completed, all 5 ACs satisfied
- Full test suite: **TEST SUCCEEDED** with zero regressions
- Task 3 (AC #3) required no code change — `EnvironmentKeys.swift` already had no reference to `MockHapticFeedbackManager`

## File List

- `PeachTests/Comparison/MockHapticFeedbackManager.swift` (new) — mock moved to test target
- `PeachTests/Comparison/ComparisonSessionFeedbackTests.swift` (modified) — updated haptic tests to use new mock API
- `Peach/Comparison/HapticFeedbackManager.swift` (modified) — removed mock class (lines 59-83)
- `docs/implementation-artifacts/20-9-move-mockhapticfeedbackmanager-to-test-target.md` (modified) — story file updated
- `docs/implementation-artifacts/sprint-status.yaml` (modified) — status updated

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.
- 2026-02-27: Implementation complete — mock moved to test target, all tests pass.
- 2026-02-27: Code review — fixed mock to follow Mock Contract (removed business logic, added call tracking/callbacks), fixed Git Intelligence typo (20.8→20.9), updated tests to use proper mock API.

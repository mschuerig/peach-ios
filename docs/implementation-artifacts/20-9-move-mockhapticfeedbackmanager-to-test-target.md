# Story 20.9: Move MockHapticFeedbackManager to Test Target

Status: pending

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

- [ ] Task 1: Create mock in test target (AC: #2)
  - [ ] Create `PeachTests/Comparison/MockHapticFeedbackManager.swift`
  - [ ] Copy `MockHapticFeedbackManager` class
  - [ ] Add `@testable import Peach` at top
  - [ ] Ensure it conforms to `HapticFeedback` and `ComparisonObserver` protocols

- [ ] Task 2: Remove mock from production (AC: #1)
  - [ ] Remove lines 59-83 (the `// MARK: - Mock for Testing` section) from `Peach/Comparison/HapticFeedbackManager.swift`

- [ ] Task 3: Verify no production references (AC: #3)
  - [ ] Search production code for `MockHapticFeedbackManager`
  - [ ] If `EnvironmentKeys.swift` references it, replace with a `private` no-op stub

- [ ] Task 4: Run full test suite (AC: #4, #5)
  - [ ] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] All tests pass, zero regressions

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

Commit message: `Implement story 20.8: Move MockHapticFeedbackManager to test target`

### References

- [Source: docs/project-context.md -- "Mock files live in test target"]
- [Source: docs/planning-artifacts/epics.md -- Epic 20]

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.

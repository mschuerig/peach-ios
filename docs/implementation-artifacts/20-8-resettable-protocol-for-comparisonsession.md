# Story 20.8: Resettable Protocol for ComparisonSession Dependencies

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want `ComparisonSession` to depend on a `Resettable` protocol instead of storing `TrendAnalyzer` and `ThresholdTimeline` as concrete types,
So that the session is decoupled from specific profile/analytics implementations and only knows that some of its dependencies can be reset.

## Acceptance Criteria

1. **`Resettable` protocol exists** -- A `protocol Resettable { func reset() }` is defined in `Peach/Core/Training/Resettable.swift`.

2. **`TrendAnalyzer` conforms to `Resettable`** -- `TrendAnalyzer` gains `Resettable` conformance (it already has a `func reset()` method).

3. **`ThresholdTimeline` conforms to `Resettable`** -- `ThresholdTimeline` gains `Resettable` conformance (it already has a `func reset()` method).

4. **`ComparisonSession` uses `[Resettable]`** -- The `private let trendAnalyzer: TrendAnalyzer?` and `private let thresholdTimeline: ThresholdTimeline?` properties are replaced with `private let resettables: [Resettable]`.

5. **`ComparisonSession.init()` accepts resettables** -- The `trendAnalyzer: TrendAnalyzer? = nil` and `thresholdTimeline: ThresholdTimeline? = nil` parameters are replaced with `resettables: [Resettable] = []`.

6. **`resetTrainingData()` uses resettables** -- `trendAnalyzer?.reset()` and `thresholdTimeline?.reset()` are replaced with `resettables.forEach { $0.reset() }`.

7. **`ComparisonSession` has no reference to `TrendAnalyzer` or `ThresholdTimeline`** -- The session file does not mention these concrete types by name.

8. **PeachApp updated** -- `PeachApp.createComparisonSession()` passes `resettables: [trendAnalyzer, thresholdTimeline]` instead of separate parameters.

9. **All existing tests pass** -- Full test suite passes with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Create Resettable protocol (AC: #1)
  - [x] Create `Peach/Core/Training/Resettable.swift`
  - [x] Define `protocol Resettable { func reset() }`

- [x] Task 2: Add conformance (AC: #2, #3)
  - [x] Add `extension TrendAnalyzer: Resettable {}` (already has `reset()`)
  - [x] Add `extension ThresholdTimeline: Resettable {}` (already has `reset()`)

- [x] Task 3: Refactor ComparisonSession (AC: #4, #5, #6, #7)
  - [x] Replace `private let trendAnalyzer: TrendAnalyzer?` and `private let thresholdTimeline: ThresholdTimeline?` with `private let resettables: [Resettable]`
  - [x] Replace init parameters with `resettables: [Resettable] = []`
  - [x] Replace `trendAnalyzer?.reset()` and `thresholdTimeline?.reset()` with `resettables.forEach { $0.reset() }`

- [x] Task 4: Update PeachApp (AC: #8)
  - [x] Change `createComparisonSession()` to pass `resettables: [trendAnalyzer, thresholdTimeline]`

- [x] Task 5: Update test helpers (AC: #9)
  - [x] Update `ComparisonTestHelpers.makeComparisonSession()` to use new `resettables` parameter (default `[]`)
  - [x] Update reset-specific tests to inject mock `Resettable` objects

- [x] Task 6: Run full test suite (AC: #9)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **`Resettable` is a focused protocol** -- It has exactly one method: `reset()`. This is the minimum abstraction needed to decouple `ComparisonSession` from `TrendAnalyzer` and `ThresholdTimeline`. It is not a generic "lifecycle" protocol; it specifically addresses the training data reset use case.
- **Array instead of optionals** -- `[Resettable]` is cleaner than two optionals. It also makes it easy to add new resettable dependencies in the future without changing the session's init signature.
- **`PerceptualProfile.reset()` is called directly** -- `ComparisonSession` already stores `profile: PitchDiscriminationProfile` and calls `profile.reset()` directly (line 145). This is correct because `profile` is used for more than just reset (it's read for strategy decisions). Only `TrendAnalyzer` and `ThresholdTimeline` are stored solely for their `reset()` method.

### Architecture & Integration

**New files:**
- `Peach/Core/Training/Resettable.swift` (protocol definition)

**Modified production files:**
- `Peach/Core/Profile/TrendAnalyzer.swift` -- add `Resettable` conformance
- `Peach/Core/Profile/ThresholdTimeline.swift` -- add `Resettable` conformance
- `Peach/Comparison/ComparisonSession.swift` -- replace concrete types with `[Resettable]`
- `Peach/App/PeachApp.swift` -- update `createComparisonSession()` call

**Modified test files:**
- `PeachTests/Comparison/ComparisonTestHelpers.swift` -- update `makeComparisonSession()`
- `PeachTests/Comparison/ComparisonSessionResetTests.swift` (if exists) -- update to inject mock resettables

### Existing Code to Reference

- **`ComparisonSession.swift:31-32`** -- `private let trendAnalyzer: TrendAnalyzer?` and `private let thresholdTimeline: ThresholdTimeline?`. [Source: Peach/Comparison/ComparisonSession.swift]
- **`ComparisonSession.swift:76-77`** -- Init parameters: `trendAnalyzer: TrendAnalyzer? = nil, thresholdTimeline: ThresholdTimeline? = nil`. [Source: Peach/Comparison/ComparisonSession.swift]
- **`ComparisonSession.swift:146-147`** -- `trendAnalyzer?.reset()` and `thresholdTimeline?.reset()` in `resetTrainingData()`. [Source: Peach/Comparison/ComparisonSession.swift]
- **`TrendAnalyzer.swift`** -- Has `func reset()` that clears entries and recomputes trend. [Source: Peach/Core/Profile/TrendAnalyzer.swift]
- **`ThresholdTimeline.swift`** -- Has `func reset()` that clears timeline entries. [Source: Peach/Core/Profile/ThresholdTimeline.swift]

### Testing Approach

- **Test the `Resettable` contract** -- Create a simple mock `Resettable` in tests, inject it into `ComparisonSession`, call `resetTrainingData()`, and verify `reset()` was called.
- **Existing reset tests** -- If `ComparisonSessionResetTests` exists and verifies trend/timeline reset behavior, those tests should inject `TrendAnalyzer` and `ThresholdTimeline` as resettables.

### Risk Assessment

- **Low risk** -- The `reset()` method signature is identical. The only change is how the session discovers its resettable dependencies (array instead of named optionals). The reset behavior is preserved.

### Git Intelligence

Commit message: `Implement story 20.8: Resettable protocol for ComparisonSession dependencies`

### References

- [Source: docs/project-context.md -- "Protocol-first design"]
- [Source: docs/planning-artifacts/epics.md -- Epic 20]

## Dev Agent Record

### Implementation Plan

- Created `Resettable` protocol with single `reset()` method in `Core/Training/`
- Added empty conformance extensions for `TrendAnalyzer` and `ThresholdTimeline` (both already had `reset()`)
- Replaced two optional concrete properties in `ComparisonSession` with a single `[Resettable]` array
- Updated `PeachApp.createComparisonSession()` to pass resettables array
- Updated `ComparisonSessionResetTests` to use `resettables:` parameter
- Created `MockResettable` for testing the protocol contract
- Created `ResettableTests` verifying protocol usage, conformances, and `ComparisonSession` integration

### Completion Notes

- All 9 acceptance criteria satisfied
- `ComparisonSession.swift` has zero references to `TrendAnalyzer` or `ThresholdTimeline`
- `ComparisonTestHelpers.makeComparisonSession()` already defaulted to no trend/timeline — no changes needed
- Full test suite passes with zero regressions

## File List

- `Peach/Core/Training/Resettable.swift` (new) — protocol definition
- `Peach/Core/Profile/TrendAnalyzer.swift` (modified) — added `Resettable` conformance extension
- `Peach/Core/Profile/ThresholdTimeline.swift` (modified) — added `Resettable` conformance extension
- `Peach/Comparison/ComparisonSession.swift` (modified) — replaced concrete types with `[Resettable]`
- `Peach/App/PeachApp.swift` (modified) — pass `resettables:` instead of named parameters
- `PeachTests/Core/Training/ResettableTests.swift` (new) — protocol and integration tests
- `PeachTests/Mocks/MockResettable.swift` (new) — mock for testing
- `PeachTests/Comparison/ComparisonSessionResetTests.swift` (modified) — use `resettables:` parameter
- `PeachTests/Comparison/ComparisonTestHelpers.swift` (modified) — added `resettables` parameter
- `docs/project-context.md` (modified) — updated protocol naming convention
- `docs/implementation-artifacts/sprint-status.yaml` (modified) — status tracking
- `docs/implementation-artifacts/20-8-resettable-protocol-for-comparisonsession.md` (modified) — story file

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.
- 2026-02-27: Implementation complete — Resettable protocol introduced, ComparisonSession decoupled from TrendAnalyzer and ThresholdTimeline concrete types.
- 2026-02-27: Code review fixes — updated project-context.md naming convention, added resettables param to ComparisonTestHelpers, added ThresholdTimeline integration test, fixed story typo, cleaned up protocol doc comment, added MockResettable cleanup method.

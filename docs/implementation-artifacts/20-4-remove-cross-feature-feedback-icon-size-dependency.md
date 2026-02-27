# Story 20.4: Remove Cross-Feature Feedback Icon Size Dependency

Status: pending

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want `PitchMatchingFeedbackIndicator` to define its own icon size constant instead of referencing `ComparisonFeedbackIndicator.defaultIconSize`,
So that PitchMatching/ has no dependency on Comparison/ and each feature module is self-contained.

## Acceptance Criteria

1. **Local constant defined** -- `PitchMatchingFeedbackIndicator` has a `private static let defaultIconSize: CGFloat = 100` (same value as the Comparison version).

2. **No cross-feature reference** -- `PitchMatchingFeedbackIndicator.swift` contains no reference to `ComparisonFeedbackIndicator`.

3. **Icon sizes unchanged** -- The icon sizes remain 100pt for the dead-center/far bands. Visual behavior is identical.

4. **All existing tests pass** -- Full test suite passes with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Add local constant (AC: #1)
  - [ ] Add `private static let defaultIconSize: CGFloat = 100` to `PitchMatchingFeedbackIndicator`

- [ ] Task 2: Replace cross-feature references (AC: #2)
  - [ ] Replace `ComparisonFeedbackIndicator.defaultIconSize` on line 15 with `defaultIconSize`
  - [ ] Replace `ComparisonFeedbackIndicator.defaultIconSize` on line ~95 with `defaultIconSize`

- [ ] Task 3: Run full test suite (AC: #3, #4)
  - [ ] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] All tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **Duplicate the constant, don't share it** -- Creating a shared constant in Core/ would violate the "no Utils/Helpers/Shared/Common directories" rule. The constant is a UI layout value (icon size in points), not a domain concept. Each feature module should own its own UI constants independently.
- **100pt is the design value** -- Both feedback indicators use 100pt as the "default" icon size for their largest state. This is a coincidence of the design, not a shared invariant. If one changes, the other doesn't need to follow.

### Architecture & Integration

**Modified production files:**
- `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` -- add local constant, replace two references

### Existing Code to Reference

- **`PitchMatchingFeedbackIndicator.swift:15`** -- `private static let farIconSize: CGFloat = ComparisonFeedbackIndicator.defaultIconSize`. [Source: Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift]
- **`ComparisonFeedbackIndicator.swift`** -- `static let defaultIconSize: CGFloat = 100`. [Source: Peach/Comparison/ComparisonFeedbackIndicator.swift]

### Testing Approach

- **No new tests** -- The icon size constants are not tested directly; they are visual layout values. Existing tests cover the `band()`, `centOffsetText()`, and `feedbackColor()` static methods which don't reference icon sizes.

### Risk Assessment

- **Extremely low risk** -- Replacing a cross-module reference with a local constant of the same value. No behavioral change.

### Git Intelligence

Commit message: `Implement story 20.3: Remove cross-feature feedback icon size dependency`

### References

- [Source: docs/project-context.md -- "Do not create Utils/, Helpers/, Shared/, Common/ directories"]
- [Source: docs/planning-artifacts/epics.md -- Epic 20]

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.

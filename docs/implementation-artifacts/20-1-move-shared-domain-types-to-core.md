# Story 20.1: Move Shared Domain Types to Core/Training/

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want shared domain types (`Comparison`, `CompletedComparison`, `ComparisonObserver`, `CompletedPitchMatching`, `PitchMatchingObserver`) moved from feature directories to `Core/Training/`,
So that Core/ no longer has upward dependencies on feature modules, and the dependency arrows point in the correct direction.

## Acceptance Criteria

1. **`Core/Training/` directory exists** -- A new `Peach/Core/Training/` directory contains the four moved files. A mirror `PeachTests/Core/Training/` directory exists (empty for now, as these types have no dedicated test files).

2. **`Comparison.swift` moved** -- `Peach/Comparison/Comparison.swift` (containing `Comparison` and `CompletedComparison`) is moved to `Peach/Core/Training/Comparison.swift`. The original file no longer exists in `Peach/Comparison/`.

3. **`ComparisonObserver.swift` moved** -- `Peach/Comparison/ComparisonObserver.swift` is moved to `Peach/Core/Training/ComparisonObserver.swift`. The original file no longer exists.

4. **`CompletedPitchMatching.swift` moved** -- `Peach/PitchMatching/CompletedPitchMatching.swift` is moved to `Peach/Core/Training/CompletedPitchMatching.swift`. The original file no longer exists.

5. **`PitchMatchingObserver.swift` moved** -- `Peach/PitchMatching/PitchMatchingObserver.swift` is moved to `Peach/Core/Training/PitchMatchingObserver.swift`. The original file no longer exists.

6. **No Core/ file depends on any type defined in a feature directory** -- After the move, all types referenced by `Core/Data/`, `Core/Profile/`, and `Core/Algorithm/` files are defined within `Core/` itself.

7. **Zero code changes required** -- Because Peach is a single-module app, types are resolved by name, not directory path. No `import` statements or type references need updating.

8. **All existing tests pass** -- Full test suite passes with zero regressions and zero code changes.

## Tasks / Subtasks

- [x] Task 1: Create directories (AC: #1)
  - [x] Create `Peach/Core/Training/`
  - [x] Create `PeachTests/Core/Training/`

- [x] Task 2: Move Comparison types (AC: #2, #3)
  - [x] `git mv Peach/Comparison/Comparison.swift Peach/Core/Training/Comparison.swift`
  - [x] `git mv Peach/Comparison/ComparisonObserver.swift Peach/Core/Training/ComparisonObserver.swift`

- [x] Task 3: Move PitchMatching types (AC: #4, #5)
  - [x] `git mv Peach/PitchMatching/CompletedPitchMatching.swift Peach/Core/Training/CompletedPitchMatching.swift`
  - [x] `git mv Peach/PitchMatching/PitchMatchingObserver.swift Peach/Core/Training/PitchMatchingObserver.swift`

- [x] Task 4: Verify dependency direction (AC: #6)
  - [x] Audit Core/ files to confirm none reference types in Comparison/ or PitchMatching/

- [x] Task 5: Run full test suite (AC: #7, #8)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All tests pass, zero regressions, zero code changes

## Dev Notes

### Critical Design Decisions

- **Pure file move, zero code changes** -- Xcode objectVersion 77 uses file-system-synchronized groups. Moving files on disk with `git mv` is sufficient; no `.pbxproj` edits needed. The Swift compiler resolves types by name within the module, not by directory path.
- **`Core/Training/` as the new home** -- These types are domain primitives (value types and protocols) used by Core/Algorithm, Core/Profile, Core/Data, and both feature sessions. They are not UI types and not feature-specific. `Core/Training/` groups them as the shared training domain vocabulary.
- **`PitchMatchingChallenge` stays** -- `PitchMatchingChallenge` is only used within the PitchMatching feature module and does not need to move.

### Architecture & Integration

**New directories:**
- `Peach/Core/Training/` (production)
- `PeachTests/Core/Training/` (test mirror, initially empty)

**Moved files (content unchanged):**
- `Peach/Comparison/Comparison.swift` -> `Peach/Core/Training/Comparison.swift`
- `Peach/Comparison/ComparisonObserver.swift` -> `Peach/Core/Training/ComparisonObserver.swift`
- `Peach/PitchMatching/CompletedPitchMatching.swift` -> `Peach/Core/Training/CompletedPitchMatching.swift`
- `Peach/PitchMatching/PitchMatchingObserver.swift` -> `Peach/Core/Training/PitchMatchingObserver.swift`

**No modified files.** All consumers reference these types by name only.

### Existing Code to Reference

- **`Core/Data/TrainingDataStore.swift`** -- Conforms to `ComparisonObserver` and `PitchMatchingObserver`; references `CompletedComparison` and `CompletedPitchMatching`. [Source: Peach/Core/Data/TrainingDataStore.swift]
- **`Core/Profile/PerceptualProfile.swift`** -- Conforms to `ComparisonObserver` and `PitchMatchingObserver`. [Source: Peach/Core/Profile/PerceptualProfile.swift]
- **`Core/Algorithm/NextComparisonStrategy.swift`** -- References `Comparison` and `CompletedComparison` in protocol signature. [Source: Peach/Core/Algorithm/NextComparisonStrategy.swift]
- **`Core/Profile/TrendAnalyzer.swift`** -- Conforms to `ComparisonObserver`, references `CompletedComparison`. [Source: Peach/Core/Profile/TrendAnalyzer.swift]
- **`Core/Profile/ThresholdTimeline.swift`** -- Conforms to `ComparisonObserver`, references `CompletedComparison`. [Source: Peach/Core/Profile/ThresholdTimeline.swift]

### Testing Approach

- **No new tests** -- This is a pure file move with no behavioral change.
- **Run full suite** to confirm the compiler resolves all types correctly at their new paths.

### Risk Assessment

- **Extremely low risk** -- Single-module app means file location does not affect compilation. The only risk is Xcode project file corruption, mitigated by using `git mv` and the modern file-system-synchronized project format.

### Git Intelligence

Commit message: `Implement story 20.1: Move shared domain types to Core/Training/`

### Project Structure Notes

- `Core/Training/` is a new subdirectory alongside `Core/Audio/`, `Core/Algorithm/`, `Core/Data/`, and `Core/Profile/`
- It holds the shared training vocabulary (value types and observer protocols) used across features

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 20: Right Direction — Dependency Inversion Cleanup]
- [Source: docs/project-context.md -- File Placement decision tree]

## Dev Agent Record

### Implementation Notes
- Pure file move using `git mv` — zero code changes, zero import changes
- Xcode objectVersion 77 file-system-synchronized groups handle the move automatically
- Dependency audit confirmed: no Core/ file references types still in feature directories
- Full test suite passed with zero regressions

### Completion Notes
- All 4 files moved from feature directories to `Core/Training/`
- `PitchMatchingChallenge.swift` correctly left in PitchMatching (feature-only type)
- Dependency direction verified: Core/ is now self-contained for training domain types

## File List

- `Peach/Core/Training/Comparison.swift` (moved from `Peach/Comparison/`)
- `Peach/Core/Training/ComparisonObserver.swift` (moved from `Peach/Comparison/`)
- `Peach/Core/Training/CompletedPitchMatching.swift` (moved from `Peach/PitchMatching/`)
- `Peach/Core/Training/PitchMatchingObserver.swift` (moved from `Peach/PitchMatching/`)
- `PeachTests/Core/Training/.gitkeep` (new, empty test mirror directory)
- `docs/implementation-artifacts/sprint-status.yaml` (status update)
- `docs/implementation-artifacts/20-1-move-shared-domain-types-to-core.md` (this file)

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.
- 2026-02-27: Implementation complete — moved 4 shared domain type files to Core/Training/, full test suite passes.

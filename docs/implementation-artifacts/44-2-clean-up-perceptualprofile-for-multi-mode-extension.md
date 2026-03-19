# Story 44.2: Clean Up PerceptualProfile for Multi-Mode Extension

Status: ready-for-dev

## Story

As a **developer**,
I want PerceptualProfile cleaned up with stale tracking removed and naming normalized,
So that it has clean extension points for the new RhythmProfile protocol conformance.

## Acceptance Criteria

1. **Given** PerceptualProfile currently contains per-MIDI-note comparison tracking, **when** the cleanup is performed, **then** any unused per-MIDI-note tracking that doesn't serve current pitch training functionality is removed.

2. **Given** PerceptualProfile conforms to PitchComparisonProfile and PitchMatchingProfile, **when** internal naming is reviewed, **then** naming conventions are normalized to align with the protocol-first pattern (PitchComparisonProfile, PitchMatchingProfile, future RhythmProfile).

3. **Given** the cleanup is complete, **when** PerceptualProfile is inspected, **then** it has clean extension points where new protocol conformances (e.g., RhythmProfile) can be added without modifying existing protocol conformances.

4. **Given** all existing pitch comparison and pitch matching tests, **when** they are run after cleanup, **then** all tests pass — no behavioral changes to existing functionality.

## Tasks / Subtasks

- [ ] Task 1: Audit per-MIDI-note tracking for stale code (AC: #1)
  - [ ] Verify each `PerceptualNote` field (`mean`, `stdDev`, `m2`, `sampleCount`, `currentDifficulty`) is actively consumed
  - [ ] Verify each `PitchComparisonProfile` protocol method is called outside PerceptualProfile
  - [ ] Remove any truly dead tracking (if found — see Dev Notes)
  - [ ] Run `bin/test.sh` to confirm no behavioral changes

- [ ] Task 2: Normalize internal naming for protocol-first alignment (AC: #2)
  - [ ] Prefix comparison-specific storage: `noteStats` → `comparisonNoteStats`
  - [ ] Reorganize MARK sections by protocol conformance:
    - `// MARK: - PitchComparisonProfile` (all comparison properties/methods)
    - `// MARK: - PitchMatchingProfile` (all matching properties/methods)
    - `// MARK: - Reset` (all reset methods)
  - [ ] Run `bin/test.sh` to confirm no behavioral changes

- [ ] Task 3: Create clean extension points for new protocol conformances (AC: #3)
  - [ ] Separate comparison and matching state into clearly delineated regions so RhythmProfile state can follow the same pattern
  - [ ] Ensure `resetAll()` calls each protocol's reset method — pattern is already `resetComparison()` + `resetMatching()`, future `resetRhythm()` just adds another call
  - [ ] Ensure observer conformance extensions (`PitchComparisonObserver`, `PitchMatchingObserver`) remain in separate extensions — future `RhythmComparisonObserver`/`RhythmMatchingObserver` follow the same pattern
  - [ ] Run `bin/test.sh` to confirm no behavioral changes

- [ ] Task 4: Final build and test verification (AC: #4)
  - [ ] Run `bin/build.sh` — zero errors, zero warnings
  - [ ] Run `bin/test.sh` — all tests pass
  - [ ] Verify no API changes via `git diff` — method signatures and protocol conformances unchanged

## Dev Notes

### Per-MIDI-note tracking audit results (from story creation analysis)

All per-note tracking is **actively used** — there is no obviously stale code to remove:

| Field | Used By |
|-------|---------|
| `mean` | `comparisonMean`, `comparisonStdDev`, `averageThreshold()`, `weakSpots()` |
| `stdDev` | Computed from `m2` on each update; exposed via `statsForNote()` |
| `m2` | Welford's running variance accumulator — essential for incremental stdDev |
| `sampleCount` | Filters trained vs. untrained notes; `isTrained` computed property |
| `currentDifficulty` | `KazezNoteStrategy` reads indirectly; `setDifficulty()` in protocol; used by adaptive algorithm |

The `isCorrect` parameter in `update(note:centOffset:isCorrect:)` is logged but not used in statistics — this is **by design** (verified by tests: "all answers both correct and incorrect contribute to mean"). Do NOT remove it.

If no dead code is found during implementation, document that finding and move to Task 2. The AC says "any unused... is removed" — if there's nothing unused, that AC is satisfied trivially.

### Naming normalization scope

The goal is to make the internal structure mirror the protocol-first naming pattern so a developer adding `RhythmProfile` conformance later sees exactly where to add their code:

**Rename `noteStats` → `comparisonNoteStats`**:
- This is the main internal rename. Currently "noteStats" is ambiguous — once rhythm adds per-tempo stats, the naming collision would be confusing. Prefixing with `comparison` makes the ownership clear.
- `comparisonNoteStats` is `private`, so no external callers are affected.
- Update all internal references within `PerceptualProfile.swift` (9 occurrences).

**Reorganize MARK sections** to group by protocol:
- Current MARKs: Properties, Initialization, Incremental Update, Weak Spot Identification, Summary Statistics, Accessors, Reset, Regional Difficulty Management, Matching Statistics
- Target MARKs: Initialization, PitchComparisonProfile, PitchMatchingProfile, Reset
- The observer conformance extensions at the bottom are already well-organized — don't change those.

### Clean extension point pattern

After cleanup, `PerceptualProfile` should follow this structure:

```
class PerceptualProfile: PitchComparisonProfile, PitchMatchingProfile {
    // MARK: - PitchComparisonProfile State
    private var comparisonNoteStats: [PerceptualNote]

    // MARK: - PitchMatchingProfile State
    private var matchingCount: Int
    private var matchingMeanAbs: Double
    private var matchingM2: Double

    // (future: MARK: - RhythmProfile State)

    // MARK: - Initialization
    init() { ... }

    // MARK: - PitchComparisonProfile
    func update(...) { ... }
    func weakSpots(...) { ... }
    var comparisonMean: Cents? { ... }
    var comparisonStdDev: Cents? { ... }
    func averageThreshold(...) { ... }
    func statsForNote(...) { ... }
    func setDifficulty(...) { ... }

    // MARK: - PitchMatchingProfile
    func updateMatching(...) { ... }
    var matchingMean: Cents? { ... }
    var matchingStdDev: Cents? { ... }
    var matchingSampleCount: Int { ... }

    // (future: MARK: - RhythmProfile)

    // MARK: - Reset
    func resetComparison() { ... }
    func resetMatching() { ... }
    func resetAll() { ... }  // calls all individual resets
}

// MARK: - PitchComparisonObserver Conformance
extension PerceptualProfile: PitchComparisonObserver { ... }

// MARK: - PitchMatchingObserver Conformance
extension PerceptualProfile: PitchMatchingObserver { ... }

// (future: extension PerceptualProfile: RhythmComparisonObserver)
// (future: extension PerceptualProfile: RhythmMatchingObserver)
```

Adding RhythmProfile will require:
1. Add `RhythmProfile` to class declaration
2. Add rhythm state variables in a new MARK section
3. Add rhythm methods in a new MARK section
4. Add `resetRhythm()` call in `resetAll()`
5. Add observer extensions for `RhythmComparisonObserver` / `RhythmMatchingObserver`

None of these steps modify existing PitchComparison or PitchMatching code.

### This is a pure refactoring — no behavioral changes

- No method signatures change
- No protocol conformances change
- No new functionality added
- `PerceptualNote` struct stays exactly the same (it's comparison-specific but clearly scoped by usage)
- All observers, sessions, and views continue to work unchanged

### Anti-patterns to avoid

- **Do NOT add RhythmProfile conformance** — that's Epic 45+ work
- **Do NOT rename the class** — `PerceptualProfile` stays as-is (the class name is protocol-agnostic, which is correct)
- **Do NOT rename `PerceptualNote`** — the struct is fine; it's used only within comparison context
- **Do NOT change any protocol signatures** — `PitchComparisonProfile` and `PitchMatchingProfile` are untouched
- **Do NOT add `Resettable` conformance** — `PerceptualProfile` intentionally does NOT conform to `Resettable` (it has separate `resetComparison()`, `resetMatching()`, `resetAll()`)
- **Do NOT modify `PeachApp.swift`** — no wiring changes needed
- **Do NOT modify test files** unless they reference the renamed private property (they shouldn't — `comparisonNoteStats` is private)

### Project Structure Notes

- File stays at `Peach/Core/Profile/PerceptualProfile.swift`
- Test file stays at `PeachTests/Core/Profile/PerceptualProfileTests.swift`
- No new files created
- No files moved or deleted

### References

- [Source: docs/planning-artifacts/epics.md — Epic 44, Story 44.2]
- [Source: docs/planning-artifacts/architecture.md — v0.4 Amendment, "Prerequisite Refactorings, Section B"]
- [Source: docs/planning-artifacts/prd.md — Version 0.4 Scope, "Pre-work"]
- [Source: docs/planning-artifacts/architecture.md — RhythmProfile Protocol]
- [Source: docs/project-context.md — Domain types everywhere, Code Style, File Placement]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

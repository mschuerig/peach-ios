# Story 44.2: Clean Up PerceptualProfile for Multi-Mode Extension

Status: done

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

- [x] Task 1: Remove dead per-MIDI-note tracking (AC: #1)
  - [x]Remove `PerceptualNote` struct entirely — it exists only to serve dead code
  - [x]Remove `noteStats: [PerceptualNote]` array (128-slot per-note storage)
  - [x]Remove dead protocol methods from `PitchComparisonProfile`: `weakSpots()`, `statsForNote()`, `setDifficulty()`, `averageThreshold()`
  - [x]Remove implementations of those methods from `PerceptualProfile`
  - [x]Remove dead protocol methods from `MockPitchComparisonProfile` in tests
  - [x]Replace per-note tracking with aggregate Welford's accumulators (same pattern as matching already uses): `comparisonCount`, `comparisonMeanAbs`, `comparisonM2`
  - [x]Rewrite `comparisonMean` and `comparisonStdDev` to read from aggregate accumulators
  - [x]Update `resetComparison()` to reset aggregate accumulators
  - [x]Update tests: remove tests for deleted methods; update `comparisonMean`/`comparisonStdDev` tests for aggregate semantics
  - [x]Run `bin/test.sh` to confirm

- [x] Task 2: Normalize naming across both protocols (AC: #2)
  - [x]Rename `update(note:centOffset:isCorrect:)` → `updateComparison(note:centOffset:isCorrect:)` in `PitchComparisonProfile` protocol and `PerceptualProfile` implementation — aligns with `updateMatching(note:centError:)` naming pattern
  - [x]Update all callers of `update()`: `PitchComparisonObserver` extension, `PeachApp.loadPerceptualProfile()`, `PeachApp.onDataChanged` closure, all tests
  - [x]Rename `MockPitchComparisonProfile` recorded calls accordingly
  - [x]Reorganize MARK sections by protocol conformance:
    - `// MARK: - PitchComparisonProfile` (comparison state + methods)
    - `// MARK: - PitchMatchingProfile` (matching state + methods)
    - `// MARK: - Reset`
  - [x]Run `bin/test.sh` to confirm

- [x] Task 3: Clean extension points for new protocol conformances (AC: #3)
  - [x]Verify comparison and matching state are in clearly delineated regions — future RhythmProfile state follows the same pattern
  - [x]Verify `resetAll()` calls each protocol's reset method — future `resetRhythm()` just adds another call
  - [x]Verify observer conformance extensions are in separate extensions — future `RhythmComparisonObserver`/`RhythmMatchingObserver` follow the same pattern
  - [x]Run `bin/test.sh` to confirm

- [x] Task 4: Final build and test verification (AC: #4)
  - [x]Run `bin/build.sh` — zero errors, zero warnings
  - [x]Run `bin/test.sh` — all tests pass

## Dev Notes

### Dead code analysis — per-MIDI-note tracking

The per-MIDI-note tracking (`noteStats: [PerceptualNote]`) and its associated protocol methods have **zero production callers**:

| Dead Method | Protocol | Production Callers |
|-------------|----------|--------------------|
| `weakSpots(count:)` | `PitchComparisonProfile` | **None** — was used by old `AdaptiveNoteStrategy`, removed in Epic 9 |
| `statsForNote(_:)` | `PitchComparisonProfile` | **None** — same origin |
| `setDifficulty(note:difficulty:)` | `PitchComparisonProfile` | **None** — same origin |
| `averageThreshold(noteRange:)` | `PitchComparisonProfile` | **None** — same origin |
| `comparisonStdDev` | `PitchComparisonProfile` | **None** — defined in protocol, not consumed by any production code |

The only consumed comparison method is `comparisonMean`, used by `KazezNoteStrategy` line 54 as a cold-start fallback.

`PerceptualNote` struct (with `mean`, `stdDev`, `m2`, `sampleCount`, `currentDifficulty`) exists solely to support these dead methods. Remove it entirely.

### Replace per-note storage with aggregate Welford's

Matching already uses this pattern (`matchingCount`, `matchingMeanAbs`, `matchingM2`). Comparison should mirror it:

```swift
// Before: 128-slot array, mean-of-per-note-means
private var noteStats: [PerceptualNote]  // 128 elements

var comparisonMean: Cents? {
    let trained = noteStats.filter { $0.sampleCount > 0 }
    return Cents(trained.map(\.mean).reduce(0, +) / Double(trained.count))
}

// After: aggregate Welford's, direct overall mean
private var comparisonCount: Int = 0
private var comparisonMeanAbs: Double = 0.0
private var comparisonM2: Double = 0.0

var comparisonMean: Cents? {
    comparisonCount > 0 ? Cents(comparisonMeanAbs) : nil
}
```

**Semantic change:** `comparisonMean` shifts from "mean of per-note means" to "overall mean across all samples." `KazezNoteStrategy` uses it only as a rough starting-difficulty fallback on cold start — the practical difference is negligible.

**Test impact:** The `comparisonMeanComputation` test (line 189) trains 3 different notes with 1 sample each → result is identical either way (40.0). Update the test to reflect aggregate semantics if needed.

### Naming: `update()` → `updateComparison()`

Current asymmetry:
- `PitchComparisonProfile.update(note:centOffset:isCorrect:)`
- `PitchMatchingProfile.updateMatching(note:centError:)`

After normalization:
- `PitchComparisonProfile.updateComparison(note:centOffset:isCorrect:)`
- `PitchMatchingProfile.updateMatching(note:centError:)` (unchanged)

This is a protocol signature change. All callers must be updated:

| File | Call Site |
|------|-----------|
| `PerceptualProfile.swift` | Implementation |
| `PerceptualProfile.swift` | `PitchComparisonObserver` extension calls `update()` → `updateComparison()` |
| `PeachApp.swift:168` | `profile.update(note:centOffset:isCorrect:)` in `loadPerceptualProfile` |
| `PeachApp.swift:66` | `profile.update(note:centOffset:isCorrect:)` in `onDataChanged` closure |
| `MockPitchComparisonProfile.swift` | Mock implementation |
| Various test files | Direct calls in integration/unit tests |

### Target structure after cleanup

```
@Observable
final class PerceptualProfile: PitchComparisonProfile, PitchMatchingProfile {
    // MARK: - PitchComparisonProfile State
    private var comparisonCount: Int = 0
    private var comparisonMeanAbs: Double = 0.0
    private var comparisonM2: Double = 0.0

    // MARK: - PitchMatchingProfile State
    private var matchingCount: Int = 0
    private var matchingMeanAbs: Double = 0.0
    private var matchingM2: Double = 0.0

    // (future: RhythmProfile state)

    // MARK: - Initialization
    init() { ... }

    // MARK: - PitchComparisonProfile
    func updateComparison(note:centOffset:isCorrect:) { ... }
    var comparisonMean: Cents? { ... }
    var comparisonStdDev: Cents? { ... }

    // MARK: - PitchMatchingProfile
    func updateMatching(note:centError:) { ... }
    var matchingMean: Cents? { ... }
    var matchingStdDev: Cents? { ... }
    var matchingSampleCount: Int { ... }

    // (future: RhythmProfile methods)

    // MARK: - Reset
    func resetComparison() { ... }
    func resetMatching() { ... }
    func resetAll() { ... }
}

// MARK: - PitchComparisonObserver
extension PerceptualProfile: PitchComparisonObserver { ... }

// MARK: - PitchMatchingObserver
extension PerceptualProfile: PitchMatchingObserver { ... }
```

Both protocols now have symmetric shape: aggregate Welford's accumulators, `update*()` method, `*Mean`/`*StdDev` computed properties, `reset*()` method. Adding `RhythmProfile` will follow the exact same pattern.

### Slimmed `PitchComparisonProfile` protocol

After removing dead methods:

```swift
protocol PitchComparisonProfile: AnyObject {
    func updateComparison(note: MIDINote, centOffset: Cents, isCorrect: Bool)
    var comparisonMean: Cents? { get }
    var comparisonStdDev: Cents? { get }
}
```

### `isCorrect` parameter

The `isCorrect` parameter in `updateComparison()` is passed through but not used in aggregate statistics — all answers contribute to mean/stdDev. Keep it: it's part of the protocol contract and logged for diagnostics. Future strategies might use it.

### Anti-patterns to avoid

- **Do NOT add RhythmProfile conformance** — that's Epic 45+ work
- **Do NOT rename the class** — `PerceptualProfile` stays as-is (protocol-agnostic name is correct)
- **Do NOT add `Resettable` conformance** — `PerceptualProfile` intentionally has separate per-protocol reset methods
- **Do NOT keep dead code "just in case"** — `weakSpots()`, `statsForNote()`, `setDifficulty()`, `averageThreshold()`, `PerceptualNote` are all dead; remove them

### Files to modify

| File | Change |
|------|--------|
| `Peach/Core/Profile/PerceptualProfile.swift` | Remove per-note tracking, add aggregate Welford's, rename `update` → `updateComparison`, reorganize MARKs, remove `PerceptualNote` |
| `Peach/Core/Profile/PitchComparisonProfile.swift` | Remove 4 dead methods, rename `update` → `updateComparison` |
| `Peach/App/PeachApp.swift` | Update `update()` → `updateComparison()` calls (2 sites) |
| `PeachTests/Profile/MockPitchComparisonProfile.swift` | Remove dead mock methods, rename `update` → `updateComparison` |
| `PeachTests/Core/Profile/PerceptualProfileTests.swift` | Remove tests for dead methods, update remaining tests for aggregate semantics and renamed method |
| `PeachTests/Core/Profile/PitchComparisonProfileTests.swift` | Update for renamed method |
| `PeachTests/Profile/ProfileScreenTests.swift` | Update for renamed method (uses `statsForNote` — remove that test or rewrite) |
| `PeachTests/PitchComparison/PitchComparisonSessionIntegrationTests.swift` | Remove/update tests that use `statsForNote()` |
| `PeachTests/PitchComparison/PitchComparisonSessionResetTests.swift` | Remove/update tests that use `statsForNote()` and `setDifficulty()` |
| `PeachTests/PitchComparison/PitchComparisonSessionSettingsTests.swift` | Update `statsForNote()` usage |
| `PeachTests/Core/Profile/PitchMatchingProfileTests.swift` | Update `statsForNote()` usage |

### References

- [Source: docs/planning-artifacts/epics.md — Epic 44, Story 44.2]
- [Source: docs/planning-artifacts/architecture.md — v0.4 Amendment, "Prerequisite Refactorings, Section B"]
- [Source: docs/planning-artifacts/prd.md — Version 0.4 Scope, "Pre-work"]
- [Source: docs/planning-artifacts/architecture.md — RhythmProfile Protocol]
- [Source: docs/project-context.md — Domain types everywhere, Code Style, File Placement]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None

### Completion Notes List

- Removed `PerceptualNote` struct entirely and the 128-slot `noteStats` array
- Removed dead protocol methods: `weakSpots()`, `statsForNote()`, `setDifficulty()`, `averageThreshold()` from `PitchComparisonProfile` and `PerceptualProfile`
- Replaced per-note tracking with aggregate Welford's accumulators (`comparisonCount`, `comparisonMeanAbs`, `comparisonM2`) — mirrors the matching pattern exactly
- `comparisonMean` now returns overall mean across all samples (previously mean-of-per-note-means; negligible practical difference for `KazezNoteStrategy` cold-start fallback)
- `comparisonStdDev` now uses aggregate Welford's (previously variance of per-note means)
- Renamed `update(note:centOffset:isCorrect:)` → `updateComparison(note:centOffset:isCorrect:)` across protocol, implementation, all callers, and all tests
- Removed dead mock methods from `MockPitchComparisonProfile` (no more `noteStats`, `setStats`, `weakSpots`, `statsForNote`, `averageThreshold`, `setDifficulty`)
- Reorganized `PerceptualProfile` MARK sections by protocol conformance: `PitchComparisonProfile State`, `PitchMatchingProfile State`, `PitchComparisonProfile`, `PitchMatchingProfile`, `Reset`
- Observer conformance extensions in separate `MARK` extensions
- Updated all test files to use aggregate assertions instead of per-note `statsForNote()` checks
- All 1069 tests pass, zero build warnings (excluding Xcode metadata warning)

### Change Log

- 2026-03-19: Implemented story 44.2 — removed dead per-note tracking, added aggregate Welford's for comparison, renamed update → updateComparison, reorganized MARK sections, updated all tests
- 2026-03-19: Extracted WelfordAccumulator private struct to eliminate duplication between comparison and matching tracking; future RhythmProfile just adds another instance

### File List

- Peach/Core/Profile/PitchComparisonProfile.swift (modified — removed 4 dead methods, renamed `update` → `updateComparison`)
- Peach/Core/Profile/PerceptualProfile.swift (modified — removed `PerceptualNote`, `noteStats`, dead methods; added aggregate Welford's; renamed `update` → `updateComparison`; reorganized MARKs)
- Peach/App/PeachApp.swift (modified — `update()` → `updateComparison()` at 2 call sites)
- PeachTests/Profile/MockPitchComparisonProfile.swift (modified — removed dead mock methods, renamed `update` → `updateComparison`)
- PeachTests/Core/Profile/PerceptualProfileTests.swift (modified — rewrote tests for aggregate semantics, removed tests for dead methods)
- PeachTests/Core/Profile/PitchMatchingProfileTests.swift (modified — `update()` → `updateComparison()`, replaced `statsForNote()` with `comparisonMean`)
- PeachTests/Profile/ProfileScreenTests.swift (modified — `update()` → `updateComparison()`, replaced `statsForNote()` with `comparisonMean`)
- PeachTests/Settings/SettingsTests.swift (modified — `update()` → `updateComparison()`, replaced `statsForNote()` with `comparisonMean`)
- PeachTests/Settings/TrainingDataImportActionTests.swift (modified — `update()` → `updateComparison()`)
- PeachTests/PitchComparison/PitchComparisonSessionIntegrationTests.swift (modified — replaced `statsForNote()` with `comparisonMean`, `update()` → `updateComparison()`)
- PeachTests/PitchComparison/PitchComparisonSessionResetTests.swift (modified — replaced `statsForNote()`/`setDifficulty()`/`currentDifficulty` checks with `comparisonMean`, `update()` → `updateComparison()`)
- PeachTests/PitchComparison/PitchComparisonSessionSettingsTests.swift (modified — replaced `statsForNote()` with `comparisonMean`)
- PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift (modified — `update()` → `updateComparison()`)

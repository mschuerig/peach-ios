# Story 45.4: RhythmProfile Protocol

Status: review

## Story

As a **developer**,
I want a `RhythmProfile` protocol defining the contract for rhythm perceptual data,
So that sessions and views can depend on the protocol while PerceptualProfile provides the implementation.

## Acceptance Criteria

1. **Given** the `RhythmProfile` protocol, **when** inspected, **then** it declares: `updateRhythmComparison(tempo:offset:isCorrect:)`, `updateRhythmMatching(tempo:userOffset:)`, `rhythmStats(tempo:direction:) -> RhythmTempoStats`, `trainedTempos: [TempoBPM]`, `rhythmOverallAccuracy: Double?`, `resetRhythm()`.

2. **Given** the `RhythmTempoStats` struct, **when** inspected, **then** it contains `mean: RhythmOffset`, `stdDev: RhythmOffset`, `sampleCount: Int`, `currentDifficulty: RhythmOffset`.

3. **Given** the protocol file, **when** it is created, **then** it is placed at `Core/Profile/RhythmProfile.swift` with `RhythmTempoStats` in the same file **and** unit tests for `RhythmTempoStats` are created.

## Tasks / Subtasks

- [x] Task 1: Create `RhythmTempoStats` value type (AC: #2, #3)
  - [x] Define `struct RhythmTempoStats: Sendable` in `Peach/Core/Profile/RhythmProfile.swift`
  - [x] Properties: `let mean: RhythmOffset`, `let stdDev: RhythmOffset`, `let sampleCount: Int`, `let currentDifficulty: RhythmOffset`
  - [x] `nonisolated init` with all four parameters (no defaults)
- [x] Task 2: Create `RhythmProfile` protocol (AC: #1, #3)
  - [x] Define `protocol RhythmProfile: AnyObject` in same file
  - [x] `func updateRhythmComparison(tempo: TempoBPM, offset: RhythmOffset, isCorrect: Bool)`
  - [x] `func updateRhythmMatching(tempo: TempoBPM, userOffset: RhythmOffset)`
  - [x] `func rhythmStats(tempo: TempoBPM, direction: RhythmDirection) -> RhythmTempoStats`
  - [x] `var trainedTempos: [TempoBPM] { get }`
  - [x] `var rhythmOverallAccuracy: Double? { get }`
  - [x] `func resetRhythm()`
- [x] Task 3: Write `RhythmTempoStats` tests (AC: #2, #3)
  - [x] Create `PeachTests/Core/Profile/RhythmTempoStatsTests.swift`
  - [x] `@Suite("RhythmTempoStats")` struct with `@Test` functions (all `async`)
  - [x] Test stored properties are accessible and correct
  - [x] Test `Sendable` conformance compiles
- [x] Task 4: Build verification
  - [x] Run `bin/build.sh` — zero errors, zero warnings
  - [x] Run `bin/test.sh` — full suite passes, zero regressions

## Dev Notes

### Pattern to follow: existing pitch profile protocols

`RhythmProfile` mirrors the existing pitch profile protocols. Reference files:

| Rhythm (new)                   | Pitch (existing pattern)                          |
|--------------------------------|---------------------------------------------------|
| `Core/Profile/RhythmProfile.swift` | `Core/Profile/PitchComparisonProfile.swift`, `Core/Profile/PitchMatchingProfile.swift` |

Key observations from the pitch profile protocols:
- **`AnyObject` constraint** — both `PitchComparisonProfile` and `PitchMatchingProfile` use `: AnyObject` because the conforming type (`PerceptualProfile`) is a class. `RhythmProfile` must also use `: AnyObject`
- **Minimal protocols** — the pitch protocols are extremely lean (1 method / 3 properties); `RhythmProfile` is larger because it combines both comparison and matching concerns into one protocol (the architecture chose this design)
- **No doc comments on pitch protocols** — they have none; follow the same convention (code is self-explanatory)
- **No `import Foundation`** — `PitchComparisonProfile.swift` and `PitchMatchingProfile.swift` have zero imports; `RhythmProfile.swift` also needs zero imports since all referenced types (`TempoBPM`, `RhythmOffset`, `RhythmDirection`) are in the same module

### Architecture specification

From architecture.md (RhythmProfile Protocol section):

```swift
protocol RhythmProfile {
    func updateRhythmComparison(tempo: TempoBPM, offset: RhythmOffset, isCorrect: Bool)
    func updateRhythmMatching(tempo: TempoBPM, userOffset: RhythmOffset)
    func rhythmStats(tempo: TempoBPM, direction: RhythmDirection) -> RhythmTempoStats
    var trainedTempos: [TempoBPM] { get }
    var rhythmOverallAccuracy: Double? { get }
    func resetRhythm()
}

struct RhythmTempoStats {
    let mean: RhythmOffset
    let stdDev: RhythmOffset
    let sampleCount: Int
    let currentDifficulty: RhythmOffset
}
```

**Add `: AnyObject`** to the protocol — the architecture snippet omits it but both pitch profile protocols use it, and the conforming type (`PerceptualProfile`) is a class.

### `nonisolated init` pattern

`RhythmTempoStats` needs `nonisolated init` because default MainActor isolation applies project-wide. Without it, the init would be `@MainActor`-isolated, preventing construction from non-isolated contexts. Follow the same pattern as `TempoBPM`, `RhythmOffset`, `CompletedRhythmComparison`.

### `Sendable` conformance

`RhythmTempoStats` should declare explicit `Sendable` conformance. All its stored properties are value types (`RhythmOffset` is `Sendable`, `Int` is `Sendable`), so it satisfies `Sendable` naturally. Declare it explicitly per the pattern established in story 45.3.

### No imports needed

`RhythmProfile.swift` needs zero imports:
- `TempoBPM` — in `Core/Music/`, same module
- `RhythmOffset` — in `Core/Music/`, same module
- `RhythmDirection` — in `Core/Music/`, same module
- No `Foundation` dependency (no `Date`, no `UUID`)

### Why one protocol instead of two

The pitch domain splits into `PitchComparisonProfile` (1 method) and `PitchMatchingProfile` (3 properties). The architecture consolidates rhythm into a single `RhythmProfile` protocol. Do not split it — follow the architecture as specified.

### Future conforming types (NOT in scope)

`PerceptualProfile` will conform to `RhythmProfile` in story 47.3. Do NOT:
- Implement any conformance on `PerceptualProfile`
- Create `MockRhythmProfile` (that belongs in future stories that need it)
- Add `@Entry` environment key for `RhythmProfile`
- Modify `PeachApp.swift`

### Anti-patterns to avoid

- **Do NOT split into two protocols** — architecture specifies one `RhythmProfile` protocol
- **Do NOT add doc comments listing future conforming types** — speculative
- **Do NOT use XCTest** — Swift Testing only (`@Test`, `@Suite`, `#expect`)
- **Do NOT add explicit `@MainActor`** — redundant with default isolation; use `nonisolated` on init
- **Do NOT add `import SwiftUI` or `import Foundation`** — `Core/` files are framework-free; no Foundation types are needed
- **Do NOT add `Codable` or `Hashable` to `RhythmTempoStats`** — not specified in AC; this is a transient computed stats container, not persisted or compared
- **Do NOT add `Equatable` to `RhythmTempoStats`** — not needed; pitch stats types don't have it either
- **Do NOT implement `RhythmProfile` conformance on `PerceptualProfile`** — that's story 47.3

### Previous story learnings (from 45.3)

- Observer protocols are minimal — single method each, no doc comments listing future conforming types
- `nonisolated init` with default parameter values only where specified (e.g., `timestamp: Date = Date()`)
- `RhythmTempoStats` has no default parameter values — all four properties are required
- Code review of 45.2 removed `Comparable` from `RhythmOffset` — don't assume types have conformances not listed in their AC

### PerceptualProfile extension points (from story 44.2)

Story 44.2 cleaned up `PerceptualProfile` with explicit extension points for `RhythmProfile`:
- Comparison and matching state are in clearly delineated regions
- Future `RhythmProfile` state follows the same `WelfordAccumulator` pattern
- Adding `RhythmProfile` conformance will be additive — no modifications to existing protocol conformances needed

### Project Structure Notes

New files only — no modifications to existing files:
- `Peach/Core/Profile/RhythmProfile.swift` — protocol + `RhythmTempoStats` value type
- `PeachTests/Core/Profile/RhythmTempoStatsTests.swift` — tests for value type

Existing `Core/Profile/` directory contains: `PitchComparisonProfile.swift`, `PitchMatchingProfile.swift`, `PerceptualProfile.swift`, `TrainingModeStatistics.swift`, `WelfordAccumulator.swift`, `MetricPoint.swift`, `TrainingModeConfig.swift`, `ProgressTimeline.swift`, `ChartLayoutCalculator.swift`, `GranularityZoneConfig.swift`.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 45, Story 45.4]
- [Source: docs/planning-artifacts/architecture.md#RhythmProfile Protocol]
- [Source: docs/project-context.md#Type Design — domain types everywhere, nonisolated init]
- [Source: docs/project-context.md#Language-Specific Rules — nonisolated, Sendable, no explicit @MainActor]
- [Source: docs/project-context.md#Testing Rules — Swift Testing, struct-based suites, async test functions]
- [Source: Peach/Core/Profile/PitchComparisonProfile.swift — reference pattern for AnyObject profile protocol]
- [Source: Peach/Core/Profile/PitchMatchingProfile.swift — reference pattern for AnyObject profile protocol]
- [Source: docs/implementation-artifacts/45-3-rhythm-observer-protocols-and-result-types.md — previous story learnings]
- [Source: docs/implementation-artifacts/44-2-clean-up-perceptualprofile-for-multi-mode-extension.md — PerceptualProfile extension points]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Created `RhythmTempoStats` struct with `Sendable` conformance, `nonisolated init`, four required properties (`mean`, `stdDev`, `sampleCount`, `currentDifficulty`)
- Created `RhythmProfile` protocol with `: AnyObject` constraint, 3 methods (`updateRhythmComparison`, `updateRhythmMatching`, `rhythmStats`) and 3 properties (`trainedTempos`, `rhythmOverallAccuracy`, `resetRhythm`)
- Tests verify stored property access and `Sendable` conformance
- Build: zero errors; Tests: 1118 passed (including 2 new), zero regressions

### Change Log

- 2026-03-20: Implemented RhythmTempoStats value type and RhythmProfile protocol with unit tests

### File List

- `Peach/Core/Profile/RhythmProfile.swift` (new)
- `PeachTests/Core/Profile/RhythmTempoStatsTests.swift` (new)
- `docs/implementation-artifacts/45-4-rhythmprofile-protocol.md` (modified)
- `docs/implementation-artifacts/sprint-status.yaml` (modified)

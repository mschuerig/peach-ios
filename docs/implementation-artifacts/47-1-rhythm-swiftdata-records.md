# Story 47.1: Rhythm SwiftData Records

Status: ready-for-dev

## Story

As a **developer**,
I want `RhythmComparisonRecord` and `RhythmMatchingRecord` SwiftData models,
So that rhythm training results can be persisted locally.

## Acceptance Criteria

1. **Given** `RhythmComparisonRecord` `@Model`, **when** inspected, **then** it contains `tempoBPM: Int`, `offsetMs: Double` (signed, negative=early, positive=late), `isCorrect: Bool`, `timestamp: Date`.

2. **Given** `RhythmMatchingRecord` `@Model`, **when** inspected, **then** it contains `tempoBPM: Int`, `expectedOffsetMs: Double` (always 0.0 for v0.4), `userOffsetMs: Double` (signed), `timestamp: Date`, **and** a comment reserves `inputMethod` for future non-tap input.

3. **Given** the `ModelContainer` schema in `PeachApp.swift`, **when** updated, **then** it includes `RhythmComparisonRecord.self` and `RhythmMatchingRecord.self` alongside existing pitch records.

4. **Given** raw types at the SwiftData boundary, **when** compared with domain types, **then** `Int`/`Double` are used at the persistence boundary (consistent with pitch record pattern), domain types at all other boundaries.

## Tasks / Subtasks

- [ ] Task 1: Create `RhythmComparisonRecord` model (AC: #1, #4)
  - [ ] Create `Peach/Core/Data/RhythmComparisonRecord.swift`
  - [ ] `@Model final class` with `tempoBPM: Int`, `offsetMs: Double`, `isCorrect: Bool`, `timestamp: Date`
  - [ ] Init with all properties, `timestamp: Date = Date()` default
  - [ ] Write tests in `PeachTests/Core/Data/RhythmComparisonRecordTests.swift`

- [ ] Task 2: Create `RhythmMatchingRecord` model (AC: #2, #4)
  - [ ] Create `Peach/Core/Data/RhythmMatchingRecord.swift`
  - [ ] `@Model final class` with `tempoBPM: Int`, `expectedOffsetMs: Double`, `userOffsetMs: Double`, `timestamp: Date`
  - [ ] Add comment: `// Future: inputMethod property for non-tap input methods`
  - [ ] Init with all properties, `timestamp: Date = Date()` default
  - [ ] Write tests in `PeachTests/Core/Data/RhythmMatchingRecordTests.swift`

- [ ] Task 3: Register models in `ModelContainer` schema (AC: #3)
  - [ ] In `PeachApp.swift`, add `RhythmComparisonRecord.self` and `RhythmMatchingRecord.self` to the `ModelContainer(for:)` call
  - [ ] Verify build succeeds

- [ ] Task 4: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Follow the pitch record pattern exactly

The two new models mirror `PitchComparisonRecord` and `PitchMatchingRecord` in structure:
- `@Model final class` (not struct — SwiftData requires reference types)
- `import SwiftData` and `import Foundation`
- Raw types (`Int`, `Double`, `Bool`, `Date`) at the persistence boundary — no domain types as stored properties
- Init with all properties, `timestamp: Date = Date()` default
- No docstrings on simple properties unless they clarify non-obvious semantics (e.g., sign convention)

**Existing patterns** (`Peach/Core/Data/PitchComparisonRecord.swift`):
```swift
@Model
final class PitchComparisonRecord {
    var referenceNote: Int
    var targetNote: Int
    var centOffset: Double
    var isCorrect: Bool
    var timestamp: Date
    var interval: Int
    var tuningSystem: String
    init(referenceNote: Int, ..., timestamp: Date = Date()) { ... }
}
```

### Domain type mapping

| SwiftData property | Domain type | Conversion |
|---|---|---|
| `tempoBPM: Int` | `TempoBPM` | `TempoBPM(record.tempoBPM)` / `tempo.value` |
| `offsetMs: Double` | `RhythmOffset` | `RhythmOffset(.milliseconds(record.offsetMs))` / `offset.duration.timeInterval * 1000` |
| `expectedOffsetMs: Double` | `RhythmOffset` | Same as above (always 0.0 for v0.4) |
| `userOffsetMs: Double` | `RhythmOffset` | Same as above |
| `isCorrect: Bool` | `Bool` | Direct |
| `timestamp: Date` | `Date` | Direct |

The conversion between `RhythmOffset` and milliseconds `Double` happens in story 47.2 (TrainingDataStore observer conformance), not in the record model itself.

### `offsetMs` sign convention

Negative = early (user perceived the beat before it happened), positive = late. This mirrors `RhythmOffset.direction`: negative duration → `.early`, positive → `.late`. Document this in a comment on the property.

### ModelContainer registration

Current schema in `PeachApp.swift` (line ~24):
```swift
let container = try ModelContainer(
    for: PitchComparisonRecord.self,
    PitchMatchingRecord.self
)
```
Add both new types to this call. No migration strategy needed — these are new models with no existing data.

### What NOT to do

- Do NOT add CRUD methods to `TrainingDataStore` — that's story 47.2
- Do NOT add observer conformances — that's story 47.2
- Do NOT add profile conformances — that's story 47.3
- Do NOT use domain types (`TempoBPM`, `RhythmOffset`) as stored properties
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT add `@testable import` — test through public interfaces

### Project Structure Notes

- New files go in `Peach/Core/Data/` alongside existing record models
- Test files go in `PeachTests/Core/Data/` mirroring source structure
- No new directories needed — `Core/Data/` already exists

### References

- [Source: Peach/Core/Data/PitchComparisonRecord.swift — pattern to follow]
- [Source: Peach/Core/Data/PitchMatchingRecord.swift — pattern to follow]
- [Source: Peach/App/PeachApp.swift — ModelContainer schema registration]
- [Source: Peach/Core/Music/TempoBPM.swift — domain type, `.value` for raw Int]
- [Source: Peach/Core/Music/RhythmOffset.swift — domain type, `.duration` for raw Duration]
- [Source: Peach/Core/Training/CompletedRhythmComparison.swift — result type that maps to record in story 47.2]
- [Source: Peach/Core/Training/CompletedRhythmMatching.swift — result type that maps to record in story 47.2]
- [Source: docs/planning-artifacts/epics.md#Epic 47: Remember Every Beat]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

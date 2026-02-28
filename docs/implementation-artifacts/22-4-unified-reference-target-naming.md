# Story 22.4: Unified Reference/Target Naming

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want `note1`/`note2` renamed to `referenceNote`/`targetNote` and `Comparison.targetNote` changed to `DetunedMIDINote` (absorbing the separate `centDifference` field) across all value types, records, sessions, strategies, observers, data store, tests, and docs,
So that naming is consistent with the reference/target mental model shared by all training modes, and `Comparison` naturally expresses its target as a detuned note.

## Acceptance Criteria

1. **ComparisonRecord field renames** -- `note1` → `referenceNote`, `note2` → `targetNote`, `note2CentOffset` → `centOffset`. All references across code, tests, and docs use the new names. No occurrence of `note1`, `note2`, `note2CentOffset`, or `centDifference` remains in Swift source files (except comments explaining the rename if needed).

2. **Comparison struct refactored** -- `note1: MIDINote, note2: MIDINote, centDifference: Cents` becomes `referenceNote: MIDINote, targetNote: DetunedMIDINote`. `targetNote.note` replaces old `note2`, `targetNote.offset` replaces `centDifference`. `ComparisonSession`, `NextComparisonStrategy`, `KazezNoteStrategy`, `ComparisonObserver` conformances, and all tests use the new shape.

3. **Comparison frequency methods renamed** -- `note1Frequency` → `referenceFrequency` using `tuningSystem.frequency(for: referenceNote, referencePitch:)`. `note2Frequency` → `targetFrequency` using `tuningSystem.frequency(for: targetNote, referencePitch:)`. Both require explicit `tuningSystem` and `referencePitch` parameters.

4. **CompletedComparison paths updated** -- All code paths use `comparison.referenceNote`, `comparison.targetNote` instead of `comparison.note1`, `comparison.note2`.

5. **PitchMatching names unchanged** -- `PitchMatchingRecord.referenceNote`, `PitchMatchingChallenge.referenceNote`, `CompletedPitchMatching.referenceNote` remain unchanged.

6. **Pure rename + type change, no functional changes** -- Full test suite passes with no behavioral changes.

## Tasks / Subtasks

- [ ] Task 1: Refactor `Comparison` struct (AC: #2, #3)
  - [ ] 1.1 Change `Comparison` fields: `note1: MIDINote` → `referenceNote: MIDINote`, remove `note2: MIDINote` and `centDifference: Cents`, add `targetNote: DetunedMIDINote`
  - [ ] 1.2 Update `isSecondNoteHigher` → `isTargetHigher`: change body to `targetNote.offset.rawValue > 0`
  - [ ] 1.3 Rename `note1Frequency(...)` → `referenceFrequency(...)`: body uses `tuningSystem.frequency(for: referenceNote, referencePitch:)`
  - [ ] 1.4 Rename `note2Frequency(...)` → `targetFrequency(...)`: body simplifies to `tuningSystem.frequency(for: targetNote, referencePitch:)` (no more inline DetunedMIDINote construction)
  - [ ] 1.5 Update `isCorrect(userAnswerHigher:)` to use `isTargetHigher`

- [ ] Task 2: Rename `ComparisonRecord` fields (AC: #1)
  - [ ] 2.1 Rename `note1: Int` → `referenceNote: Int`
  - [ ] 2.2 Rename `note2: Int` → `targetNote: Int`
  - [ ] 2.3 Rename `note2CentOffset: Double` → `centOffset: Double`
  - [ ] 2.4 Update init parameters and doc comments
  - [ ] 2.5 No SwiftData migration needed — no production user base

- [ ] Task 3: Update `KazezNoteStrategy` (AC: #2)
  - [ ] 3.1 Change `last.comparison.centDifference.magnitude` → `last.comparison.targetNote.offset.magnitude`
  - [ ] 3.2 Change `Comparison(note1: note, note2: note, centDifference: Cents(signed))` → `Comparison(referenceNote: note, targetNote: DetunedMIDINote(note: note, offset: Cents(signed)))`
  - [ ] 3.3 Update logger message: `centDiff=` → use `targetNote.offset` equivalent

- [ ] Task 4: Update `ComparisonSession` (AC: #2, #3, #4)
  - [ ] 4.1 `currentDifficulty`: change `currentComparison?.centDifference.magnitude` → `currentComparison?.targetNote.offset.magnitude`
  - [ ] 4.2 `playComparisonNotes()`: change `comparison.note1Frequency(...)` → `comparison.referenceFrequency(...)`, `comparison.note2Frequency(...)` → `comparison.targetFrequency(...)`
  - [ ] 4.3 Update logger messages: `note1=\(comparison.note1.rawValue)` → `ref=\(comparison.referenceNote.rawValue)`, `centDiff=\(comparison.centDifference.rawValue)` → `offset=\(comparison.targetNote.offset.rawValue)`, `comparison.isSecondNoteHigher` → `comparison.isTargetHigher`
  - [ ] 4.4 `trackSessionBest()`: change `completed.comparison.centDifference.magnitude` → `completed.comparison.targetNote.offset.magnitude`

- [ ] Task 5: Update `TrainingDataStore` observer (AC: #1, #4)
  - [ ] 5.1 In `comparisonCompleted(_:)`: `comparison.note1.rawValue` → `comparison.referenceNote.rawValue`, `comparison.note2.rawValue` → `comparison.targetNote.note.rawValue`, `comparison.centDifference.rawValue` → `comparison.targetNote.offset.rawValue`
  - [ ] 5.2 Update ComparisonRecord constructor call to use new parameter names

- [ ] Task 6: Update `PerceptualProfile` observer (AC: #4)
  - [ ] 6.1 `comparison.centDifference.magnitude` → `comparison.targetNote.offset.magnitude`
  - [ ] 6.2 `comparison.note1` → `comparison.referenceNote`

- [ ] Task 7: Update `ThresholdTimeline` and `TimelineDataPoint` (AC: #1, #4)
  - [ ] 7.1 `TimelineDataPoint.centDifference` → `centOffset` (Double field)
  - [ ] 7.2 `TimelineDataPoint.note1` → `referenceNote` (Int field)
  - [ ] 7.3 Update `init(records:)`: `record.note2CentOffset` → `record.centOffset`, `record.note1` → `record.referenceNote`
  - [ ] 7.4 Update `comparisonCompleted(_:)`: `comparison.centDifference` → `comparison.targetNote.offset`, `comparison.note1` → `comparison.referenceNote`
  - [ ] 7.5 Update `recomputeAggregatedPoints()`: `\.centDifference` keypath → `\.centOffset`

- [ ] Task 8: Update `TrendAnalyzer` (AC: #1, #4)
  - [ ] 8.1 `records.map { abs($0.note2CentOffset) }` → `records.map { abs($0.centOffset) }`
  - [ ] 8.2 `completed.comparison.centDifference.magnitude` → `completed.comparison.targetNote.offset.magnitude`
  - [ ] 8.3 Update doc comment: `abs(note2CentOffset)` → `abs(centOffset)`

- [ ] Task 9: Update `PeachApp.swift` profile loading (AC: #1, #4)
  - [ ] 9.1 `MIDINote(record.note1)` → `MIDINote(record.referenceNote)`
  - [ ] 9.2 `abs(record.note2CentOffset)` → `abs(record.centOffset)`

- [ ] Task 10: Update `EnvironmentKeys.swift` preview strategy (AC: #2)
  - [ ] 10.1 `Comparison(note1: MIDINote(60), note2: MIDINote(60), centDifference: Cents(50.0))` → `Comparison(referenceNote: MIDINote(60), targetNote: DetunedMIDINote(note: MIDINote(60), offset: Cents(50.0)))`

- [ ] Task 11: Update all test files (AC: #1, #2, #6)
  - [ ] 11.1 `ComparisonTests.swift` (~20 occurrences): Update all Comparison construction and property access
  - [ ] 11.2 `KazezNoteStrategyTests.swift` (~30 occurrences): Update all Comparison construction and assertions
  - [ ] 11.3 `TrendAnalyzerTests.swift` (~28 occurrences): Update ComparisonRecord construction and centDifference references
  - [ ] 11.4 `TrainingDataStoreTests.swift` (~13 occurrences): Update ComparisonRecord construction
  - [ ] 11.5 `ComparisonSessionLoudnessTests.swift` (~19 occurrences): Update Comparison construction in mocks
  - [ ] 11.6 `ComparisonSessionIntegrationTests.swift` (~10 occurrences): Update Comparison references
  - [ ] 11.7 `ComparisonSessionDifficultyTests.swift` (~3 occurrences): Update Comparison construction
  - [ ] 11.8 `ComparisonSessionResetTests.swift` (~8 occurrences): Update Comparison construction
  - [ ] 11.9 `ComparisonSessionUserDefaultsTests.swift` (~5 occurrences): Update Comparison construction
  - [ ] 11.10 `ComparisonSessionLifecycleTests.swift` (~2 occurrences): Update Comparison references
  - [ ] 11.11 `ThresholdTimelineTests.swift` (~7 occurrences): Update ComparisonRecord and TimelineDataPoint references
  - [ ] 11.12 `DetunedMIDINoteTests.swift` (~9 occurrences): Check for any note1/note2 references
  - [ ] 11.13 `SettingsTests.swift` (~9 occurrences): Update ComparisonRecord construction
  - [ ] 11.14 `ProfilePreviewViewTests.swift` (~1 occurrence): Update Comparison construction
  - [ ] 11.15 `ProfileScreenLayoutTests.swift` (~3 occurrences): Update references
  - [ ] 11.16 `TrainingDataStoreEdgeCaseTests.swift` (~3 occurrences): Update ComparisonRecord construction

- [ ] Task 12: Update mock/helper files (AC: #2)
  - [ ] 12.1 `MockNextComparisonStrategy.swift`: Update default `Comparison(note1:...)` → new shape
  - [ ] 12.2 `ComparisonTestHelpers.swift`: Update comparison factory helpers
  - [ ] 12.3 `MockTrainingDataStore.swift`: Update ComparisonRecord construction in `comparisonCompleted`

- [ ] Task 13: Update view preview code (AC: #1)
  - [ ] 13.1 `ProfileScreen.swift` preview: Update mock Comparison/ComparisonRecord construction
  - [ ] 13.2 `ThresholdTimelineView.swift` preview: Update mock data
  - [ ] 13.3 `ProfilePreviewView.swift` preview: Update mock data
  - [ ] 13.4 `SummaryStatisticsView.swift` preview: Update mock data

- [ ] Task 14: Update `project-context.md` (AC: #1)
  - [ ] 14.1 Update `ComparisonRecord` field documentation to reflect new names
  - [ ] 14.2 Update any references to `note1`/`note2` in domain rules section

- [ ] Task 15: Run full test suite and verify (AC: #6)
  - [ ] 15.1 `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] 15.2 Verify zero behavioral changes
  - [ ] 15.3 Run `tools/check-dependencies.sh` to verify no dependency violations

## Dev Notes

### Comparison Struct Shape Change (Critical)

The `Comparison` struct changes from 3 stored properties to 2:

**Before (current):**
```swift
struct Comparison {
    let note1: MIDINote
    let note2: MIDINote
    let centDifference: Cents
}
```

**After:**
```swift
struct Comparison {
    let referenceNote: MIDINote
    let targetNote: DetunedMIDINote  // absorbs note2 + centDifference
}
```

Key implications:
- `comparison.note2` becomes `comparison.targetNote.note`
- `comparison.centDifference` becomes `comparison.targetNote.offset`
- `comparison.isSecondNoteHigher` → `comparison.isTargetHigher` (uses `targetNote.offset.rawValue > 0`)
- `note2Frequency(...)` simplifies: no more inline `DetunedMIDINote(note: note2, offset: centDifference)` construction — just `tuningSystem.frequency(for: targetNote, referencePitch:)` directly

### ComparisonRecord Stays Flat (No Type Change)

`ComparisonRecord` is a SwiftData `@Model` — its fields must be primitive types (`Int`, `Double`). Only the names change:
- `note1: Int` → `referenceNote: Int`
- `note2: Int` → `targetNote: Int`
- `note2CentOffset: Double` → `centOffset: Double`

No structural change — just renames. No SwiftData migration needed (no production user base).

### TrainingDataStore Mapping Update

In `comparisonCompleted(_:)`, the mapping from `Comparison` → `ComparisonRecord` changes:

**Before:**
```swift
ComparisonRecord(
    note1: comparison.note1.rawValue,
    note2: comparison.note2.rawValue,
    note2CentOffset: comparison.centDifference.rawValue,
    ...
)
```

**After:**
```swift
ComparisonRecord(
    referenceNote: comparison.referenceNote.rawValue,
    targetNote: comparison.targetNote.note.rawValue,
    centOffset: comparison.targetNote.offset.rawValue,
    ...
)
```

### PeachApp.swift Profile Loading Update

The profile loading loop reads ComparisonRecord fields:

**Before:**
```swift
profile.update(
    note: MIDINote(record.note1),
    centOffset: abs(record.note2CentOffset),
    isCorrect: record.isCorrect
)
```

**After:**
```swift
profile.update(
    note: MIDINote(record.referenceNote),
    centOffset: abs(record.centOffset),
    isCorrect: record.isCorrect
)
```

Note: `profile.update(note:centOffset:isCorrect:)` parameter names stay as-is — they use generic names, not note1/note2.

### KazezNoteStrategy Construction Pattern

**Before:**
```swift
return Comparison(
    note1: note,
    note2: note,
    centDifference: Cents(signed)
)
```

**After:**
```swift
return Comparison(
    referenceNote: note,
    targetNote: DetunedMIDINote(note: note, offset: Cents(signed))
)
```

Note: `note2` was always the same MIDI note as `note1` for unison comparison — the cent offset was the only difference. With `DetunedMIDINote`, this is expressed naturally: `DetunedMIDINote(note: note, offset: Cents(signed))`.

### TimelineDataPoint Rename

`TimelineDataPoint` is an internal struct in `ThresholdTimeline.swift`. Its fields rename to match the convention:
- `centDifference: Double` → `centOffset: Double`
- `note1: Int` → `referenceNote: Int`

The `\.centDifference` keypath used in `recomputeAggregatedPoints()` becomes `\.centOffset`.

### Scope Summary

**Production source files (~10):**
- `Comparison.swift` — struct shape change + method renames
- `ComparisonRecord.swift` — field renames
- `ComparisonSession.swift` — caller updates
- `KazezNoteStrategy.swift` — Comparison construction + property access
- `TrainingDataStore.swift` — ComparisonRecord construction in observer
- `PerceptualProfile.swift` — observer property access
- `ThresholdTimeline.swift` — struct fields + observer property access
- `TrendAnalyzer.swift` — observer property access + doc comment
- `PeachApp.swift` — profile loading loop
- `EnvironmentKeys.swift` — preview strategy

**Test/mock files (~19):**
- See Task 11 and Task 12 for full list
- ~175+ total occurrences to rename

**View preview files (~4):**
- `ProfileScreen.swift`, `ThresholdTimelineView.swift`, `ProfilePreviewView.swift`, `SummaryStatisticsView.swift`

### Recommended Execution Order

1. **Comparison.swift** first (defines the new shape) — Tasks 1
2. **ComparisonRecord.swift** — Task 2
3. **Production callers** — Tasks 3-10 (will compile-error until updated)
4. **Test files** — Tasks 11-12 (systematic search-and-replace)
5. **View previews** — Task 13
6. **Documentation** — Task 14
7. **Full test suite** — Task 15

### Grep Verification Commands

After all renames, verify completeness:
```bash
# Must return zero results in Swift files:
grep -rn 'note1\|note2\|note2CentOffset\|centDifference' --include='*.swift' Peach/ PeachTests/

# Exceptions allowed only in comments explaining the rename
```

### Project Structure Notes

- No new files created — all changes are in-place renames
- No new directories needed
- File names stay the same (Comparison.swift, ComparisonRecord.swift, etc.)
- No dependency direction changes — all existing import relationships preserved

### References

- [Source: docs/planning-artifacts/epics.md#Story 22.4] — acceptance criteria and story definition
- [Source: Peach/Core/Training/Comparison.swift] — struct to refactor (3 fields → 2)
- [Source: Peach/Core/Data/ComparisonRecord.swift] — SwiftData model field renames
- [Source: Peach/Comparison/ComparisonSession.swift] — session caller updates
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift:43-47] — Comparison construction
- [Source: Peach/Core/Data/TrainingDataStore.swift:136-138] — ComparisonRecord mapping
- [Source: Peach/Core/Profile/PerceptualProfile.swift:176-179] — observer access
- [Source: Peach/Core/Profile/ThresholdTimeline.swift:3-8,28-33,117-122] — TimelineDataPoint fields + mapping
- [Source: Peach/Core/Profile/TrendAnalyzer.swift:36,87] — centOffset access
- [Source: Peach/App/PeachApp.swift:120-121] — profile loading record access
- [Source: Peach/App/EnvironmentKeys.swift:68] — preview Comparison construction
- [Source: docs/implementation-artifacts/22-3-introduce-detunedmidinote-and-two-world-architecture.md] — previous story patterns and learnings
- [Source: docs/project-context.md] — project rules and conventions

### Previous Story Intelligence (22.3)

**Patterns from story 22.3 to follow:**
- Domain type changes propagate from the core struct outward: change `Comparison` first, then fix all callers
- Frequency method signature changes require updating both the callers in `ComparisonSession` and all test code
- Test migration preserves numerical assertions exactly — same values, same precision
- The `decompose(frequency:)` helper established a `nonisolated static` pattern for SoundFont internals — no impact on this story but demonstrates the established code style
- Code review found stale comments and misleading descriptions — double-check that all doc comments accurately describe the new shape

**Files modified in 22.3 that will be touched again:**
- `Comparison.swift` — was modified to add `tuningSystem` param; now refactored again for note1→referenceNote and type change
- `ComparisonSession.swift` — was updated for TuningSystem; now updated for property renames
- `ComparisonTests.swift` — was updated for `tuningSystem` param; now updated for new property names

### Git Intelligence

**Recent commits (22.1-22.3):**
```
ce2162a Fix code review findings for story 22.3 and mark done
ac9aa73 Implement story 22.3: Introduce DetunedMIDINote and Two-World Architecture
d6f3a93 Implement story 22.2: Domain Type Documentation and API Cleanup
5fc64e6 Fix code review findings for story 22.1 and mark done
e5cb19a Implement story 22.1: Migrate FrequencyCalculation to Domain Types
```

**Pattern:** Commit directly to main, one commit per story, code review as separate commit. Commit message: `Implement story 22.4: Unified Reference/Target Naming`.

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

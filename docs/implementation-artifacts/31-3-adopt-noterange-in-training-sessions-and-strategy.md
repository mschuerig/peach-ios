# Story 31.3: Adopt NoteRange in Training Sessions and Strategy

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want training sessions and the note selection strategy to accept `NoteRange` instead of separate min/max values,
so that range handling is consistent and validated at the boundary.

## Acceptance Criteria

1. **Given** `TrainingSettings`, **when** it is updated, **then** `noteRangeMin`/`noteRangeMax` are replaced by `noteRange: NoteRange`
2. **Given** `ComparisonSession`, **when** it reads settings for a new comparison, **then** it passes `NoteRange` to the strategy (via `TrainingSettings`)
3. **Given** `PitchMatchingSession`, **when** it reads settings for a new challenge, **then** it uses `NoteRange` for note selection (via `TrainingSettings`)
4. **Given** the `NextComparisonStrategy` protocol and `KazezNoteStrategy`, **when** they receive a `NoteRange` (inside `TrainingSettings`), **then** they use `noteRange.lowerBound`/`noteRange.upperBound` for boundary enforcement, **and** upper bound shrinking for intervals uses `NoteRange` arithmetic
5. **Given** `MockNextComparisonStrategy` and other test mocks, **when** updated, **then** they accept `NoteRange` consistent with the protocol change

## Tasks / Subtasks

- [x] Task 1: Update `TrainingSettings` struct (AC: #1)
  - [x] 1.1 Write failing test: `TrainingSettings` has `noteRange: NoteRange` property instead of `noteRangeMin`/`noteRangeMax`
  - [x] 1.2 Replace `noteRangeMin: MIDINote` and `noteRangeMax: MIDINote` with `noteRange: NoteRange` in `TrainingSettings`
  - [x] 1.3 Update init to accept `noteRange: NoteRange` with default `NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))`
  - [x] 1.4 Remove `isInRange(_:)` method (unused in production and tests; replaced by `noteRange.contains(_:)`)
  - [x] 1.5 Verify test passes
- [x] Task 2: Update `KazezNoteStrategy` (AC: #4)
  - [x] 2.1 Replace `settings.noteRangeMin` with `settings.noteRange.lowerBound` (2 occurrences)
  - [x] 2.2 Replace `settings.noteRangeMax` with `settings.noteRange.upperBound` (2 occurrences)
  - [x] 2.3 Verify build succeeds
- [x] Task 3: Simplify `ComparisonSession.currentSettings` (AC: #2)
  - [x] 3.1 Replace decomposed `noteRangeMin: userSettings.noteRange.lowerBound, noteRangeMax: userSettings.noteRange.upperBound` with `noteRange: userSettings.noteRange`
  - [x] 3.2 Verify build succeeds
- [x] Task 4: Simplify `PitchMatchingSession` (AC: #3)
  - [x] 4.1 Replace decomposed min/max in `currentSettings` with `noteRange: userSettings.noteRange`
  - [x] 4.2 Replace `settings.noteRangeMin`/`settings.noteRangeMax` with `settings.noteRange.lowerBound`/`settings.noteRange.upperBound` in `generateChallenge()` (4 occurrences)
  - [x] 4.3 Verify build succeeds
- [x] Task 5: Update test files (AC: #5)
  - [x] 5.1 Update `KazezNoteStrategyTests.swift`: 8 `TrainingSettings(noteRangeMin:noteRangeMax:...)` calls to `TrainingSettings(noteRange: NoteRange(...), ...)`, plus 1 assertion using `settings.noteRangeMin`/`settings.noteRangeMax`
  - [x] 5.2 Update `ComparisonSessionSettingsTests.swift`: 4 assertions `?.noteRangeMin`/`?.noteRangeMax` to `?.noteRange.lowerBound`/`?.noteRange.upperBound`
  - [x] 5.3 Update `ComparisonSessionUserDefaultsTests.swift`: 6 assertions same pattern
  - [x] 5.4 Update `SettingsTests.swift`: 2 assertions `trainingDefaults.noteRangeMin.rawValue`/`.noteRangeMax.rawValue` to `trainingDefaults.noteRange.lowerBound.rawValue`/`.noteRange.upperBound.rawValue`
  - [x] 5.5 Verify all tests calling `TrainingSettings(referencePitch:)` still compile with new default (ComparisonSessionIntegrationTests, ComparisonSessionResetTests)
- [x] Task 6: Run full test suite (AC: all)
  - [x] 6.1 Run `bin/test.sh` — all tests must pass
  - [x] 6.2 Run `bin/build.sh` — no warnings or errors
  - [x] 6.3 Run `bin/check-dependencies.sh` — no dependency violations

## Dev Notes

### Technical Requirements

**What this story IS:**
- Replace `noteRangeMin: MIDINote` and `noteRangeMax: MIDINote` with `noteRange: NoteRange` in `TrainingSettings` struct
- Update all consumers of `TrainingSettings.noteRangeMin`/`noteRangeMax` to use `noteRange.lowerBound`/`noteRange.upperBound`
- Simplify `ComparisonSession.currentSettings` and `PitchMatchingSession.currentSettings` — eliminate the decompose/recompose round-trip (they read `userSettings.noteRange` and now pass it directly)
- Remove `TrainingSettings.isInRange(_:)` — never called in production or test code; `NoteRange.contains(_:)` is the domain-standard equivalent
- Update test files to use the new `TrainingSettings` init and property names

**What this story is NOT:**
- No changes to `UserSettings` protocol — already uses `NoteRange` (done in story 31.2)
- No changes to `AppUserSettings`, `MockUserSettings`, or `PreviewUserSettings` — they already expose `noteRange: NoteRange`
- No changes to `SettingsScreen` or `SettingsKeys` — `@AppStorage` layer is unaffected
- No changes to `PerceptualProfile` or `PianoKeyboardView` — that's story 31.4
- No changes to `NoteRange` itself — created in story 31.1, unchanged
- No semantic behavior changes — purely mechanical refactoring with identical behavior
- No new files — only modifications to existing files
- No localization changes

### Architecture Compliance

**`TrainingSettings` struct change:** This struct is defined in `Core/Algorithm/NextComparisonStrategy.swift`. It already imports `Foundation` and uses `MIDINote` from `Core/Audio/`. `NoteRange` is also in `Core/Audio/`, so no new imports are needed.

**`isInRange(_:)` removal is safe:** A comprehensive search confirms this method is never called in any production code or test file. It exists only as dead code. `NoteRange.contains(_:)` provides the same functionality with the validated domain type.

**`currentSettings` simplification:** Both `ComparisonSession` and `PitchMatchingSession` currently decompose `userSettings.noteRange` back into `lowerBound`/`upperBound` to feed the old `TrainingSettings(noteRangeMin:noteRangeMax:)` init. After this story, the impedance mismatch disappears — `noteRange` flows through directly.

**`generateChallenge` in `PitchMatchingSession`:** This method accesses `settings.noteRangeMin`/`noteRangeMax` directly for interval-adjusted range computation. It becomes `settings.noteRange.lowerBound`/`settings.noteRange.upperBound` — same logic, different property path.

**No cross-feature coupling changes:** `TrainingSettings` is in `Core/Algorithm/` and is consumed by `Comparison/` and `PitchMatching/` — both correct dependency directions (feature depends on core).

### Library & Framework Requirements

**No new dependencies.** This story uses only existing types:
- `NoteRange` — created in story 31.1, located in `Core/Audio/`
- `MIDINote` — existing domain type in `Core/Audio/`
- `Foundation` — standard library

### File Structure Requirements

**0 files created, 4 production files modified, 4 test files modified:**

| File | Action | What Changes |
|------|--------|-------------|
| `Peach/Core/Algorithm/NextComparisonStrategy.swift` | Modify | `TrainingSettings`: replace `noteRangeMin`/`noteRangeMax` with `noteRange: NoteRange`, update init, remove `isInRange(_:)` |
| `Peach/Core/Algorithm/KazezNoteStrategy.swift` | Modify | 4 occurrences: `settings.noteRangeMin`/`Max` -> `settings.noteRange.lowerBound`/`upperBound` |
| `Peach/Comparison/ComparisonSession.swift` | Modify | `currentSettings`: pass `noteRange:` directly instead of decomposing |
| `Peach/PitchMatching/PitchMatchingSession.swift` | Modify | `currentSettings` + `generateChallenge()`: 6 total replacements |

**Test files to update:**

| File | Action | What Changes |
|------|--------|-------------|
| `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift` | Modify | 8 `TrainingSettings(noteRangeMin:noteRangeMax:...)` calls, 1 assertion |
| `PeachTests/Comparison/ComparisonSessionSettingsTests.swift` | Modify | 4 assertions: `?.noteRangeMin`/`Max` -> `?.noteRange.lowerBound`/`upperBound` |
| `PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift` | Modify | 6 assertions: same pattern |
| `PeachTests/Settings/SettingsTests.swift` | Modify | 2 assertions: `trainingDefaults.noteRangeMin.rawValue` -> `trainingDefaults.noteRange.lowerBound.rawValue` |

**Do not touch these files:**
- `Peach/Core/Audio/NoteRange.swift` — story 31.1, no changes
- `Peach/Settings/UserSettings.swift` — story 31.2, already uses `NoteRange`
- `Peach/Settings/AppUserSettings.swift` — storage layer, unaffected
- `Peach/Settings/SettingsKeys.swift` — storage constants, unaffected
- `Peach/Settings/SettingsScreen.swift` — `@AppStorage` layer, unaffected
- `Peach/App/EnvironmentKeys.swift` — `PreviewComparisonStrategy` takes `TrainingSettings` generically
- `PeachTests/Mocks/MockUserSettings.swift` — already uses `noteRange: NoteRange`
- `PeachTests/Mocks/MockNextComparisonStrategy.swift` — stores `TrainingSettings?` generically, auto-compatible
- `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` — no `TrainingSettings` references
- Any profile or visualization files — story 31.4

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — never XCTest.

**All `@Test` functions must be `async`.** No `test` prefix on function names.

**`TrainingSettings` init change propagation:**

The new init signature:
```swift
init(
    noteRange: NoteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)),
    referencePitch: Frequency,
    minCentDifference: Cents = 0.1,
    maxCentDifference: Cents = 100.0
)
```

Callers using only `referencePitch:` (with defaults for note range) compile unchanged:
- `ComparisonSessionIntegrationTests.swift` — `TrainingSettings(referencePitch: .concert440)` — no changes needed
- `ComparisonSessionResetTests.swift` — same pattern, no changes needed
- `KazezNoteStrategyTests.swift` — ~10 call sites using defaults, no changes needed

Callers using explicit `noteRangeMin:`/`noteRangeMax:` must update (8 sites in `KazezNoteStrategyTests.swift`):
```swift
// BEFORE:
TrainingSettings(noteRangeMin: 48, noteRangeMax: 72, referencePitch: .concert440)

// AFTER:
TrainingSettings(noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72)), referencePitch: .concert440)
```

**Assertion migration in test files:**

Pattern A — `KazezNoteStrategyTests` (line 22):
```swift
// BEFORE:
#expect(comparison.referenceNote >= settings.noteRangeMin && comparison.referenceNote <= settings.noteRangeMax)

// AFTER:
#expect(settings.noteRange.contains(comparison.referenceNote))
```

Pattern B — `ComparisonSessionSettingsTests` and `ComparisonSessionUserDefaultsTests`:
```swift
// BEFORE:
#expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)
#expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 72)

// AFTER:
#expect(mockStrategy.lastReceivedSettings?.noteRange.lowerBound == MIDINote(48))
#expect(mockStrategy.lastReceivedSettings?.noteRange.upperBound == MIDINote(72))
```

Pattern C — `SettingsTests`:
```swift
// BEFORE:
#expect(SettingsKeys.defaultNoteRangeMin == trainingDefaults.noteRangeMin.rawValue)
#expect(SettingsKeys.defaultNoteRangeMax == trainingDefaults.noteRangeMax.rawValue)

// AFTER:
#expect(SettingsKeys.defaultNoteRangeMin == trainingDefaults.noteRange.lowerBound.rawValue)
#expect(SettingsKeys.defaultNoteRangeMax == trainingDefaults.noteRange.upperBound.rawValue)
```

**NoteRange span validation — all test values are safe:**
- `MIDINote(48)` to `MIDINote(72)` = 24 semitones (>= 12)
- `MIDINote(60)` to `MIDINote(72)` = 12 semitones (== 12, valid)
- `MIDINote(48)` to `MIDINote(84)` = 36 semitones
- `MIDINote(60)` to `MIDINote(124)` = 64 semitones
- `MIDINote(0)` to `MIDINote(84)` = 84 semitones

**Run full suite:** `bin/test.sh` — all existing + new tests must pass before committing.

### Implementation Guidance

**`NextComparisonStrategy.swift` — updated `TrainingSettings`:**

```swift
struct TrainingSettings {
    var noteRange: NoteRange
    var referencePitch: Frequency
    var minCentDifference: Cents
    var maxCentDifference: Cents

    init(
        noteRange: NoteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)),
        referencePitch: Frequency,
        minCentDifference: Cents = 0.1,
        maxCentDifference: Cents = 100.0
    ) {
        self.noteRange = noteRange
        self.referencePitch = referencePitch
        self.minCentDifference = minCentDifference
        self.maxCentDifference = maxCentDifference
    }
}
```

Remove `isInRange(_:)` entirely — it is dead code (never called in production or tests).

**`KazezNoteStrategy.swift` — updated note range access (lines 44-48):**

```swift
// Direction-based range adjustment for intervals
let minNote: MIDINote
let maxNote: MIDINote
if interval.direction == .up {
    minNote = settings.noteRange.lowerBound
    maxNote = MIDINote(min(settings.noteRange.upperBound.rawValue, 127 - interval.interval.semitones))
} else {
    minNote = MIDINote(max(settings.noteRange.lowerBound.rawValue, interval.interval.semitones))
    maxNote = settings.noteRange.upperBound
}
```

**`ComparisonSession.swift` — simplified `currentSettings`:**

```swift
private var currentSettings: TrainingSettings {
    TrainingSettings(
        noteRange: userSettings.noteRange,
        referencePitch: userSettings.referencePitch
    )
}
```

**`PitchMatchingSession.swift` — simplified `currentSettings` + updated `generateChallenge`:**

```swift
private var currentSettings: TrainingSettings {
    TrainingSettings(
        noteRange: userSettings.noteRange,
        referencePitch: userSettings.referencePitch
    )
}

private func generateChallenge(settings: TrainingSettings, interval: DirectedInterval) -> PitchMatchingChallenge {
    let minNote: MIDINote
    let maxNote: MIDINote
    if interval.direction == .up {
        minNote = settings.noteRange.lowerBound
        maxNote = MIDINote(min(settings.noteRange.upperBound.rawValue, 127 - interval.interval.semitones))
    } else {
        minNote = MIDINote(max(settings.noteRange.lowerBound.rawValue, interval.interval.semitones))
        maxNote = settings.noteRange.upperBound
    }
    // ... rest unchanged
}
```

### Previous Story Intelligence

**Story 31.2 (Adopt NoteRange in UserSettings and Settings Screen) — completed:**
- `UserSettings` protocol now exposes `noteRange: NoteRange` (not separate `noteRangeMin`/`noteRangeMax`)
- `AppUserSettings` constructs `NoteRange` from two `@AppStorage` Int values
- `MockUserSettings` has `noteRange: NoteRange` with default `NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))`
- `ComparisonSession` and `PitchMatchingSession` were mechanically updated: `userSettings.noteRangeMin` -> `userSettings.noteRange.lowerBound` (this story eliminates that decomposition)
- `SettingsKeys.minimumNoteGap` was removed, replaced by `NoteRange.minimumSpan`
- 827 tests passing at story 31.2 completion
- Build clean, dependency rules pass

**Story 31.2 Dev Notes — key insights for this story:**
- The "mechanical fix" in ComparisonSession/PitchMatchingSession (`userSettings.noteRange.lowerBound`/`.upperBound`) was documented as intentionally intermediate — this story cleans it up by having `TrainingSettings` accept `NoteRange` directly
- `@AppStorage` keys are unaffected — the storage layer was already handled
- `SettingsScreen` is unaffected — it operates at the `@AppStorage`/Int level

**Story 31.1 (Create NoteRange Value Type) — completed:**
- Created `NoteRange` struct in `Peach/Core/Audio/NoteRange.swift`
- `precondition` validates minimum 12-semitone span
- Properties: `lowerBound`, `upperBound`, `contains(_:)`, `clamped(_:)`, `semitoneSpan`
- `minimumSpan = 12`
- Conforms to `Equatable`, `Sendable`, `Hashable`

### Git Intelligence

**Recent commits:**
```
3170a45 Review story 31.2: Add defensive fallback for corrupted UserDefaults in AppUserSettings.noteRange
f2b6804 Implement story 31.2: Adopt NoteRange in UserSettings and Settings Screen
e1ef035 Implement story 31.1: Create NoteRange value type
```

**Commit format:** `Implement story 31.3: Adopt NoteRange in Training Sessions and Strategy`

**Current test count:** 827 tests passing (as of story 31.2 completion).

### Project Structure Notes

- All modified files are in their correct locations per project structure rules
- No new files created — only modifications
- `NoteRange` is in `Core/Audio/`, already accessible from `Core/Algorithm/` (same module, core-to-core reference is valid)
- No cross-feature coupling changes — `TrainingSettings` is in `Core/Algorithm/`, consumed by `Comparison/` and `PitchMatching/` (feature depends on core — correct dependency direction)
- `bin/check-dependencies.sh` should pass unchanged — no new imports introduced

### Cross-Story Context (Epic 31 Roadmap)

This is story 3 of 4 in Epic 31:
- **31.1 (done):** Created `NoteRange` value type with validation, contains, clamped, semitoneSpan
- **31.2 (done):** Replaced `noteRangeMin`/`noteRangeMax` in `UserSettings` protocol with `noteRange: NoteRange`; updated all protocol consumers
- **31.3 (this story):** Replace separate min/max in `TrainingSettings`; update `KazezNoteStrategy`, `ComparisonSession`, `PitchMatchingSession`; remove `isInRange(_:)` dead code
- **31.4 (next):** Adopt `NoteRange` in `PerceptualProfile` and `PianoKeyboardView`

**After this story:** The only remaining `noteRangeMin`/`noteRangeMax` references should be in profile/visualization code (31.4) and the `@AppStorage`/`SettingsKeys` storage layer (which intentionally keeps raw Int keys).

### References

- [Source: docs/planning-artifacts/epics.md#Epic 31] — Epic definition, story 31.3 acceptance criteria
- [Source: Peach/Core/Audio/NoteRange.swift] — Value type created in story 31.1, `minimumSpan = 12`, `contains(_:)`, `clamped(_:)`
- [Source: Peach/Core/Algorithm/NextComparisonStrategy.swift:56-80] — `TrainingSettings` struct with `noteRangeMin`/`noteRangeMax` and `isInRange(_:)`
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift:44-48] — Direction-based range adjustment accessing `settings.noteRangeMin`/`Max`
- [Source: Peach/Comparison/ComparisonSession.swift:40-46] — `currentSettings` decomposes `userSettings.noteRange` back to min/max
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:195-201] — Same decomposition pattern
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:209-223] — `generateChallenge()` accesses `settings.noteRangeMin`/`Max`
- [Source: PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift] — 8 call sites with explicit `noteRangeMin:`/`noteRangeMax:`
- [Source: PeachTests/Comparison/ComparisonSessionSettingsTests.swift:31-32,78-79] — Assertions on `?.noteRangeMin`/`Max`
- [Source: PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift:33-34,119,128-129] — Same assertion pattern
- [Source: PeachTests/Settings/SettingsTests.swift:15-16] — `trainingDefaults.noteRangeMin.rawValue` assertions
- [Source: docs/implementation-artifacts/31-2-adopt-noterange-in-usersettings-and-settings-screen.md] — Previous story with learnings
- [Source: docs/project-context.md] — Swift 6.2, precondition pattern, value types, testing rules

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered. Purely mechanical refactoring — all changes compiled and passed on first attempt.

### Completion Notes List

- Replaced `noteRangeMin: MIDINote` and `noteRangeMax: MIDINote` with `noteRange: NoteRange` in `TrainingSettings` struct
- Removed dead code `isInRange(_:)` method from `TrainingSettings`
- Updated `KazezNoteStrategy` to access `settings.noteRange.lowerBound`/`upperBound` (4 occurrences)
- Simplified `ComparisonSession.currentSettings` — `noteRange` now flows directly from `userSettings.noteRange`
- Simplified `PitchMatchingSession.currentSettings` — same direct flow pattern
- Updated `PitchMatchingSession.generateChallenge()` to use `settings.noteRange.lowerBound`/`upperBound` (4 occurrences)
- Updated 4 test files: `KazezNoteStrategyTests` (8 init calls + 1 assertion), `ComparisonSessionSettingsTests` (4 assertions), `ComparisonSessionUserDefaultsTests` (6 assertions), `SettingsTests` (2 assertions)
- Build clean, 826 tests pass, no dependency violations

### Change Log

- 2026-03-04: Implemented story 31.3 — adopted NoteRange in TrainingSettings, training sessions, and strategy
- 2026-03-04: Review story 31.3 — fixed stale test description referencing removed noteRangeMin/noteRangeMax API

### File List

- `Peach/Core/Algorithm/NextComparisonStrategy.swift` — modified (TrainingSettings: replaced noteRangeMin/noteRangeMax with noteRange, removed isInRange)
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` — modified (4 property path updates)
- `Peach/Comparison/ComparisonSession.swift` — modified (currentSettings simplified)
- `Peach/PitchMatching/PitchMatchingSession.swift` — modified (currentSettings simplified + generateChallenge updated)
- `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift` — modified (8 init calls + 1 assertion migrated)
- `PeachTests/Comparison/ComparisonSessionSettingsTests.swift` — modified (4 assertions migrated)
- `PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift` — modified (6 assertions migrated)
- `PeachTests/Settings/SettingsTests.swift` — modified (2 assertions migrated)

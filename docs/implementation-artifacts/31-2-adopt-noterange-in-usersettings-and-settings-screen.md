# Story 31.2: Adopt NoteRange in UserSettings and Settings Screen

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want `UserSettings` to expose a single `noteRange: NoteRange` instead of separate `noteRangeMin`/`noteRangeMax`,
so that all consumers work with a validated range object.

## Acceptance Criteria

1. **Given** the `UserSettings` protocol, **when** it is updated, **then** `noteRangeMin: MIDINote` and `noteRangeMax: MIDINote` are replaced by `noteRange: NoteRange`
2. **Given** `AppUserSettings`, **when** it implements the updated protocol, **then** it constructs `NoteRange` from the two `@AppStorage` values, **and** the `@AppStorage` keys remain unchanged (backward compatible)
3. **Given** `SettingsScreen`, **when** the user adjusts the note range steppers, **then** validation is performed through `NoteRange` (minimum 12-semitone gap), **and** the two-stepper UX remains unchanged
4. **Given** `SettingsKeys`, **when** default range values are accessed, **then** they are expressed as a `NoteRange` (default: C2-C6)
5. **Given** all existing tests, **when** the test suite is run, **then** all tests pass with the updated interface

## Tasks / Subtasks

- [x] Task 1: Update `UserSettings` protocol (AC: #1)
  - [x] 1.1 Write failing test: `MockUserSettings` has `noteRange: NoteRange` property
  - [x] 1.2 Replace `noteRangeMin: MIDINote` and `noteRangeMax: MIDINote` with `noteRange: NoteRange` in `UserSettings` protocol
  - [x] 1.3 Update `MockUserSettings` to use `noteRange: NoteRange` with default `NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))`
  - [x] 1.4 Verify test passes
- [x] Task 2: Update `AppUserSettings` (AC: #2)
  - [x] 2.1 Write failing test: `AppUserSettings().noteRange` returns default `NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))`
  - [x] 2.2 Write failing test: `AppUserSettings().noteRange` reads custom values from UserDefaults
  - [x] 2.3 Replace `noteRangeMin` and `noteRangeMax` computed properties with single `noteRange` property that constructs `NoteRange` from two UserDefaults reads
  - [x] 2.4 Verify tests pass
- [x] Task 3: Update `SettingsKeys` (AC: #4)
  - [x] 3.1 Write failing test: `SettingsKeys.defaultNoteRange` equals `NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))`
  - [x] 3.2 Add `static let defaultNoteRange` computed from existing `defaultNoteRangeMin`/`defaultNoteRangeMax`
  - [x] 3.3 Update `lowerBoundRange`/`upperBoundRange` to use `NoteRange.minimumSpan` instead of `minimumNoteGap`
  - [x] 3.4 Remove `minimumNoteGap` (replaced by `NoteRange.minimumSpan`)
  - [x] 3.5 Verify tests pass
- [x] Task 4: Update protocol consumers — mechanical fix (AC: #1, #5)
  - [x] 4.1 Update `PreviewUserSettings` in `EnvironmentKeys.swift`: replace `noteRangeMin`/`noteRangeMax` with `noteRange`
  - [x] 4.2 Update `ComparisonSession.swift`: change `userSettings.noteRangeMin` to `userSettings.noteRange.lowerBound` and `userSettings.noteRangeMax` to `userSettings.noteRange.upperBound`
  - [x] 4.3 Update `PitchMatchingSession.swift`: same mechanical replacement
  - [x] 4.4 Verify build succeeds
- [x] Task 5: Update `SettingsScreen` validation (AC: #3)
  - [x] 5.1 Verify SettingsScreen still uses `@AppStorage` with raw Int values for Stepper binding (no change to storage)
  - [x] 5.2 Confirm Steppers reference `NoteRange.minimumSpan` via updated `SettingsKeys.lowerBoundRange`/`upperBoundRange`
  - [x] 5.3 Verify the two-stepper UX is unchanged
- [x] Task 6: Update existing tests — CRITICAL: NoteRange minimum span enforcement (AC: #5)
  - [x] 6.1 Update `PitchMatchingSessionTests.swift`: ~20 locations set `noteRangeMin == noteRangeMax` (e.g., both to 69) — must change to valid NoteRange with >= 12 semitone gap (see "Test Migration Guide" in Dev Notes)
  - [x] 6.2 Update `ComparisonSessionSettingsTests.swift`: ~4 locations set `noteRangeMin`/`noteRangeMax` on mock
  - [x] 6.3 Update `ComparisonSessionUserDefaultsTests.swift`: ~4 locations set `noteRangeMin`/`noteRangeMax` on mock
  - [x] 6.4 Update `SettingsTests` that reference `SettingsKeys.minimumNoteGap` (now uses `NoteRange.minimumSpan`)
  - [x] 6.5 Add new NoteRange integration tests to `SettingsTests.swift`
- [x] Task 7: Run full test suite (AC: #5)
  - [x] 7.1 Run `bin/test.sh` - all tests must pass
  - [x] 7.2 Run `bin/build.sh` - no warnings or errors
  - [x] 7.3 Run `bin/check-dependencies.sh` - no dependency violations

## Dev Notes

### Technical Requirements

**What this story IS:**
- Replace two separate properties (`noteRangeMin`/`noteRangeMax`) with a single `noteRange: NoteRange` in the `UserSettings` protocol
- Update all direct consumers of the protocol to use the new interface
- Keep `@AppStorage` keys unchanged for backward compatible storage
- `AppUserSettings` constructs `NoteRange` from the two UserDefaults values
- Add `defaultNoteRange` to `SettingsKeys` and unify gap validation constant with `NoteRange.minimumSpan`

**What this story is NOT:**
- No changes to `TrainingSettings` struct — it keeps `noteRangeMin`/`noteRangeMax` (that's story 31.3)
- No changes to `KazezNoteStrategy` — it reads from `TrainingSettings`, not `UserSettings` (story 31.3)
- No changes to `PerceptualProfile` or `PianoKeyboardView` (story 31.4)
- No changes to Stepper UX — the two-stepper behavior is identical
- No changes to `@AppStorage` key names or value types — storage is backward compatible
- No localization changes
- No new files — only modifications to existing files

### Architecture Compliance

**Protocol change propagation:** When `UserSettings` protocol changes, ALL conforming types and ALL consumers must update:
- **Conforming types:** `AppUserSettings`, `MockUserSettings`, `PreviewUserSettings` (in EnvironmentKeys.swift)
- **Consumers:** `ComparisonSession`, `PitchMatchingSession` (access `userSettings.noteRangeMin/Max`)

**ComparisonSession/PitchMatchingSession changes are mechanical:** These files create `TrainingSettings(noteRangeMin: userSettings.noteRangeMin, noteRangeMax: userSettings.noteRangeMax, ...)`. After the protocol change, they become `TrainingSettings(noteRangeMin: userSettings.noteRange.lowerBound, noteRangeMax: userSettings.noteRange.upperBound, ...)`. Story 31.3 will change `TrainingSettings` to accept `NoteRange` directly — this is intentional incremental refactoring.

**No framework imports in Settings/ files:** `NoteRange` is in `Core/Audio/` with only `import Foundation`. `UserSettings.swift` already imports Foundation and uses `MIDINote` from the same location. No new imports needed.

**`@AppStorage` stays as raw Int:** SwiftUI's `@AppStorage` works with basic types (Int, String, Double, Bool). `NoteRange` cannot be stored directly in `@AppStorage`. The two separate Int keys (`noteRangeMin`, `noteRangeMax`) remain as the storage representation. `AppUserSettings` constructs `NoteRange` on read.

### Library & Framework Requirements

**No new dependencies.** This story uses only existing types:
- `NoteRange` — created in story 31.1, located in `Core/Audio/`
- `MIDINote` — existing domain type in `Core/Audio/`
- `Foundation` — standard library

### File Structure Requirements

**0 files created, 8 files modified:**

| File | Action | What Changes |
|------|--------|-------------|
| `Peach/Settings/UserSettings.swift` | Modify | Replace `noteRangeMin`/`noteRangeMax` with `noteRange: NoteRange` |
| `Peach/Settings/AppUserSettings.swift` | Modify | Replace two computed properties with single `noteRange` that constructs `NoteRange` from UserDefaults |
| `Peach/Settings/SettingsKeys.swift` | Modify | Add `defaultNoteRange`, remove `minimumNoteGap` (use `NoteRange.minimumSpan`), update range functions |
| `Peach/Settings/SettingsScreen.swift` | Verify | Steppers already work via `SettingsKeys` range functions — may only need comment update |
| `Peach/App/EnvironmentKeys.swift` | Modify | Update `PreviewUserSettings`: replace `noteRangeMin`/`noteRangeMax` with `noteRange` |
| `Peach/Comparison/ComparisonSession.swift` | Modify | Mechanical: `userSettings.noteRangeMin` -> `userSettings.noteRange.lowerBound` (2 lines) |
| `Peach/PitchMatching/PitchMatchingSession.swift` | Modify | Mechanical: same replacement (2 lines) |

**Test files to update:**

| File | Action | What Changes |
|------|--------|-------------|
| `PeachTests/Mocks/MockUserSettings.swift` | Modify | Replace `noteRangeMin`/`noteRangeMax` with `noteRange: NoteRange` |
| `PeachTests/Settings/SettingsTests.swift` | Modify | Update defaults tests, add `noteRange` tests |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Modify | ~20 locations: `mockSettings.noteRangeMin/Max` -> `mockSettings.noteRange` with valid spans |
| `PeachTests/Comparison/ComparisonSessionSettingsTests.swift` | Modify | ~4 locations: same mock property migration |
| `PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift` | Modify | ~4 locations: same mock property migration |

**Do not touch these files:**
- `Peach/Core/Audio/NoteRange.swift` — created in story 31.1, no changes needed
- `Peach/Core/Algorithm/NextComparisonStrategy.swift` — `TrainingSettings` changes are story 31.3
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` — reads from `TrainingSettings`, not `UserSettings` (story 31.3)
- `PeachTests/Core/Audio/NoteRangeTests.swift` — story 31.1 tests, no changes needed
- Any profile or visualization files — story 31.4

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — never XCTest.

**All `@Test` functions must be `async`.** No `test` prefix on function names.

**New tests to add in `PeachTests/Settings/SettingsTests.swift`:**

```swift
// MARK: - NoteRange Integration

@Test("SettingsKeys defaultNoteRange is C2-C6")
func defaultNoteRange() async {
    let range = SettingsKeys.defaultNoteRange
    #expect(range.lowerBound == MIDINote(36))
    #expect(range.upperBound == MIDINote(84))
}

@Test("AppUserSettings returns default NoteRange when no UserDefaults entries")
func appUserSettingsNoteRangeDefault() async {
    UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMin)
    UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMax)
    let settings = AppUserSettings()
    #expect(settings.noteRange == NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)))
}

@Test("AppUserSettings reads custom NoteRange from UserDefaults")
func appUserSettingsNoteRangeCustom() async {
    defer {
        UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.removeObject(forKey: SettingsKeys.noteRangeMax)
    }
    UserDefaults.standard.set(48, forKey: SettingsKeys.noteRangeMin)
    UserDefaults.standard.set(96, forKey: SettingsKeys.noteRangeMax)
    let settings = AppUserSettings()
    #expect(settings.noteRange == NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(96)))
}

@Test("MockUserSettings noteRange defaults to C2-C6")
func mockUserSettingsNoteRange() async {
    let mock = MockUserSettings()
    #expect(mock.noteRange == NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84)))
}

@Test("MockUserSettings allows noteRange injection")
func mockUserSettingsNoteRangeInjection() async {
    let mock = MockUserSettings()
    mock.noteRange = NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72))
    #expect(mock.noteRange.lowerBound == MIDINote(48))
    #expect(mock.noteRange.upperBound == MIDINote(72))
}
```

**Existing tests to update:**

`SettingsTests.algorithmDefaultsMatchTrainingSettings()` — currently references `SettingsKeys.defaultNoteRangeMin == trainingDefaults.noteRangeMin.rawValue`. This test still compiles (it's comparing `SettingsKeys` Int defaults with `TrainingSettings` properties, neither of which changes in this story). No update needed.

`SettingsTests.lowerBoundRangeEnforcesGap()` and `upperBoundRangeEnforcesGap()` — these test `SettingsKeys.lowerBoundRange(noteRangeMax:)` and `upperBoundRange(noteRangeMin:)`. The function signatures don't change, only the internal constant (`minimumNoteGap` -> `NoteRange.minimumSpan`). Tests pass unchanged.

**Tests that reference MockUserSettings `noteRangeMin`/`noteRangeMax`:** Search for all test files that set `mock.noteRangeMin` or `mock.noteRangeMax`. These need to change to `mock.noteRange = NoteRange(lowerBound:upperBound:)`.

**Run full suite:** `bin/test.sh` — all existing + new tests must pass before committing.

### Test Migration Guide — CRITICAL

**Problem:** Many existing tests set `mockSettings.noteRangeMin == mockSettings.noteRangeMax` (e.g., both to MIDINote(69)) to force a specific note for deterministic testing. `NoteRange` requires a minimum 12-semitone span, so `NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(69))` would CRASH with a precondition failure.

**Solution:** Tests must use valid NoteRange spans (>= 12 semitones). The migration depends on what the test verifies:

**Pattern A — Tests checking session state transitions (most tests):**
These tests don't care about the exact note — they test lifecycle, state machine, feedback, etc. Change to a valid range:
```swift
// BEFORE (crashes with NoteRange):
mockSettings.noteRangeMin = MIDINote(69)
mockSettings.noteRangeMax = MIDINote(69)

// AFTER:
mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
```

**Pattern B — Tests checking the exact note value:**
For tests that assert a specific reference note was generated, widen the range and adjust assertions to check the note is within range rather than exact equality:
```swift
// BEFORE:
mockSettings.noteRangeMin = MIDINote(60)
mockSettings.noteRangeMax = MIDINote(60)
// ...later: #expect(challenge.referenceNote == MIDINote(60))

// AFTER:
mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
// ...later: #expect(mockSettings.noteRange.contains(challenge.referenceNote))
```

**Pattern C — Tests checking interval boundary enforcement:**
PitchMatchingSession's `generateChallenge` shrinks the range for intervals. With a valid range, boundary tests still work:
```swift
// BEFORE (testing up interval doesn't exceed max):
mockSettings.noteRangeMin = MIDINote(60)
mockSettings.noteRangeMax = MIDINote(125)

// AFTER:
mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(125))
// This already has >12 gap, so it works unchanged
```

**Pattern D — ComparisonSession tests that verify TrainingSettings passthrough:**
These tests set mock note range and verify the values arrive in `TrainingSettings`. The assertions check `lastReceivedSettings?.noteRangeMin` which is a `TrainingSettings` property (unchanged in this story):
```swift
// BEFORE:
mockSettings.noteRangeMin = MIDINote(48)
mockSettings.noteRangeMax = MIDINote(72)
// ...later: #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)

// AFTER:
mockSettings.noteRange = NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72))
// Assertion unchanged — TrainingSettings still has noteRangeMin/Max (story 31.3)
```

**Affected test files and approximate counts:**
- `PitchMatchingSessionTests.swift`: ~20 locations (mostly Pattern A, some Pattern B/C)
- `ComparisonSessionSettingsTests.swift`: ~4 locations (Pattern D)
- `ComparisonSessionUserDefaultsTests.swift`: ~4 locations (Pattern D)

### Implementation Guidance

**`UserSettings.swift` — updated protocol:**

```swift
import Foundation

protocol UserSettings {
    var noteRange: NoteRange { get }
    var noteDuration: NoteDuration { get }
    var referencePitch: Frequency { get }
    var soundSource: SoundSourceID { get }
    var varyLoudness: UnitInterval { get }
    var intervals: Set<DirectedInterval> { get }
    var tuningSystem: TuningSystem { get }
}
```

**`AppUserSettings.swift` — updated implementation:**

```swift
var noteRange: NoteRange {
    NoteRange(
        lowerBound: MIDINote(UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMin) as? Int ?? SettingsKeys.defaultNoteRangeMin),
        upperBound: MIDINote(UserDefaults.standard.object(forKey: SettingsKeys.noteRangeMax) as? Int ?? SettingsKeys.defaultNoteRangeMax)
    )
}
```

Remove the old `noteRangeMin` and `noteRangeMax` computed properties.

**`SettingsKeys.swift` — additions:**

```swift
static let defaultNoteRange = NoteRange(
    lowerBound: MIDINote(defaultNoteRangeMin),
    upperBound: MIDINote(defaultNoteRangeMax)
)
```

Update range functions to use `NoteRange.minimumSpan`:

```swift
static func lowerBoundRange(noteRangeMax: Int) -> ClosedRange<Int> {
    absoluteMinNote...(noteRangeMax - NoteRange.minimumSpan)
}

static func upperBoundRange(noteRangeMin: Int) -> ClosedRange<Int> {
    (noteRangeMin + NoteRange.minimumSpan)...absoluteMaxNote
}
```

Remove `minimumNoteGap` — it's now `NoteRange.minimumSpan`.

**`EnvironmentKeys.swift` — PreviewUserSettings update:**

```swift
private final class PreviewUserSettings: UserSettings {
    let noteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
    // ... rest unchanged
}
```

Remove `let noteRangeMin = MIDINote(36)` and `let noteRangeMax = MIDINote(84)`.

**`MockUserSettings.swift` — update:**

```swift
final class MockUserSettings: UserSettings {
    var noteRange: NoteRange = NoteRange(
        lowerBound: MIDINote(SettingsKeys.defaultNoteRangeMin),
        upperBound: MIDINote(SettingsKeys.defaultNoteRangeMax)
    )
    // ... rest unchanged
}
```

Remove `var noteRangeMin` and `var noteRangeMax`.

**`ComparisonSession.swift` — mechanical fix (2 lines):**

```swift
private var currentSettings: TrainingSettings {
    TrainingSettings(
        noteRangeMin: userSettings.noteRange.lowerBound,
        noteRangeMax: userSettings.noteRange.upperBound,
        referencePitch: userSettings.referencePitch
    )
}
```

**`PitchMatchingSession.swift` — mechanical fix (2 lines):**

Same pattern as ComparisonSession.

**`SettingsScreen.swift` — no changes needed:**

The SettingsScreen uses `@AppStorage` with raw Int values bound directly to Steppers. It doesn't go through the `UserSettings` protocol. The validation via `SettingsKeys.lowerBoundRange()`/`upperBoundRange()` is updated in Task 3 to use `NoteRange.minimumSpan` (same value of 12, but now flows from the domain type). The two-stepper UX is unchanged.

### Key Design Decisions

- **`@AppStorage` stays as raw Int** — SwiftUI `@AppStorage` requires primitive types. The two Int keys remain as the canonical storage. `AppUserSettings` constructs `NoteRange` on read. This is the "anti-corruption layer" between storage and domain model.
- **`minimumNoteGap` removed from SettingsKeys** — the single source of truth for the minimum gap is now `NoteRange.minimumSpan = 12`. `SettingsKeys` range functions reference it directly.
- **`defaultNoteRangeMin`/`defaultNoteRangeMax` Int constants remain** — needed by `@AppStorage` default values in `SettingsScreen`. They're the storage-level defaults. `defaultNoteRange` is the domain-level default.
- **Mechanical consumer updates** — ComparisonSession and PitchMatchingSession change from `userSettings.noteRangeMin` to `userSettings.noteRange.lowerBound`. This is intentionally minimal — story 31.3 will change `TrainingSettings` to accept `NoteRange` directly, eliminating the `.lowerBound/.upperBound` decomposition.

### Previous Story Intelligence

**Story 31.1 (Create NoteRange Value Type) — completed:**
- Created `NoteRange` struct in `Peach/Core/Audio/NoteRange.swift`
- `precondition` validates minimum 12-semitone span
- Properties: `lowerBound`, `upperBound`, `contains(_:)`, `clamped(_:)`, `semitoneSpan`
- `minimumSpan = 12` — the constant this story references
- 22 tests in `PeachTests/Core/Audio/NoteRangeTests.swift`
- 820 tests passing at story 31.1 completion
- Build clean, dependency rules pass

**Story 31.1 Dev Notes — key insight:**
- `NoteRange.minimumSpan = 12` matches `SettingsKeys.minimumNoteGap` — defined independently (no dependency). This story unifies them by making `SettingsKeys` reference `NoteRange.minimumSpan` and removing `minimumNoteGap`.

### Git Intelligence

**Recent commits:**
```
e1ef035 Implement story 31.1: Create NoteRange value type
2e6d8a7 Create story 31.1: NoteRange value type
79553b0 Fix epic numbering: insert Epics 25-30, renumber 25-32 -> 31-38
```

**Commit format:** `Implement story 31.2: Adopt NoteRange in UserSettings and Settings Screen`

**Current test count:** 820 tests passing (as of story 31.1 completion).

### Project Structure Notes

- All modified files are in their correct locations per project structure rules
- No new files created — only modifications
- `NoteRange` is in `Core/Audio/` — already accessible from `Settings/` files (same module, no cross-feature coupling)
- `SettingsKeys` referencing `NoteRange.minimumSpan` is acceptable — it's referencing a `Core/Audio/` type from `Settings/`, which is the correct dependency direction (feature depends on core)
- No cross-feature coupling introduced — ComparisonSession and PitchMatchingSession only touch their own `currentSettings` computed property

### Cross-Story Context (Epic 31 Roadmap)

This is story 2 of 4 in Epic 31:
- **31.1 (done):** Created `NoteRange` value type with validation, contains, clamped, semitoneSpan
- **31.2 (this story):** Replace `noteRangeMin`/`noteRangeMax` in `UserSettings` protocol with `noteRange: NoteRange`; update all protocol consumers
- **31.3 (next):** Replace separate min/max in `TrainingSettings`, `ComparisonSession` parameters, `PitchMatchingSession` parameters, `KazezNoteStrategy`
- **31.4:** Adopt in `PerceptualProfile` and `PianoKeyboardView`

**Important for this story:** The mechanical fixes in ComparisonSession/PitchMatchingSession (using `noteRange.lowerBound`/`noteRange.upperBound`) are intentionally intermediate — story 31.3 will clean up `TrainingSettings` to accept `NoteRange` directly.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 31] — Epic definition, story 31.2 acceptance criteria
- [Source: Peach/Core/Audio/NoteRange.swift] — Value type created in story 31.1, `minimumSpan = 12`
- [Source: Peach/Settings/UserSettings.swift] — Protocol to modify: `noteRangeMin`, `noteRangeMax`
- [Source: Peach/Settings/AppUserSettings.swift] — Implementation to modify: UserDefaults reads
- [Source: Peach/Settings/SettingsKeys.swift] — Constants to modify: `minimumNoteGap`, add `defaultNoteRange`
- [Source: Peach/Settings/SettingsScreen.swift] — Uses `@AppStorage` with Int values, Steppers use `SettingsKeys` range functions
- [Source: Peach/App/EnvironmentKeys.swift:75-84] — `PreviewUserSettings` with `noteRangeMin`/`noteRangeMax`
- [Source: Peach/Comparison/ComparisonSession.swift:40-46] — `currentSettings` reads `userSettings.noteRangeMin/Max`
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:195-201] — Same pattern as ComparisonSession
- [Source: PeachTests/Mocks/MockUserSettings.swift] — Mock to update
- [Source: PeachTests/Settings/SettingsTests.swift] — Existing tests for settings
- [Source: docs/project-context.md] — Swift 6.2, precondition pattern, value types, testing rules

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered. All changes compiled and tested on first pass.

### Completion Notes List

- Replaced `noteRangeMin: MIDINote` and `noteRangeMax: MIDINote` with `noteRange: NoteRange` in `UserSettings` protocol
- Updated `AppUserSettings` to construct `NoteRange` from two `UserDefaults` reads (storage keys unchanged)
- Added `defaultNoteRange` to `SettingsKeys`, replaced `minimumNoteGap` with `NoteRange.minimumSpan` in range functions
- Updated all protocol conformers: `MockUserSettings`, `PreviewUserSettings`
- Mechanical fix in `ComparisonSession` and `PitchMatchingSession`: `userSettings.noteRangeMin` → `userSettings.noteRange.lowerBound`
- Migrated ~20 test locations in `PitchMatchingSessionTests` from `noteRangeMin`/`noteRangeMax` to `noteRange` with valid 12-semitone spans
- Migrated ~4 locations each in `ComparisonSessionSettingsTests` and `ComparisonSessionUserDefaultsTests`
- Added 5 new NoteRange integration tests in `SettingsTests`
- Tests: 820 → 826 (6 new), all passing
- SettingsScreen unchanged (uses `@AppStorage` with raw Int, Steppers use updated `SettingsKeys` range functions)

### Change Log

- 2026-03-04: Implemented story 31.2 — replaced separate `noteRangeMin`/`noteRangeMax` in `UserSettings` protocol with single `noteRange: NoteRange`, updated all consumers and tests
- 2026-03-04: Code review — added defensive fallback in `AppUserSettings.noteRange` for corrupted UserDefaults (falls back to `defaultNoteRange` if gap < 12 semitones), +1 test

### File List

**Production files modified:**
- Peach/Settings/UserSettings.swift
- Peach/Settings/AppUserSettings.swift
- Peach/Settings/SettingsKeys.swift
- Peach/App/EnvironmentKeys.swift
- Peach/Comparison/ComparisonSession.swift
- Peach/PitchMatching/PitchMatchingSession.swift

**Test files modified:**
- PeachTests/Mocks/MockUserSettings.swift
- PeachTests/Settings/SettingsTests.swift
- PeachTests/PitchMatching/PitchMatchingSessionTests.swift
- PeachTests/Comparison/ComparisonSessionSettingsTests.swift
- PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift

**Tracking files updated:**
- docs/implementation-artifacts/sprint-status.yaml
- docs/implementation-artifacts/31-2-adopt-noterange-in-usersettings-and-settings-screen.md

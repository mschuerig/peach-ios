# Story 31.4: Adopt NoteRange in Profile and Visualization

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want profile computation and keyboard visualization to use `NoteRange`,
so that range references are consistent domain-wide.

## Acceptance Criteria

1. **Given** `PitchDiscriminationProfile` protocol, **when** `averageThreshold` is called, **then** it accepts `NoteRange` instead of `ClosedRange<Int>`
2. **Given** `PerceptualProfile`, **when** it implements `averageThreshold`, **then** the implementation uses `NoteRange`
3. **Given** `PianoKeyboardLayout`, **when** it receives range parameters, **then** it accepts `NoteRange` instead of `ClosedRange<Int>`
4. **Given** `SummaryStatisticsView`, **when** it receives range parameters and computes stats, **then** it accepts `NoteRange` instead of `ClosedRange<Int>`
5. **Given** `ProfileScreen`, **when** it references the displayed note range, **then** it uses `NoteRange` (via `SettingsKeys.defaultNoteRange`)
6. **Given** any Swift source code outside the `@AppStorage`/`SettingsKeys` storage layer, **when** the codebase is searched for `ClosedRange<Int>` MIDI range parameters, **then** no raw `ClosedRange<Int>` MIDI ranges remain — all are expressed through `NoteRange`
7. **Given** the full test suite, **when** run after all adoptions, **then** all tests pass

## Tasks / Subtasks

- [x] Task 1: Update `PitchDiscriminationProfile` protocol (AC: #1)
  - [x] 1.1 Write failing test: `MockPitchDiscriminationProfile.averageThreshold` accepts `NoteRange` parameter
  - [x] 1.2 Change `averageThreshold(midiRange: ClosedRange<Int>) -> Int?` to `averageThreshold(noteRange: NoteRange) -> Int?` in protocol
  - [x] 1.3 Verify test passes
- [x] Task 2: Update `PerceptualProfile` implementation (AC: #2)
  - [x] 2.1 Update `averageThreshold` method signature to accept `NoteRange`
  - [x] 2.2 Replace internal `midiRange.filter { ... }` with `(noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue).filter { ... }`
  - [x] 2.3 Verify build succeeds
- [x] Task 3: Update `MockPitchDiscriminationProfile` (AC: #1)
  - [x] 3.1 Update `averageThreshold` method signature to accept `NoteRange`
  - [x] 3.2 Verify build succeeds
- [x] Task 4: Update `PianoKeyboardLayout` (AC: #3)
  - [x] 4.1 Write failing test: `PianoKeyboardLayout(noteRange:)` init accepts `NoteRange`
  - [x] 4.2 Change `midiRange: ClosedRange<Int>` property to `noteRange: NoteRange`
  - [x] 4.3 Update all 6 internal references from `midiRange.lowerBound`/`midiRange.upperBound` to `noteRange.lowerBound.rawValue`/`noteRange.upperBound.rawValue`
  - [x] 4.4 Verify build succeeds
- [x] Task 5: Update `SummaryStatisticsView` (AC: #4)
  - [x] 5.1 Write failing test: `SummaryStatisticsView.computeStats(from:noteRange:)` accepts `NoteRange`
  - [x] 5.2 Change `midiRange: ClosedRange<Int>` property to `noteRange: NoteRange`
  - [x] 5.3 Update `init(midiRange:)` to `init(noteRange:)` with default `SettingsKeys.defaultNoteRange`
  - [x] 5.4 Update `computeStats` signature from `midiRange: ClosedRange<Int>` to `noteRange: NoteRange`
  - [x] 5.5 Update internal iteration from `midiRange.filter { ... }` to `(noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue).filter { ... }`
  - [x] 5.6 Verify build succeeds
- [x] Task 6: Update `ProfileScreen` (AC: #5)
  - [x] 6.1 Replace `private let midiRange: ClosedRange<Int> = 36...84` with `private let noteRange = SettingsKeys.defaultNoteRange`
  - [x] 6.2 Update call site: `SummaryStatisticsView(midiRange: midiRange)` to `SummaryStatisticsView(noteRange: noteRange)`
  - [x] 6.3 Verify build succeeds
- [x] Task 7: Update test files (AC: #6, #7)
  - [x] 7.1 Update `ProfileScreenTests.swift`: 2 `PianoKeyboardLayout(midiRange: 36...84)` calls to `PianoKeyboardLayout(noteRange: SettingsKeys.defaultNoteRange)`
  - [x] 7.2 Update `SummaryStatisticsTests.swift`: 5 `computeStats(from:, midiRange: 36...84)` calls to `computeStats(from:, noteRange: SettingsKeys.defaultNoteRange)`
  - [x] 7.3 Verify all tests compile
- [x] Task 8: Run full test suite (AC: #7)
  - [x] 8.1 Run `bin/test.sh` — all tests must pass
  - [x] 8.2 Run `bin/build.sh` — no warnings or errors
  - [x] 8.3 Run `bin/check-dependencies.sh` — no dependency violations

## Dev Notes

### Technical Requirements

**What this story IS:**
- Replace `ClosedRange<Int>` MIDI range parameters with `NoteRange` in the profile and visualization layer
- Update `PitchDiscriminationProfile` protocol's `averageThreshold` method signature
- Update `PerceptualProfile` implementation to match
- Update `PianoKeyboardLayout` to accept `NoteRange` instead of `ClosedRange<Int>`
- Update `SummaryStatisticsView` to accept `NoteRange` instead of `ClosedRange<Int>` (both init and `computeStats`)
- Update `ProfileScreen` to use `SettingsKeys.defaultNoteRange` instead of hardcoded `36...84`
- Update all test files to use `NoteRange` / `SettingsKeys.defaultNoteRange`

**What this story is NOT:**
- No changes to `SettingsKeys.swift` — storage key strings (`"noteRangeMin"`, `"noteRangeMax"`) and raw Int defaults are intentionally preserved as the persistence layer
- No changes to `SettingsScreen.swift` — `@AppStorage` operates at the raw Int level, unaffected
- No changes to `AppUserSettings.swift` — storage reconstruction layer, unaffected
- No changes to `NoteRange.swift` — created in story 31.1, unchanged
- No changes to `TrainingSettings` — already uses `NoteRange` (done in story 31.3)
- No changes to `ComparisonSession` or `PitchMatchingSession` — done in story 31.3
- No changes to `SoundFontNotePlayer.swift` — its internal `0...127` range is for MIDI decomposition, not note range configuration
- No semantic behavior changes — purely mechanical type migration with identical behavior
- No new files — only modifications to existing files
- No localization changes

### Architecture Compliance

**`PitchDiscriminationProfile` protocol change:** This protocol is in `Core/Profile/` and already imports Foundation. `NoteRange` is in `Core/Audio/`. Both are in the `Core/` layer — core-to-core references are valid. No new imports needed (both are within the same module).

**`PianoKeyboardLayout` change:** This struct is in `Peach/Profile/PianoKeyboardView.swift`. It already uses `MIDINote` via `noteName(midiNote:)` calling `MIDINote(midiNote).name`. Switching from `ClosedRange<Int>` to `NoteRange` adds no new imports — `NoteRange` and `MIDINote` are in the same module.

**`SummaryStatisticsView` change:** The `computeStats` method accepts `PitchDiscriminationProfile` protocol and a range. Changing the range parameter from `ClosedRange<Int>` to `NoteRange` is a type-only change. Internal iteration switches from `midiRange.filter { ... }` to `(noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue).filter { ... }` — identical semantics.

**`ProfileScreen` change:** Replaces a hardcoded `ClosedRange<Int>` literal with `SettingsKeys.defaultNoteRange`. `SettingsKeys` is already accessible from Profile code (same module). No new environment dependencies needed.

**`averageThreshold` is dead code:** A comprehensive search confirms no call site for `.averageThreshold(` exists in the entire codebase. The method exists only in the protocol declaration and its two implementations. The signature change is still required for protocol consistency — the protocol should speak the domain language (`NoteRange`), not raw primitives.

**No cross-feature coupling changes:** All modified files are in `Core/Profile/` (protocol and implementation) and `Profile/` (visualization). The `Profile/` feature depends on `Core/` — correct dependency direction.

**Storage layer is exempt:** `SettingsKeys.noteRangeMin`/`noteRangeMax` (String key names), `defaultNoteRangeMin`/`defaultNoteRangeMax` (raw Int defaults), `lowerBoundRange(noteRangeMax:)`/`upperBoundRange(noteRangeMin:)` (range validation functions), `SettingsScreen` `@AppStorage` bindings, and `AppUserSettings` reconstruction code — all intentionally keep raw Int types because they interface with `UserDefaults`/`@AppStorage` which requires primitive types.

### Library & Framework Requirements

**No new dependencies.** This story uses only existing types:
- `NoteRange` — created in story 31.1, located in `Core/Audio/`
- `MIDINote` — existing domain type in `Core/Audio/`
- `SettingsKeys` — existing configuration in `Settings/`
- `Foundation` — standard library

### File Structure Requirements

**0 files created, 5 production files modified, 3 test files modified:**

| File | Action | What Changes |
|------|--------|-------------|
| `Peach/Core/Profile/PitchDiscriminationProfile.swift` | Modify | `averageThreshold(midiRange: ClosedRange<Int>)` -> `averageThreshold(noteRange: NoteRange)` |
| `Peach/Core/Profile/PerceptualProfile.swift` | Modify | `averageThreshold` implementation: signature + internal range iteration |
| `Peach/Profile/PianoKeyboardView.swift` | Modify | `PianoKeyboardLayout.midiRange: ClosedRange<Int>` -> `noteRange: NoteRange`, 6 internal refs |
| `Peach/Profile/SummaryStatisticsView.swift` | Modify | Property, init, and `computeStats` signature: `ClosedRange<Int>` -> `NoteRange` |
| `Peach/Profile/ProfileScreen.swift` | Modify | Replace `midiRange: ClosedRange<Int> = 36...84` with `noteRange = SettingsKeys.defaultNoteRange` |

**Test files to update:**

| File | Action | What Changes |
|------|--------|-------------|
| `PeachTests/Profile/MockPitchDiscriminationProfile.swift` | Modify | `averageThreshold` signature to match protocol |
| `PeachTests/Profile/ProfileScreenTests.swift` | Modify | 2 `PianoKeyboardLayout(midiRange: 36...84)` -> `PianoKeyboardLayout(noteRange: SettingsKeys.defaultNoteRange)` |
| `PeachTests/Profile/SummaryStatisticsTests.swift` | Modify | 5 `computeStats(from:, midiRange: 36...84)` -> `computeStats(from:, noteRange: SettingsKeys.defaultNoteRange)` |

**Do not touch these files:**
- `Peach/Core/Audio/NoteRange.swift` — story 31.1, no changes
- `Peach/Core/Algorithm/NextComparisonStrategy.swift` — story 31.3, already uses `NoteRange`
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` — story 31.3, already uses `NoteRange`
- `Peach/Settings/SettingsKeys.swift` — storage key layer, intentionally raw Int
- `Peach/Settings/SettingsScreen.swift` — `@AppStorage` layer, intentionally raw Int
- `Peach/Settings/AppUserSettings.swift` — storage reconstruction, intentionally raw Int
- `Peach/Settings/UserSettings.swift` — story 31.2, already uses `NoteRange`
- `Peach/Comparison/ComparisonSession.swift` — story 31.3, already uses `NoteRange`
- `Peach/PitchMatching/PitchMatchingSession.swift` — story 31.3, already uses `NoteRange`
- `Peach/Core/Audio/SoundFontNotePlayer.swift` — internal `0...127` is for MIDI decomposition, unrelated
- `PeachTests/Settings/SettingsTests.swift` — tests storage keys and defaults, unaffected
- Any mock/test files from earlier stories already migrated

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — never XCTest.

**All `@Test` functions must be `async`.** No `test` prefix on function names.

**`PitchDiscriminationProfile` protocol change propagation:**

The new method signature:
```swift
func averageThreshold(noteRange: NoteRange) -> Int?
```

Implementors to update:
- `PerceptualProfile` (production)
- `MockPitchDiscriminationProfile` (test mock)

**`PianoKeyboardLayout` init change:**

```swift
// BEFORE:
let layout = PianoKeyboardLayout(midiRange: 36...84)

// AFTER:
let layout = PianoKeyboardLayout(noteRange: SettingsKeys.defaultNoteRange)
```

2 call sites in `ProfileScreenTests.swift`.

**`SummaryStatisticsView.computeStats` change:**

```swift
// BEFORE:
let stats = SummaryStatisticsView.computeStats(from: profile, midiRange: 36...84)

// AFTER:
let stats = SummaryStatisticsView.computeStats(from: profile, noteRange: SettingsKeys.defaultNoteRange)
```

5 call sites in `SummaryStatisticsTests.swift`.

**NoteRange span validation — all test values are safe:**
- `SettingsKeys.defaultNoteRange` = `NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))` = 48 semitones (>= 12)

**Run full suite:** `bin/test.sh` — all existing + new tests must pass before committing.

### Implementation Guidance

**`PitchDiscriminationProfile.swift` — updated protocol method:**

```swift
func averageThreshold(noteRange: NoteRange) -> Int?
```

**`PerceptualProfile.swift` — updated implementation:**

```swift
func averageThreshold(noteRange: NoteRange) -> Int? {
    let trainedNotes = (noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue).filter { statsForNote(MIDINote($0)).isTrained }
    guard !trainedNotes.isEmpty else { return nil }
    let avg = trainedNotes.map { statsForNote(MIDINote($0)).mean }.reduce(0.0, +) / Double(trainedNotes.count)
    return Int(avg)
}
```

**`MockPitchDiscriminationProfile.swift` — updated mock:**

```swift
func averageThreshold(noteRange: NoteRange) -> Int? {
    nil
}
```

**`PianoKeyboardView.swift` — updated `PianoKeyboardLayout`:**

```swift
struct PianoKeyboardLayout {
    let noteRange: NoteRange

    // Internal helper for raw Int range iteration
    private var rawRange: ClosedRange<Int> {
        noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue
    }

    var whiteKeyCount: Int {
        rawRange.filter { Self.isWhiteKey(midiNote: $0) }.count
    }

    func xPosition(forMidiNote midiNote: Int, totalWidth: CGFloat) -> CGFloat {
        let keyWidth = whiteKeyWidth(totalWidth: totalWidth)

        if Self.isWhiteKey(midiNote: midiNote) {
            let whiteIndex = (rawRange.lowerBound..<midiNote).filter { Self.isWhiteKey(midiNote: $0) }.count
            return (CGFloat(whiteIndex) + 0.5) * keyWidth
        } else {
            let prevWhite = (rawRange.lowerBound..<midiNote).reversed().first { Self.isWhiteKey(midiNote: $0) } ?? rawRange.lowerBound
            let nextWhite = ((midiNote + 1)...rawRange.upperBound).first { Self.isWhiteKey(midiNote: $0) } ?? rawRange.upperBound
            let prevX = xPosition(forMidiNote: prevWhite, totalWidth: totalWidth)
            let nextX = xPosition(forMidiNote: nextWhite, totalWidth: totalWidth)
            return (prevX + nextX) / 2.0
        }
    }

    var octaveBoundaries: [(midiNote: Int, name: String)] {
        rawRange
            .filter { Self.isOctaveBoundary(midiNote: $0) }
            .map { (midiNote: $0, name: Self.noteName(midiNote: $0)) }
    }
}
```

Note: The `private var rawRange` computed property avoids repeating `noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue` at every usage site. Static methods (`isWhiteKey`, `noteName`, `isOctaveBoundary`) remain unchanged — they operate on raw `Int` MIDI notes and are independent of the range type.

**`SummaryStatisticsView.swift` — updated property and methods:**

```swift
private let noteRange: NoteRange

init(noteRange: NoteRange = SettingsKeys.defaultNoteRange) {
    self.noteRange = noteRange
}

// body:
let stats = Self.computeStats(from: profile, noteRange: noteRange)

// computeStats:
static func computeStats(from profile: PitchDiscriminationProfile, noteRange: NoteRange) -> Stats? {
    let trainedNotes = (noteRange.lowerBound.rawValue...noteRange.upperBound.rawValue).filter { profile.statsForNote(MIDINote($0)).isTrained }
    // ... rest unchanged
}
```

**`ProfileScreen.swift` — updated range property:**

```swift
private let noteRange = SettingsKeys.defaultNoteRange

// body:
SummaryStatisticsView(noteRange: noteRange)
```

### Previous Story Intelligence

**Story 31.3 (Adopt NoteRange in Training Sessions and Strategy) — completed:**
- `TrainingSettings` now uses `noteRange: NoteRange` (not separate `noteRangeMin`/`noteRangeMax`)
- `KazezNoteStrategy` accesses `settings.noteRange.lowerBound`/`.upperBound`
- `ComparisonSession.currentSettings` and `PitchMatchingSession.currentSettings` pass `noteRange` directly
- `isInRange(_:)` dead code was removed from `TrainingSettings`
- 826 tests passing at story 31.3 completion
- Build clean, dependency rules pass

**Story 31.3 Dev Notes — key insights for this story:**
- Pattern: `.noteRange.lowerBound.rawValue` / `.noteRange.upperBound.rawValue` for raw Int access
- `NoteRange.contains(_:)` replaces ad-hoc range-check methods
- "Purely mechanical refactoring — all changes compiled and passed on first attempt"
- `bin/check-dependencies.sh` must pass unchanged — no new imports introduced

**Story 31.2 (Adopt NoteRange in UserSettings and Settings Screen) — completed:**
- `UserSettings` protocol exposes `noteRange: NoteRange`
- `AppUserSettings` constructs `NoteRange` from two `@AppStorage` Int values with defensive fallback
- `SettingsKeys.defaultNoteRange` was introduced as the canonical default range
- `@AppStorage` keys intentionally remain raw Int — this is the storage boundary

**Story 31.1 (Create NoteRange Value Type) — completed:**
- `NoteRange` struct in `Peach/Core/Audio/NoteRange.swift`
- `precondition` validates minimum 12-semitone span
- Properties: `lowerBound`, `upperBound`, `contains(_:)`, `clamped(_:)`, `semitoneSpan`
- `minimumSpan = 12`
- Conforms to `Equatable`, `Sendable`, `Hashable`

### Git Intelligence

**Recent commits:**
```
671eddf Review story 31.3: Fix stale test description referencing removed noteRangeMin/noteRangeMax API
c92dfbe Implement story 31.3: Adopt NoteRange in Training Sessions and Strategy
5729404 Create story 31.3: Adopt NoteRange in Training Sessions and Strategy
3170a45 Review story 31.2: Add defensive fallback for corrupted UserDefaults in AppUserSettings.noteRange
f2b6804 Implement story 31.2: Adopt NoteRange in UserSettings and Settings Screen
```

**Commit format:** `Implement story 31.4: Adopt NoteRange in Profile and Visualization`

**Current test count:** 826 tests passing (as of story 31.3 completion).

### Project Structure Notes

- All modified files are in their correct locations per project structure rules
- No new files created — only modifications
- `NoteRange` is in `Core/Audio/`, accessible from `Core/Profile/` (core-to-core, same module)
- `SettingsKeys` is in `Settings/`, accessible from `Profile/` (same module, no cross-feature coupling)
- `Profile/` depends on `Core/` — correct dependency direction
- `bin/check-dependencies.sh` should pass unchanged — no new imports introduced

### Cross-Story Context (Epic 31 Roadmap)

This is story 4 of 4 in Epic 31 — the **final story**:
- **31.1 (done):** Created `NoteRange` value type with validation, contains, clamped, semitoneSpan
- **31.2 (done):** Replaced `noteRangeMin`/`noteRangeMax` in `UserSettings` protocol with `noteRange: NoteRange`; updated settings layer consumers
- **31.3 (done):** Replaced separate min/max in `TrainingSettings`; updated `KazezNoteStrategy`, `ComparisonSession`, `PitchMatchingSession`; removed `isInRange(_:)` dead code
- **31.4 (this story):** Adopt `NoteRange` in `PitchDiscriminationProfile`, `PerceptualProfile`, `PianoKeyboardLayout`, `SummaryStatisticsView`, `ProfileScreen`

**After this story:** The `NoteRange` refactoring is complete. The only remaining `noteRangeMin`/`noteRangeMax` references will be in the `@AppStorage`/`SettingsKeys`/`AppUserSettings` storage layer, which intentionally keeps raw Int types for `UserDefaults` compatibility. All domain-level code will express note ranges through the validated `NoteRange` type.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 31] — Epic definition, story 31.4 acceptance criteria
- [Source: Peach/Core/Audio/NoteRange.swift] — Value type created in story 31.1, `minimumSpan = 12`, `contains(_:)`, `clamped(_:)`
- [Source: Peach/Core/Profile/PitchDiscriminationProfile.swift:7] — `averageThreshold(midiRange: ClosedRange<Int>) -> Int?` protocol method
- [Source: Peach/Core/Profile/PerceptualProfile.swift:90-95] — `averageThreshold` implementation with `ClosedRange<Int>` parameter
- [Source: Peach/Profile/PianoKeyboardView.swift:6] — `PianoKeyboardLayout.midiRange: ClosedRange<Int>` property
- [Source: Peach/Profile/PianoKeyboardView.swift:30,45,50-51,61] — 6 internal references to `midiRange.lowerBound`/`midiRange.upperBound`
- [Source: Peach/Profile/SummaryStatisticsView.swift:9,11,86] — `midiRange: ClosedRange<Int>` property, init, and `computeStats` signature
- [Source: Peach/Profile/ProfileScreen.swift:7] — Hardcoded `midiRange: ClosedRange<Int> = 36...84`
- [Source: Peach/Profile/ProfileScreen.swift:16] — `SummaryStatisticsView(midiRange: midiRange)` call site
- [Source: PeachTests/Profile/MockPitchDiscriminationProfile.swift:29] — Mock `averageThreshold` implementation
- [Source: PeachTests/Profile/ProfileScreenTests.swift:45,60] — 2 `PianoKeyboardLayout(midiRange: 36...84)` call sites
- [Source: PeachTests/Profile/SummaryStatisticsTests.swift:17,32,46,56,71] — 5 `computeStats(from:, midiRange: 36...84)` call sites
- [Source: Peach/Settings/SettingsKeys.swift:27-30] — `defaultNoteRange` static property
- [Source: docs/implementation-artifacts/31-3-adopt-noterange-in-training-sessions-and-strategy.md] — Previous story with learnings
- [Source: docs/project-context.md] — Swift 6.2, precondition pattern, value types, testing rules

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered — purely mechanical type migration compiled and passed on first attempt.

### Completion Notes List

- Replaced `ClosedRange<Int>` MIDI range parameters with `NoteRange` across the profile and visualization layer
- `PitchDiscriminationProfile.averageThreshold(midiRange:)` → `averageThreshold(noteRange:)` — protocol, production impl, and mock all updated
- `PianoKeyboardLayout.midiRange` → `noteRange: NoteRange` with `private var rawRange` computed property to avoid repetitive `.lowerBound.rawValue...upperBound.rawValue` expressions
- `SummaryStatisticsView` — property, init, body call site, and `computeStats` all migrated from `ClosedRange<Int>` to `NoteRange`
- `ProfileScreen` — replaced hardcoded `36...84` with `SettingsKeys.defaultNoteRange`
- All 826 tests pass, build clean, dependency rules pass
- This completes Epic 31 — all domain-level note range references now use `NoteRange`

### Change Log

- 2026-03-04: Implemented story 31.4 — adopted NoteRange in profile and visualization layer (5 production files, 3 test files modified)

### File List

- Peach/Core/Profile/PitchDiscriminationProfile.swift (modified)
- Peach/Core/Profile/PerceptualProfile.swift (modified)
- Peach/Profile/PianoKeyboardView.swift (modified)
- Peach/Profile/SummaryStatisticsView.swift (modified)
- Peach/Profile/ProfileScreen.swift (modified)
- PeachTests/Profile/MockPitchDiscriminationProfile.swift (modified)
- PeachTests/Profile/ProfileScreenTests.swift (modified)
- PeachTests/Profile/SummaryStatisticsTests.swift (modified)

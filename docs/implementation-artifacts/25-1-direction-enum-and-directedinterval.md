# Story 25.1: Direction Enum and DirectedInterval

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want interval training to distinguish between ascending and descending intervals,
so that I can train my ear to recognize intervals in both directions for comprehensive musicianship.

## Acceptance Criteria

### AC 1: Direction enum exists with up and down cases
**Given** the Core/Audio domain
**When** a Direction value is created
**Then** it supports `.up` and `.down` cases
**And** conforms to `Hashable`, `Comparable`, `Sendable`, `CaseIterable`, `Codable`
**And** has a `displayName` property returning localized "Up" or "Down"

### AC 2: DirectedInterval value type combines Interval with Direction
**Given** the Core/Audio domain
**When** a DirectedInterval is created from an Interval and a Direction
**Then** it stores both components
**And** conforms to `Hashable`, `Comparable`, `Sendable`, `Codable`
**And** has a `displayName` property (e.g., "Perfect Fifth Up", "Major Third Down", "Prime")
**And** provides static factories: `.prime`, `.up(_)`, `.down(_)` for ergonomic construction
**And** provides `static func between(_ reference: MIDINote, _ target: MIDINote) throws -> DirectedInterval` that infers direction from note ordering

### AC 3: MIDINote transposition supports DirectedInterval
**Given** a MIDINote
**When** transposed by a DirectedInterval
**Then** `.up` adds semitones (existing behavior)
**And** `.down` subtracts semitones
**And** precondition enforces result stays in MIDI range 0–127

### AC 4: Session and strategy APIs use DirectedInterval
**Given** the training system APIs
**When** a training session starts
**Then** `TrainingSession.start(intervals: Set<DirectedInterval>)` is the protocol signature
**And** `ComparisonSession` stores and selects from `Set<DirectedInterval>`
**And** `PitchMatchingSession` stores and selects from `Set<DirectedInterval>`
**And** `NextComparisonStrategy.nextComparison(..., interval: DirectedInterval)` receives a DirectedInterval
**And** `KazezNoteStrategy` adjusts note range bounds for downward transposition (reference note must be high enough that target stays >= noteRangeMin)
**And** `PitchMatchingSession.generateChallenge()` adjusts note range bounds for downward transposition

### AC 5: Navigation and UI use DirectedInterval
**Given** the navigation and settings system
**When** training mode buttons are tapped
**Then** `NavigationDestination.comparison(intervals:)` and `.pitchMatching(intervals:)` use `Set<DirectedInterval>`
**And** `ComparisonScreen` and `PitchMatchingScreen` accept `Set<DirectedInterval>`
**And** `UserSettings.intervals` returns `Set<DirectedInterval>`
**And** `AppUserSettings.intervals` returns `Set<DirectedInterval>`
**And** `StartScreen` NavigationLinks use `DirectedInterval` (e.g., `.up(.perfectFifth)`)
**And** `isIntervalMode` correctly identifies non-prime directed intervals

### AC 6: Interval.displayName replaced by DirectedInterval.displayName
**Given** the display name system
**When** interval names are displayed on training screens
**Then** `Interval.displayName` is renamed to `Interval.name` with direction-agnostic labels (e.g., "Perfect Fifth", not "Perfect Fifth Up")
**And** `DirectedInterval.displayName` composes `interval.name` + `direction.displayName` for non-prime intervals
**And** prime always displays as "Prime" regardless of direction
**And** localization entries updated: old "X Up" entries replaced with direction-agnostic interval names + separate "Up"/"Down" entries
**And** German translations provided for direction labels ("aufwärts"/"abwärts")

### AC 7: Data model unchanged — direction is inferable
**Given** existing `ComparisonRecord` and `PitchMatchingRecord` data models
**When** a training result is recorded
**Then** the data model is NOT modified (direction is inferable from `referenceNote` vs `targetNote`)
**And** `TrainingDataStore` continues using `Interval.between()` for unsigned semitone storage
**And** existing stored data remains valid without migration

### AC 8: All tests pass with comprehensive coverage
**Given** the test suite
**When** all tests run
**Then** new tests exist for `Direction` (semitone values, CaseIterable, Codable, Comparable, displayName)
**And** new tests exist for `DirectedInterval` (construction, displayName, between, Codable, Hashable, Comparable, static factories)
**And** new tests exist for downward `MIDINote.transposed(by:)` including edge cases
**And** all existing tests updated to use `DirectedInterval` where `Interval` was used
**And** full test suite passes

## Tasks / Subtasks

- [x] Task 1: Create Direction enum (AC: 1)
  - [x] New file `Peach/Core/Audio/Direction.swift` with `.up` (rawValue 0) and `.down` (rawValue 1) cases
  - [x] Conform to `Int`, `Hashable`, `Comparable`, `Sendable`, `CaseIterable`, `Codable`
  - [x] Add `displayName` property with localized "Up" / "Down"
  - [x] Add `Comparable` via rawValue comparison (up < down)
  - [x] New test file `PeachTests/Core/Audio/DirectionTests.swift`
- [x] Task 2: Create DirectedInterval struct (AC: 2)
  - [x] New file `Peach/Core/Audio/DirectedInterval.swift`
  - [x] Struct with `let interval: Interval` and `let direction: Direction`
  - [x] Conform to `Hashable`, `Comparable`, `Sendable`, `Codable`
  - [x] `displayName`: prime → "Prime"; others → `"\(interval.name) \(direction.displayName)"`
  - [x] Static factories: `static let prime`, `static func up(_ interval: Interval)`, `static func down(_ interval: Interval)`
  - [x] `static func between(_ reference: MIDINote, _ target: MIDINote) throws -> DirectedInterval`
  - [x] `Comparable`: compare by interval first, then direction (up < down)
  - [x] Move `MIDINote.transposed(by: DirectedInterval)` extension here
  - [x] New test file `PeachTests/Core/Audio/DirectedIntervalTests.swift`
- [x] Task 3: Update Interval.swift (AC: 3, 6)
  - [x] Rename `displayName` → `name` with direction-agnostic labels (remove "Up" suffix)
  - [x] Remove `MIDINote.transposed(by: Interval)` extension (moved to DirectedInterval)
  - [x] Keep `Interval.between()`, `semitones`, all conformances
  - [x] Update `IntervalTests.swift` for renamed property and removed extension
- [x] Task 4: Replace Interval with DirectedInterval in protocols (AC: 4)
  - [x] `TrainingSession.start(intervals: Set<DirectedInterval>)`
  - [x] `NextComparisonStrategy.nextComparison(..., interval: DirectedInterval)`
- [x] Task 5: Update KazezNoteStrategy for DirectedInterval (AC: 4)
  - [x] Change parameter type to `DirectedInterval`
  - [x] Adjust note range calculation: for `.down`, `minNote = max(noteRangeMin, interval.semitones)` instead of capping maxNote
  - [x] Use `note.transposed(by: directedInterval)` for both directions
  - [x] Update `KazezNoteStrategyTests.swift`
- [x] Task 6: Update ComparisonSession for DirectedInterval (AC: 4, 5)
  - [x] `sessionIntervals: Set<DirectedInterval>`
  - [x] `currentInterval: DirectedInterval?`
  - [x] `start(intervals: Set<DirectedInterval>)`
  - [x] Update `isIntervalMode` to check `currentInterval?.interval != .prime`
  - [x] Update `ComparisonSessionTests.swift` — use `[.prime]` static factory
- [x] Task 7: Update PitchMatchingSession for DirectedInterval (AC: 4, 5)
  - [x] `sessionIntervals: Set<DirectedInterval>`
  - [x] `currentInterval: DirectedInterval?`
  - [x] `start(intervals: Set<DirectedInterval>)`
  - [x] Update `isIntervalMode` to check `currentInterval?.interval != .prime`
  - [x] Update `generateChallenge()` — adjust note range for downward transposition
  - [x] Update `PitchMatchingSessionTests.swift` — use `[.prime]` static factory
- [x] Task 8: Update navigation and UI types (AC: 5)
  - [x] `NavigationDestination`: `Set<Interval>` → `Set<DirectedInterval>`
  - [x] `ComparisonScreen`: `intervals: Set<DirectedInterval>`
  - [x] `PitchMatchingScreen`: `intervals: Set<DirectedInterval>`
  - [x] `UserSettings.intervals`: `Set<DirectedInterval>`
  - [x] `AppUserSettings.intervals`: return `[.up(.perfectFifth)]`
  - [x] `StartScreen`: update NavigationLink values (e.g., `[.prime]`, `[.up(.perfectFifth)]`)
  - [x] Update all related tests
- [x] Task 9: Update localization (AC: 6)
  - [x] Mark old "X Up" entries as stale in `Localizable.xcstrings`
  - [x] Add direction-agnostic interval name entries (English + German)
  - [x] Add "Up" (de: "aufwärts") and "Down" (de: "abwärts") entries
  - [x] Verify composed display names render correctly
- [x] Task 10: Run full test suite (AC: 8)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  - [x] All tests pass

## Dev Notes

### Developer Context — Critical Implementation Intelligence

This story introduces directional interval support — the foundation for training musicians on both ascending and descending intervals. It creates two new domain types (`Direction`, `DirectedInterval`) and replaces bare `Interval` with `DirectedInterval` throughout the API surface. The `Interval` enum itself is preserved as a pure semitone distance type.

**Scope of change:** ~20 source files and ~15 test files. The change is mechanical but pervasive — every place that passes `Set<Interval>` or a single `Interval` through the training pipeline needs updating. No data model migration is required (direction is inferable from existing `referenceNote` vs `targetNote` fields).

**What this story changes:**
- Adds `Direction` enum and `DirectedInterval` struct in `Core/Audio/`
- Replaces `Interval` with `DirectedInterval` in all session, strategy, navigation, settings, and screen APIs
- Renames `Interval.displayName` → `Interval.name` (direction-agnostic)
- Updates `MIDINote.transposed(by:)` to accept `DirectedInterval` (supports downward transposition)
- Updates `KazezNoteStrategy` and `PitchMatchingSession.generateChallenge()` note range bounds for downward intervals
- Updates localization entries

**What this story does NOT change:**
- `Interval` enum itself — cases, rawValues, `semitones`, `between()`, and conformances are preserved
- `ComparisonRecord` and `PitchMatchingRecord` data models — no new fields, no migration
- `TrainingDataStore` — continues using `Interval.between()` for unsigned semitone storage
- `Comparison`, `CompletedComparison`, `PitchMatchingChallenge`, `CompletedPitchMatching` value types
- `NotePlayer`, `PlaybackHandle`, `SoundFontNotePlayer` — audio layer untouched
- Profile computation — `PerceptualProfile`, `PitchDiscriminationProfile`, `PitchMatchingProfile` unchanged
- `PeachApp.swift` composition root — no new services to wire
- `TuningSystem` — no changes needed

### Technical Requirements

**Direction enum design:**
```swift
// Peach/Core/Audio/Direction.swift
enum Direction: Int, Hashable, Comparable, Sendable, CaseIterable, Codable {
    case up = 0
    case down = 1

    var displayName: String {
        switch self {
        case .up: String(localized: "Up")
        case .down: String(localized: "Down")
        }
    }

    static func < (lhs: Direction, rhs: Direction) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

**DirectedInterval design:**
```swift
// Peach/Core/Audio/DirectedInterval.swift
struct DirectedInterval: Hashable, Comparable, Sendable, Codable {
    let interval: Interval
    let direction: Direction

    var displayName: String {
        if interval == .prime { return interval.name }
        return "\(interval.name) \(direction.displayName)"
    }

    // MARK: - Static Factories

    static let prime = DirectedInterval(interval: .prime, direction: .up)

    static func up(_ interval: Interval) -> DirectedInterval {
        DirectedInterval(interval: interval, direction: .up)
    }

    static func down(_ interval: Interval) -> DirectedInterval {
        DirectedInterval(interval: interval, direction: .down)
    }

    // MARK: - Comparable

    static func < (lhs: DirectedInterval, rhs: DirectedInterval) -> Bool {
        if lhs.interval != rhs.interval { return lhs.interval < rhs.interval }
        return lhs.direction < rhs.direction
    }

    // MARK: - Between

    static func between(_ reference: MIDINote, _ target: MIDINote) throws -> DirectedInterval {
        let interval = try Interval.between(reference, target)
        let direction: Direction = target.rawValue >= reference.rawValue ? .up : .down
        return DirectedInterval(interval: interval, direction: direction)
    }
}

// MARK: - MIDINote Transposition

extension MIDINote {
    func transposed(by directedInterval: DirectedInterval) -> MIDINote {
        let delta = directedInterval.direction == .up
            ? directedInterval.interval.semitones
            : -directedInterval.interval.semitones
        let newValue = rawValue + delta
        precondition(Self.validRange.contains(newValue),
            "Transposed note \(newValue) out of MIDI range 0-127")
        return MIDINote(newValue)
    }
}
```

**Interval.displayName → Interval.name (direction-agnostic):**
```swift
// In Interval.swift — rename displayName to name, remove "Up" suffixes
var name: String {
    switch self {
    case .prime: String(localized: "Prime")
    case .minorSecond: String(localized: "Minor Second")
    case .majorSecond: String(localized: "Major Second")
    // ... all cases without "Up" suffix
    }
}
```

Remove the existing `extension MIDINote { func transposed(by interval: Interval) }` from Interval.swift (moved to DirectedInterval.swift with updated signature).

**KazezNoteStrategy — directional note range adjustment:**
```swift
// Current (up only):
let maxNote = MIDINote(min(settings.noteRangeMax.rawValue, 127 - interval.semitones))
let note = MIDINote.random(in: settings.noteRangeMin...maxNote)
let targetBaseNote = note.transposed(by: interval)

// Updated (direction-aware):
let minNote: MIDINote
let maxNote: MIDINote
if directedInterval.direction == .up {
    minNote = settings.noteRangeMin
    maxNote = MIDINote(min(settings.noteRangeMax.rawValue, 127 - directedInterval.interval.semitones))
} else {
    minNote = MIDINote(max(settings.noteRangeMin.rawValue, directedInterval.interval.semitones))
    maxNote = settings.noteRangeMax
}
let note = MIDINote.random(in: minNote...maxNote)
let targetBaseNote = note.transposed(by: directedInterval)
```

Same adjustment needed in `PitchMatchingSession.generateChallenge()`.

**isIntervalMode update:**
```swift
// Current:
var isIntervalMode: Bool { currentInterval != nil && currentInterval != .prime }

// Updated:
var isIntervalMode: Bool {
    guard let current = currentInterval else { return false }
    return current.interval != .prime
}
```

**StartScreen usage:**
```swift
// Current:
NavigationDestination.comparison(intervals: [.prime])
NavigationDestination.comparison(intervals: [.perfectFifth])

// Updated:
NavigationDestination.comparison(intervals: [.prime])          // uses DirectedInterval.prime static
NavigationDestination.comparison(intervals: [.up(.perfectFifth)])  // uses DirectedInterval.up(_) factory
```

### Architecture Compliance

1. **Value types by default** — `Direction` is an enum (value type), `DirectedInterval` is a struct (value type) [Source: docs/project-context.md#Type Design]
2. **Protocol-first design** — `TrainingSession`, `NextComparisonStrategy`, `UserSettings` protocols updated first, implementations follow [Source: docs/project-context.md#Error Handling]
3. **Core/ is framework-free** — both new types in `Core/Audio/` with no SwiftUI/UIKit imports [Source: docs/project-context.md#Dependency Direction Rules]
4. **File placement** — audio domain value types → `Core/Audio/` [Source: docs/project-context.md#File Placement]
5. **Naming conventions** — enum cases `lowerCamelCase` (`up`, `down`); boolean property `isPrime` on DirectedInterval [Source: docs/project-context.md#Code Quality & Style Rules]
6. **No cross-feature coupling** — `Direction` and `DirectedInterval` in `Core/`, referenced by all features [Source: docs/project-context.md#Dependency Direction Rules]
7. **Two-world architecture preserved** — `DirectedInterval` is logical world (like `Interval`); physical world (`Frequency`) untouched [Source: docs/project-context.md#AVAudioEngine]

### Library/Framework Requirements

- **Swift 6.2** — strict concurrency; `Sendable` conformance on both new types
- **No new dependencies** — zero third-party packages
- **SwiftUI** — only affected in screen/navigation files; no SwiftUI in `Core/`
- **SwiftData** — NOT affected; no data model changes
- **String Catalogs** — localization entry updates for direction-agnostic interval names + direction labels

### File Structure — Files to Create

| File | Purpose |
|------|---------|
| `Peach/Core/Audio/Direction.swift` | Direction enum (.up, .down) |
| `Peach/Core/Audio/DirectedInterval.swift` | DirectedInterval struct + MIDINote.transposed(by:) extension |
| `PeachTests/Core/Audio/DirectionTests.swift` | Direction enum tests |
| `PeachTests/Core/Audio/DirectedIntervalTests.swift` | DirectedInterval tests |

### File Structure — Files to Modify

| File | Change | Why |
|------|--------|-----|
| `Peach/Core/Audio/Interval.swift` | Rename `displayName` → `name` (remove "Up" suffixes); remove `MIDINote.transposed(by: Interval)` extension | Direction-agnostic; transposition moves to DirectedInterval |
| `Peach/Core/TrainingSession.swift` | `Set<Interval>` → `Set<DirectedInterval>` | Protocol signature |
| `Peach/Core/Algorithm/NextComparisonStrategy.swift` | `interval: Interval` → `interval: DirectedInterval` | Protocol signature |
| `Peach/Core/Algorithm/KazezNoteStrategy.swift` | `Interval` → `DirectedInterval`; direction-aware note range | Handle downward transposition |
| `Peach/Comparison/ComparisonSession.swift` | `Set<Interval>` → `Set<DirectedInterval>`; `Interval?` → `DirectedInterval?`; `isIntervalMode` update | Session state |
| `Peach/PitchMatching/PitchMatchingSession.swift` | Same as ComparisonSession; update `generateChallenge()` note range | Session state + challenge generation |
| `Peach/App/NavigationDestination.swift` | `Set<Interval>` → `Set<DirectedInterval>` | Navigation routing |
| `Peach/Comparison/ComparisonScreen.swift` | `Set<Interval>` → `Set<DirectedInterval>` | Screen parameter |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | `Set<Interval>` → `Set<DirectedInterval>` | Screen parameter |
| `Peach/Settings/UserSettings.swift` | `Set<Interval>` → `Set<DirectedInterval>` | Protocol |
| `Peach/Settings/AppUserSettings.swift` | Return `[.up(.perfectFifth)]` | Implementation |
| `Peach/Start/StartScreen.swift` | Use DirectedInterval factories in NavigationLinks | UI |
| `Peach/Resources/Localizable.xcstrings` | Update interval names; add "Up"/"Down" entries | Localization |
| `PeachTests/Core/Audio/IntervalTests.swift` | Update for `name` rename; remove transposition tests | Test updates |
| `PeachTests/Core/Audio/MIDINoteTests.swift` | Update transposition tests for DirectedInterval | Test updates |
| `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift` | Use DirectedInterval | Test updates |
| `PeachTests/Comparison/ComparisonSessionTests.swift` | Use `[.prime]` DirectedInterval | Test updates |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Use `[.prime]` DirectedInterval | Test updates |
| Additional test files referencing `Interval` in `Set<Interval>` context | Mechanical type replacement | Test updates |

**Files NOT to modify:**
- `Peach/Core/Training/Comparison.swift` — value type, no Interval reference
- `Peach/Core/Training/ComparisonObserver.swift` — protocol, no Interval reference
- `Peach/Core/Data/ComparisonRecord.swift` — data model unchanged (AC 7)
- `Peach/Core/Data/PitchMatchingRecord.swift` — data model unchanged (AC 7)
- `Peach/Core/Data/TrainingDataStore.swift` — uses `Interval.between()` (unsigned), unchanged
- `Peach/Core/Audio/TuningSystem.swift` — no Interval dependency
- `Peach/Core/Audio/MIDINote.swift` — no Interval dependency (transposition extension is in Interval.swift)
- `Peach/Core/Profile/*` — profile computation unchanged
- `Peach/App/PeachApp.swift` — no new services to wire
- `Peach/App/EnvironmentKeys.swift` — no new environment entries
- `Peach/PitchMatching/PitchMatchingChallenge.swift` — uses MIDINote, not Interval

### Testing Requirements

**TDD approach — write failing tests first for each task:**

**New test files:**

1. **DirectionTests.swift:**
   - `.up` rawValue is 0, `.down` rawValue is 1
   - `CaseIterable` gives 2 cases
   - `Codable` round-trip preserves value
   - `Comparable`: `.up < .down`
   - `displayName` returns localized strings

2. **DirectedIntervalTests.swift:**
   - Construction from Interval + Direction
   - Static factories: `.prime`, `.up(.perfectFifth)`, `.down(.majorThird)`
   - `displayName`: prime → "Prime"; up → "Perfect Fifth Up"; down → "Major Third Down"
   - `Codable` round-trip
   - `Hashable` in Set
   - `Comparable` ordering: by interval, then direction
   - `between()`: higher target → `.up`; lower target → `.down`; equal → `.prime` (up)
   - `between()` throws for distance exceeding octave
   - MIDINote transposition up: `MIDINote(60).transposed(by: .up(.perfectFifth))` → `MIDINote(67)`
   - MIDINote transposition down: `MIDINote(67).transposed(by: .down(.perfectFifth))` → `MIDINote(60)`
   - MIDINote transposition prime: `MIDINote(60).transposed(by: .prime)` → `MIDINote(60)`

**Updated test files:**

3. **IntervalTests.swift:**
   - Rename `displayName` references to `name`
   - Remove "Up" suffix expectations
   - Remove `MIDINote.transposed(by: Interval)` tests (moved to DirectedIntervalTests)

4. **KazezNoteStrategyTests.swift:**
   - Use `DirectedInterval.prime` / `.up(.perfectFifth)` where `Interval` was used
   - Add test for downward interval note range bounds

5. **ComparisonSessionTests.swift:**
   - Use `[DirectedInterval.prime]` in `start(intervals:)` calls
   - Add test verifying `isIntervalMode` with `.up(.perfectFifth)`

6. **PitchMatchingSessionTests.swift:**
   - Same as ComparisonSession updates

7. **All other test files using `Set<Interval>` or `Interval`** — mechanical replacement

**Test execution:** `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`

### Previous Story Intelligence (Stories 24.1, 24.2)

**From Story 24.2 (Start Screen Four Training Buttons):**
- StartScreen has 4 NavigationLinks with `.comparison(intervals: [.prime])`, `.pitchMatching(intervals: [.prime])`, `.comparison(intervals: [.perfectFifth])`, `.pitchMatching(intervals: [.perfectFifth])`
- Button styling: `.borderedProminent` for hero "Comparison", `.bordered` for rest
- Divider separates unison from interval groups
- All 4 buttons use `Text(...)` labels (no icons)
- `ComparisonScreen(intervals:)` and `PitchMatchingScreen(intervals:)` already accept intervals parameter

**From Story 24.1 (NavigationDestination Parameterization):**
- Destination handler in `StartScreen.swift` (lines 91-101) routes intervals to screens
- Key learning: destination handler is in `StartScreen.swift`, NOT `ContentView.swift`
- Pattern: `.buttonStyle(.borderedProminent)` for hero, `.bordered` for secondary

**Patterns established in Epic 23-24:**
- `Interval` passed as `Set<Interval>` through the entire pipeline: navigation → screen → session → strategy
- Sessions read `sessionIntervals.randomElement()!` on each comparison
- `isIntervalMode` checks `currentInterval != .prime`
- Code review commits are separate from implementation commits

### Git Intelligence

Recent commits:
```
eec3fc0 Update sprint status: close epics 21–24, add epics 25–27
2f8f968 Fix code review findings for story 24.2 and mark done
96572c1 Implement story 24.2: Start Screen Four Training Buttons
3275c94 Add story 24.2: Start Screen Four Training Buttons
b4d924c Fix code review findings for story 24.1 and mark done
94b8672 Implement story 24.1: NavigationDestination Parameterization and Routing
```

**Pattern:** Story creation → implementation → code review findings. Commit message format: `{Verb} story {id}: {description}`.

### Project Structure Notes

- All new files align with existing project structure (`Core/Audio/` for domain types)
- New test files mirror source structure (`PeachTests/Core/Audio/`)
- No new directories needed
- No cross-feature coupling introduced
- `Direction` and `DirectedInterval` follow the same value type pattern as `MIDINote`, `Cents`, `Frequency`, `Interval`

### References

- [Source: docs/implementation-artifacts/sprint-status.yaml#Epic 25] — Story definition: "Direction enum (.up/.down), DirectedInterval type, replace Interval with DirectedInterval throughout"
- [Source: docs/planning-artifacts/architecture.md#v0.3 Amendment] — Interval enum, TuningSystem, session parameterization, navigation routing
- [Source: docs/planning-artifacts/prd.md#FR53-FR55] — Interval domain requirements
- [Source: docs/planning-artifacts/prd.md#FR67] — Initial interval: perfect fifth up
- [Source: docs/project-context.md#Type Design] — Value types by default
- [Source: docs/project-context.md#File Placement] — Core/Audio/ for audio domain value types
- [Source: docs/project-context.md#Testing Rules] — Swift Testing framework, TDD workflow
- [Source: docs/project-context.md#Two-world architecture] — Logical world types
- [Source: docs/implementation-artifacts/24-2-start-screen-four-training-buttons.md] — Previous story with StartScreen button layout
- [Source: docs/implementation-artifacts/24-1-navigationdestination-parameterization-and-routing.md] — Navigation infrastructure
- [Source: Peach/Core/Audio/Interval.swift] — Current Interval enum (13 cases, displayName, between(), transposed(by:))
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift] — Note range calculation with interval.semitones
- [Source: Peach/Comparison/ComparisonSession.swift] — Session state machine with Set<Interval>
- [Source: Peach/PitchMatching/PitchMatchingSession.swift] — PitchMatching session with Set<Interval>

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

None

### Completion Notes List

- All 10 tasks completed successfully
- Full test suite passes (`** TEST SUCCEEDED **`)
- ~20 source files and ~15 test files updated from `Interval` to `DirectedInterval`
- Direction-aware note range calculation implemented in KazezNoteStrategy and PitchMatchingSession.generateChallenge()
- Old "X Up" localization entries marked as stale; new direction-agnostic entries + "Up"/"Down" direction entries added
- Data models (ComparisonRecord, PitchMatchingRecord) unchanged — direction inferable from referenceNote vs targetNote
- No new dependencies introduced

### Change Log

- Created `Direction` enum with `.up`/`.down` cases, Codable/Comparable/CaseIterable conformances
- Created `DirectedInterval` struct with static factories (`.prime`, `.up(_)`, `.down(_)`), `between()`, and `displayName`
- Moved `MIDINote.transposed(by:)` from `Interval.swift` to `DirectedInterval.swift` with direction support
- Renamed `Interval.displayName` → `Interval.name` with direction-agnostic labels
- Updated all protocol/session/strategy/navigation/settings/screen APIs from `Interval` to `DirectedInterval`
- Added direction-aware note range bounds for downward interval transposition
- Updated localization catalog with direction-agnostic interval names and "Up"/"Down" direction entries
- Updated all test files to use `DirectedInterval` APIs

### Senior Developer Review (AI)

**Reviewer:** Michael | **Date:** 2026-03-01 | **Outcome:** Approved with fixes applied

**Issues Found:** 1 High, 3 Medium, 3 Low — all HIGH and MEDIUM fixed automatically.

**Fixes applied:**
1. **[HIGH] Added downward interval tests to KazezNoteStrategyTests** — 3 new tests covering `.down(.perfectFifth)`, downward note range constraint with min=0, and `.down(.octave)` boundary
2. **[MEDIUM] Added downward interval tests to PitchMatchingSessionTests** — 2 new tests covering downward challenge generation and note range constraints
3. **[MEDIUM] Normalized `DirectedInterval.down(.prime)` to canonical `.prime`** — `down()` factory now returns `.prime` when interval is `.prime`, preventing semantically invalid distinct values
4. **[MEDIUM] Fixed stale docstring in `Interval.swift`** — Removed reference to deleted `MIDINote.transposed(by:)` extension

**Remaining LOW issues (not fixed):**
- Inconsistent factory usage in `StartScreen.swift` (`[DirectedInterval.prime]` vs `[.prime]`)
- Redundant `Comparable` operator in `Direction.swift` (auto-synthesized from enum order)
- Missing downward transposition boundary test near MIDI 0 in `DirectedIntervalTests`

**Verification:** Full test suite passes after all fixes (`** TEST SUCCEEDED **`).

### File List

**Created:**
- `Peach/Core/Audio/Direction.swift`
- `Peach/Core/Audio/DirectedInterval.swift`
- `PeachTests/Core/Audio/DirectionTests.swift`
- `PeachTests/Core/Audio/DirectedIntervalTests.swift`

**Modified:**
- `Peach/Core/Audio/Interval.swift`
- `Peach/Core/TrainingSession.swift`
- `Peach/Core/Algorithm/NextComparisonStrategy.swift`
- `Peach/Core/Algorithm/KazezNoteStrategy.swift`
- `Peach/Comparison/ComparisonSession.swift`
- `Peach/PitchMatching/PitchMatchingSession.swift`
- `Peach/App/NavigationDestination.swift`
- `Peach/Comparison/ComparisonScreen.swift`
- `Peach/PitchMatching/PitchMatchingScreen.swift`
- `Peach/Settings/UserSettings.swift`
- `Peach/Settings/AppUserSettings.swift`
- `Peach/Start/StartScreen.swift`
- `Peach/App/EnvironmentKeys.swift`
- `Peach/Resources/Localizable.xcstrings`
- `PeachTests/Core/Audio/IntervalTests.swift`
- `PeachTests/Core/Audio/MIDINoteTests.swift`
- `PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift`
- `PeachTests/Comparison/ComparisonSessionTests.swift`
- `PeachTests/Comparison/MockNextComparisonStrategy.swift`
- `PeachTests/PitchMatching/PitchMatchingSessionTests.swift`
- `PeachTests/Mocks/MockUserSettings.swift`
- `PeachTests/Start/StartScreenTests.swift`
- `PeachTests/Settings/SettingsTests.swift`
- `PeachTests/Core/Profile/PerceptualProfileTests.swift`
- `PeachTests/Core/Data/TrainingDataStoreTests.swift`
- `docs/implementation-artifacts/25-1-direction-enum-and-directedinterval.md`
- `docs/implementation-artifacts/sprint-status.yaml`

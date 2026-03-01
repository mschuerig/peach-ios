# Story 25.2: Interval Selector on Settings Screen

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to select which directed intervals are active for training on the Settings screen,
so that I can customize my interval ear training to focus on specific intervals and directions.

## Acceptance Criteria

### AC 1: Interval selector grid displays in Settings
**Given** the Settings screen
**When** the user scrolls to the Intervals section
**Then** a two-row grid displays with row headers ⏶ (up) and ⏷ (down)
**And** columns for all 13 intervals: P1, m2, M2, m3, M3, P4, d5, P5, m6, M6, m7, M7, P8
**And** each cell is a toggle button showing the interval abbreviation
**And** active cells are visually distinct from inactive cells
**And** the Prime (P1) column only has an active toggle in the Up row (Down row disabled/hidden, since `.down(.prime)` normalizes to `.prime`)

### AC 2: Interval selection persists via UserDefaults
**Given** the user toggles intervals on/off in the selector
**When** the app is restarted
**Then** the previously selected intervals are restored
**And** the `SettingsKeys.intervals` key stores the selection as a JSON-encoded string
**And** the default value is `[.up(.perfectFifth)]` (matching pre-existing behavior)

### AC 3: AppUserSettings reads persisted intervals
**Given** `AppUserSettings` implements `UserSettings.intervals`
**When** a training session reads `userSettings.intervals`
**Then** it receives the user's persisted selection from UserDefaults
**And** decoding failure or missing key falls back to `[.up(.perfectFifth)]`

### AC 4: At least one interval must remain selected
**Given** the interval selector with exactly one interval active
**When** the user attempts to deactivate the last remaining interval
**Then** the toggle is prevented (button disabled or tap ignored)
**And** the user cannot reach an empty selection state

### AC 5: All user-facing strings are localized (EN/DE)
**Given** the interval selector UI
**When** the device language is German
**Then** section title "Intervals" displays as "Intervalle"
**And** help text is displayed in German
**And** interval abbreviations (P1, m2, M2, etc.) remain unchanged (international standard notation)
**And** row header symbols ⏶/⏷ are not localized (universal symbols)

### AC 6: Start screen interval-mode buttons use selected intervals
**Given** the user has selected specific intervals in Settings
**When** the user taps "Interval Comparison" or "Interval Pitch Matching" on the Start screen
**Then** the training session uses the user-selected intervals (not hardcoded `[.up(.perfectFifth)]`)
**And** unison-mode buttons continue using `[.prime]` regardless of settings

### AC 7: Comprehensive test coverage
**Given** the test suite
**When** all tests run
**Then** serialization round-trip tests pass for `Set<DirectedInterval>` encoding/decoding
**And** `AppUserSettings.intervals` correctly reads from UserDefaults
**And** default fallback works when no UserDefaults entry exists
**And** minimum-selection guard is tested
**And** full test suite passes

## Tasks / Subtasks

- [ ] Task 1: Add `Interval.abbreviation` computed property (AC: 1)
  - [ ] Add `abbreviation: String` to `Interval` enum returning standard notation: P1, m2, M2, m3, M3, P4, d5, P5, m6, M6, m7, M7, P8
  - [ ] NOT localized — these are international standard music theory abbreviations (plain `String`, not `String(localized:)`)
  - [ ] Add tests in `IntervalTests.swift` verifying all 13 abbreviations
- [ ] Task 2: Add interval serialization for UserDefaults (AC: 2, 3)
  - [ ] Create `Set<DirectedInterval>` ↔ JSON string serialization (encode/decode)
  - [ ] Approach: extend or wrap to conform to `RawRepresentable` where `RawValue == String` for `@AppStorage` compatibility
  - [ ] Handle decoding failure gracefully (return default)
  - [ ] Add round-trip serialization tests
- [ ] Task 3: Add `SettingsKeys.intervals` key and default (AC: 2, 3)
  - [ ] Add `static let intervals = "intervals"` to `SettingsKeys`
  - [ ] Add `static let defaultIntervals` — the JSON-encoded string of `[DirectedInterval.up(.perfectFifth)]`
  - [ ] File: `Peach/Settings/SettingsKeys.swift`
- [ ] Task 4: Update `AppUserSettings.intervals` to read from UserDefaults (AC: 3)
  - [ ] Replace hardcoded `[.up(.perfectFifth)]` with UserDefaults read + JSON decode
  - [ ] Fallback to `[.up(.perfectFifth)]` on decode failure or missing key
  - [ ] File: `Peach/Settings/AppUserSettings.swift`
  - [ ] Add test in `SettingsTests.swift` or new test file
- [ ] Task 5: Create `IntervalSelectorView` subview (AC: 1, 4)
  - [ ] New file `Peach/Settings/IntervalSelectorView.swift`
  - [ ] Two-row grid: Up row (⏶) and Down row (⏷), each with 13 interval columns
  - [ ] Row headers use ⏶/⏷ symbols (Unicode: U+23F6 / U+23F7), not text labels
  - [ ] Column headers show `Interval.abbreviation`
  - [ ] Each cell is a toggle button (visually distinct active/inactive states)
  - [ ] Prime column: Down row cell disabled (prime has no direction)
  - [ ] Minimum-selection guard: disable last active toggle
  - [ ] Horizontal scroll if grid exceeds screen width
  - [ ] Binding to `Set<DirectedInterval>` selection
- [ ] Task 6: Add Intervals section to `SettingsScreen` (AC: 1, 5)
  - [ ] New `Section` in the Form with localized title "Intervals"
  - [ ] Contains `IntervalSelectorView` with `@AppStorage` binding
  - [ ] Footer/help text explaining the selector purpose (localized EN/DE)
  - [ ] File: `Peach/Settings/SettingsScreen.swift`
- [ ] Task 7: Update `StartScreen` to use selected intervals (AC: 6)
  - [ ] Replace hardcoded `[.up(.perfectFifth)]` in interval-mode NavigationLinks
  - [ ] Read intervals from `AppUserSettings` via `@Environment` or `@AppStorage`
  - [ ] Unison-mode buttons remain `[.prime]` (unchanged)
  - [ ] File: `Peach/Start/StartScreen.swift`
- [ ] Task 8: Add localized strings (AC: 5)
  - [ ] Section title: "Intervals" (de: "Intervalle")
  - [ ] Help text (EN + DE) explaining interval selector purpose
  - [ ] File: `Peach/Resources/Localizable.xcstrings`
- [ ] Task 9: Run full test suite (AC: 7)
  - [ ] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  - [ ] All tests pass

## Dev Notes

### Developer Context — Critical Implementation Intelligence

This story connects the `DirectedInterval` type system (created in story 25.1) to the user-facing settings, replacing the hardcoded `[.up(.perfectFifth)]` with a user-configurable interval selection. It adds a visual grid selector to the Settings screen and persists the selection via UserDefaults.

**Scope of change:** ~6 source files modified, 1 new view file created, localization updates. Medium complexity — the main challenge is the `@AppStorage` serialization for `Set<DirectedInterval>` and the grid UI layout.

**What this story changes:**
- Adds `Interval.abbreviation` for compact grid labels
- Adds interval serialization to/from JSON string for UserDefaults persistence
- Adds `SettingsKeys.intervals` key and default
- Updates `AppUserSettings.intervals` from hardcoded to UserDefaults-backed
- Creates `IntervalSelectorView` (new subview for the two-row grid)
- Adds Intervals section to `SettingsScreen`
- Updates `StartScreen` interval-mode buttons to use selected intervals

**What this story does NOT change:**
- `Direction`, `DirectedInterval` — types created in 25.1 are stable, no modifications
- `ComparisonSession`, `PitchMatchingSession` — already accept `Set<DirectedInterval>` via `start(intervals:)`
- `NavigationDestination` — already parameterized with `Set<DirectedInterval>`
- `KazezNoteStrategy` — already handles directional note ranges
- `NotePlayer`, audio layer — untouched
- Data models — no schema changes
- Profile computation — unchanged

**Critical: The `@AppStorage` serialization challenge:**
`@AppStorage` natively supports `String`, `Int`, `Double`, `Bool`, `URL`, `Data`. For `Set<DirectedInterval>`, you need `RawRepresentable` conformance where `RawValue == String`. Since `DirectedInterval` is `Codable` (from story 25.1), JSON encode/decode to String works. Two approaches:

**Approach A — Extension on `Set<DirectedInterval>` (retroactive conformance):**
```swift
// May require @retroactive in Swift 6.2; check compiler behavior
extension Set: @retroactive RawRepresentable where Element == DirectedInterval { ... }
```

**Approach B — Wrapper type (preferred, avoids retroactive conformance):**
```swift
struct IntervalSelection: RawRepresentable, Equatable {
    var intervals: Set<DirectedInterval>
    init(_ intervals: Set<DirectedInterval>) { self.intervals = intervals }
    init?(rawValue: String) { /* JSON decode */ }
    var rawValue: String { /* JSON encode */ }
}
// Usage: @AppStorage(SettingsKeys.intervals) private var intervalSelection = IntervalSelection([.up(.perfectFifth)])
```

Choose whichever approach the Swift 6.2 compiler accepts cleanly. Place serialization code in `Peach/Settings/` (it's a settings concern, not a domain concern).

### Technical Requirements

**Grid UI layout:**
```
+-+--+--+--+--+--+--+--+--+--+--+--+--+--+
|⏶|P1|m2|M2|m3|M3|P4|d5|P5|m6|M6|m7|M7|P8|
+-+--+--+--+--+--+--+--+--+--+--+--+--+--+
|⏷|P1|m2|M2|m3|M3|P4|d5|P5|m6|M6|m7|M7|P8|
+-+--+--+--+--+--+--+--+--+--+--+--+--+--+
```
- Use SwiftUI `Grid` (available since iOS 16, project targets iOS 26)
- Wrap in `ScrollView(.horizontal)` if 13 columns exceed screen width
- Row headers: ⏶ / ⏷ symbols (Unicode U+23F6 / U+23F7) — not text, not localized
- Column labels: `Interval.abbreviation` (P1, m2, M2, m3, M3, P4, d5, P5, m6, M6, m7, M7, P8)
- Toggle cells: visually distinct active (accent color) vs inactive (muted) states
- Prime column special handling: Down row cell disabled/hidden

**Interval abbreviations (standard music theory notation):**
| Interval | Abbreviation |
|----------|-------------|
| prime | P1 |
| minorSecond | m2 |
| majorSecond | M2 |
| minorThird | m3 |
| majorThird | M3 |
| perfectFourth | P4 |
| tritone | d5 |
| perfectFifth | P5 |
| minorSixth | m6 |
| majorSixth | M6 |
| minorSeventh | m7 |
| majorSeventh | M7 |
| octave | P8 |

These are international standard notation — NOT localized (same in EN and DE).

**Minimum selection enforcement:**
When only one interval remains active, its toggle button should be disabled (prevent tap). Check `selection.count == 1 && selection.contains(interval)` before allowing deactivation.

**StartScreen integration:**
Currently `StartScreen` hardcodes interval-mode buttons:
```swift
NavigationDestination.comparison(intervals: [.up(.perfectFifth)])
NavigationDestination.pitchMatching(intervals: [.up(.perfectFifth)])
```
After this story, read from settings:
```swift
// Option A: @AppStorage with same key
@AppStorage(SettingsKeys.intervals) private var intervalSelection = IntervalSelection([.up(.perfectFifth)])
// Then: NavigationDestination.comparison(intervals: intervalSelection.intervals)

// Option B: @Environment(\.userSettings)
@Environment(\.userSettings) private var userSettings
// Then: NavigationDestination.comparison(intervals: userSettings.intervals)
```
Use whichever approach minimizes `@Environment` surface per project conventions. `@AppStorage` is self-contained; `@Environment(\.userSettings)` adds a dependency but uses the existing protocol.

### Architecture Compliance

1. **Settings pattern** — `@AppStorage` with centralized keys in `SettingsKeys.swift`, `AppUserSettings` reads from `UserDefaults.standard` [Source: docs/project-context.md#Settings]
2. **Views are thin** — `IntervalSelectorView` observes state and renders; toggle logic is simple binding mutation [Source: docs/project-context.md#SwiftUI View Rules]
3. **Extract subviews at ~40 lines** — the grid is complex enough to warrant its own file `IntervalSelectorView.swift` [Source: docs/project-context.md#SwiftUI View Rules]
4. **Core/ is framework-free** — `Interval.abbreviation` is a pure `String` property, no SwiftUI import [Source: docs/project-context.md#Dependency Direction Rules]
5. **File placement** — new view in `Settings/` (same feature directory as `SettingsScreen`) [Source: docs/project-context.md#File Placement]
6. **String Catalogs for localization** — section title and help text via `String(localized:)`, auto-extracted to `.xcstrings` [Source: docs/project-context.md#Localization]
7. **No cross-feature coupling** — `IntervalSelectorView` only depends on `DirectedInterval`, `Interval`, `Direction` from `Core/Audio/` [Source: docs/project-context.md#Dependency Direction Rules]
8. **Value types by default** — serialization wrapper (if used) is a struct [Source: docs/project-context.md#Type Design]

### Library/Framework Requirements

- **Swift 6.2** with strict concurrency — `Sendable` on any new types
- **SwiftUI** — `Grid`, `ScrollView`, `@AppStorage`, `Section`, `Button`
- **Foundation** — `JSONEncoder`, `JSONDecoder` for serialization
- **No new dependencies** — zero third-party packages
- **SwiftData** — NOT affected
- **String Catalogs** — new localization entries

### File Structure — Files to Create

| File | Purpose |
|------|---------|
| `Peach/Settings/IntervalSelectorView.swift` | Two-row grid subview for interval selection |

### File Structure — Files to Modify

| File | Change | Why |
|------|--------|-----|
| `Peach/Core/Audio/Interval.swift` | Add `abbreviation` computed property | Compact grid labels |
| `Peach/Settings/SettingsKeys.swift` | Add `intervals` key and `defaultIntervals` | Persistence key |
| `Peach/Settings/AppUserSettings.swift` | Read `intervals` from UserDefaults with JSON decode | Replace hardcoded value |
| `Peach/Settings/SettingsScreen.swift` | Add Intervals `Section` with `IntervalSelectorView` | UI integration |
| `Peach/Start/StartScreen.swift` | Read intervals from settings for interval-mode buttons | Use user selection |
| `Peach/Resources/Localizable.xcstrings` | Add "Intervals", help text (EN/DE) | Localization |
| `PeachTests/Core/Audio/IntervalTests.swift` | Add `abbreviation` tests | Test coverage |
| `PeachTests/Settings/SettingsTests.swift` | Add serialization and AppUserSettings tests | Test coverage |

**Files NOT to modify:**
- `Peach/Core/Audio/Direction.swift` — unchanged (displayName already localized)
- `Peach/Core/Audio/DirectedInterval.swift` — unchanged (Codable conformance exists)
- `Peach/Comparison/ComparisonSession.swift` — already accepts `Set<DirectedInterval>` via `start(intervals:)`
- `Peach/PitchMatching/PitchMatchingSession.swift` — already accepts `Set<DirectedInterval>`
- `Peach/App/NavigationDestination.swift` — already parameterized with `Set<DirectedInterval>`
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` — already handles directional note ranges
- `Peach/Settings/UserSettings.swift` — protocol already has `intervals: Set<DirectedInterval>`
- `Peach/App/PeachApp.swift` — no new services to wire
- `Peach/App/EnvironmentKeys.swift` — no new environment entries needed (unless using @Environment approach for StartScreen)
- Data models, profile computation, audio layer — all untouched

### Testing Requirements

**TDD approach — write failing tests first for each task:**

1. **IntervalTests.swift — abbreviation tests:**
   - All 13 intervals return correct abbreviation
   - Abbreviations match standard music theory notation

2. **Serialization tests (new or in SettingsTests.swift):**
   - Empty set encodes/decodes (edge case for validation)
   - Single interval round-trip: `[.up(.perfectFifth)]`
   - Multiple intervals round-trip: `[.prime, .up(.majorThird), .down(.perfectFifth)]`
   - All 25 possible DirectedIntervals round-trip (13 up + 12 down, prime only up)
   - Invalid JSON string falls back to default
   - Missing key falls back to default

3. **AppUserSettings tests:**
   - When no UserDefaults entry: returns `[.up(.perfectFifth)]`
   - When valid JSON in UserDefaults: returns decoded set
   - When invalid JSON in UserDefaults: returns fallback

4. **Test execution:** `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

### Previous Story Intelligence (Story 25.1)

**Key learnings from story 25.1:**
- `DirectedInterval` is `Codable` — JSON serialization works out of the box
- `DirectedInterval.down(.prime)` normalizes to `.prime` (canonical form) — the grid must handle this: Down row for prime column should be disabled
- `Direction.displayName` returns localized "Up"/"Down" ("aufwärts"/"abwärts") — available but grid uses ⏶/⏷ symbols instead
- `Interval.name` returns localized full names — for grid, use new `abbreviation` instead
- `Interval.allCases` gives all 13 intervals in order (prime through octave) — use for grid columns
- `Direction.allCases` gives `[.up, .down]` — use for grid rows
- Code review found: inconsistent factory usage in StartScreen (`[DirectedInterval.prime]` vs `[.prime]`) — use consistent short form in this story

**Files established in 25.1 that this story builds on:**
- `Direction.swift` — enum with displayName, CaseIterable
- `DirectedInterval.swift` — struct with Codable, static factories
- `Interval.swift` — renamed `name` property, CaseIterable
- `UserSettings.swift` — protocol already has `intervals: Set<DirectedInterval>`
- `AppUserSettings.swift` — currently hardcoded, target for this story

### Git Intelligence

Recent commits:
```
b12314f Fix code review findings for story 25.1 and mark done
45ccd14 Implement story 25.1: Direction Enum and DirectedInterval
337ef50 Add story 25.1: Direction Enum and DirectedInterval
eec3fc0 Update sprint status: close epics 21-24, add epics 25-27
2f8f968 Fix code review findings for story 24.2 and mark done
96572c1 Implement story 24.2: Start Screen Four Training Buttons
```

**Commit pattern:** `Add story X.Y: Title` → `Implement story X.Y: Title` → `Fix code review findings for story X.Y and mark done`

### Project Structure Notes

- New file `IntervalSelectorView.swift` goes in `Peach/Settings/` (same directory as SettingsScreen)
- Serialization code goes in `Peach/Settings/` (settings concern, not domain)
- `Interval.abbreviation` goes in existing `Peach/Core/Audio/Interval.swift`
- No new directories needed
- No cross-feature coupling introduced

### References

- [Source: docs/implementation-artifacts/sprint-status.yaml#Epic 25] — "Two-row grid (up/down x 13 intervals P1-P8), toggle active, localized help texts"
- [Source: docs/implementation-artifacts/25-1-direction-enum-and-directedinterval.md] — Previous story with Direction, DirectedInterval, all Codable
- [Source: docs/project-context.md#Settings] — @AppStorage pattern, SettingsKeys centralization
- [Source: docs/project-context.md#SwiftUI View Rules] — Thin views, subview extraction at ~40 lines
- [Source: docs/project-context.md#File Placement] — Settings/ for settings-related views
- [Source: docs/project-context.md#Localization] — String Catalogs, String(localized:)
- [Source: docs/project-context.md#Testing Rules] — Swift Testing, TDD workflow
- [Source: Peach/Settings/SettingsScreen.swift] — Current Form layout with 4 sections
- [Source: Peach/Settings/SettingsKeys.swift] — Key centralization pattern
- [Source: Peach/Settings/AppUserSettings.swift] — UserDefaults read pattern, hardcoded intervals
- [Source: Peach/Settings/UserSettings.swift] — Protocol with intervals property
- [Source: Peach/Core/Audio/Interval.swift] — 13-case enum, CaseIterable, Codable, name property
- [Source: Peach/Core/Audio/Direction.swift] — Up/Down enum, CaseIterable, displayName
- [Source: Peach/Core/Audio/DirectedInterval.swift] — Codable struct with static factories
- [Source: Peach/Start/StartScreen.swift] — Hardcoded interval-mode NavigationLinks to update

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

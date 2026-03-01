# Story 23.4: Training Screen Interval Label and Observer Verification

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want both `ComparisonScreen` and `PitchMatchingScreen` to show a conditional target interval label when in interval mode, and verify that observers/profiles handle the updated value types,
So that users see what interval they're training and all data flows correctly through the system.

## Acceptance Criteria

1. **ComparisonScreen shows interval label in interval mode**
   - **Given** `ComparisonScreen` receives training via the `comparisonSession` environment
   - **When** `comparisonSession.isIntervalMode` is `true`
   - **Then** a `Text` label showing the current interval name (e.g., "Perfect Fifth Up") is visible at the top of the training area, below the `DifficultyDisplayView` and above the answer buttons
   - **And** the label uses `.headline` or `.title3` styling

2. **ComparisonScreen hides label in unison mode**
   - **Given** `ComparisonScreen` is entered in unison mode (`intervals: [.prime]`)
   - **When** `comparisonSession.isIntervalMode` is `false`
   - **Then** no interval label is visible — the screen looks exactly as pre-v0.3

3. **PitchMatchingScreen shows interval label in interval mode**
   - **Given** `PitchMatchingScreen` receives training via the `pitchMatchingSession` environment
   - **When** `pitchMatchingSession.isIntervalMode` is `true`
   - **Then** a `Text` label showing the current interval name is visible at the top of the screen, above the `VerticalPitchSlider`

4. **PitchMatchingScreen hides label in unison mode**
   - **When** `pitchMatchingSession.isIntervalMode` is `false`
   - **Then** no interval label is visible

5. **VoiceOver reads the interval label accessibly**
   - **Given** the target interval label
   - **When** VoiceOver is active
   - **Then** it reads "Target interval: Perfect Fifth Up" (or equivalent accessible label)

6. **Observers handle updated value types correctly**
   - **Given** `ComparisonObserver` and `PitchMatchingObserver` receive updated value types with `tuningSystem` and `targetNote`
   - **When** interval training results flow through the observer path
   - **Then** profiles receive all data regardless of interval — no filtering, no interval-aware aggregation
   - **And** all frequency computations in sessions flow through `TuningSystem.frequency(for:referencePitch:)`

## Tasks / Subtasks

- [x] Task 1: Add `displayName` computed property to `Interval` enum (AC: #1, #3, #5)
  - [x] Add `var displayName: String` computed property to `Interval` in `Peach/Core/Audio/Interval.swift`
  - [x] Return localized strings using `String(localized:)` for each case:
    - `.prime` → "Prime" (though it won't display in UI since `isIntervalMode` is false)
    - `.minorSecond` → "Minor Second Up"
    - `.majorSecond` → "Major Second Up"
    - `.minorThird` → "Minor Third Up"
    - `.majorThird` → "Major Third Up"
    - `.perfectFourth` → "Perfect Fourth Up"
    - `.tritone` → "Tritone Up"
    - `.perfectFifth` → "Perfect Fifth Up"
    - `.minorSixth` → "Minor Sixth Up"
    - `.majorSixth` → "Major Sixth Up"
    - `.minorSeventh` → "Minor Seventh Up"
    - `.majorSeventh` → "Major Seventh Up"
    - `.octave` → "Octave Up"
  - [x] Write tests for `displayName` for `.prime`, `.perfectFifth`, and `.octave` at minimum

- [x] Task 2: Add interval label to `ComparisonScreen` (AC: #1, #2, #5)
  - [x] In `ComparisonScreen.swift` body, after the `DifficultyDisplayView` block (line 29) and before the `Group` (line 31), add:
    ```swift
    if comparisonSession.isIntervalMode, let interval = comparisonSession.currentInterval {
        Text(interval.displayName)
            .font(.title3)
            .accessibilityLabel(String(localized: "Target interval: \(interval.displayName)"))
    }
    ```
  - [x] When `isIntervalMode` is `false` (unison), the `if` block does not render — screen is unchanged from pre-v0.3

- [x] Task 3: Add interval label to `PitchMatchingScreen` (AC: #3, #4, #5)
  - [x] In `PitchMatchingScreen.swift` body, wrap existing content in a `VStack` and add the label above the `VerticalPitchSlider`:
    ```swift
    VStack(spacing: 8) {
        if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
            Text(interval.displayName)
                .font(.title3)
                .accessibilityLabel(String(localized: "Target interval: \(interval.displayName)"))
        }

        VerticalPitchSlider(...)
            .padding()
            .overlay { ... }
            .animation(...)
    }
    ```
  - [x] When `isIntervalMode` is `false` (unison), the `if` block does not render — screen is unchanged

- [x] Task 4: Verify observer/profile data flows handle interval context (AC: #6)
  - [x] Write a verification test in `TrainingDataStoreTests.swift`:
    - Create a `CompletedComparison` with `tuningSystem: .equalTemperament` and a non-prime interval (targetNote = referenceNote + 7 semitones)
    - Call `comparisonCompleted(_:)` on `TrainingDataStore`
    - Verify the persisted `ComparisonRecord` has correct `interval` (7), `tuningSystem` ("equal_temperament"), and `targetNote` values
  - [x] Write a verification test in `TrainingDataStoreTests.swift`:
    - Create a `CompletedPitchMatching` with `tuningSystem: .equalTemperament`, `targetNote = referenceNote.transposed(by: .perfectFifth)`
    - Call `pitchMatchingCompleted(_:)` on `TrainingDataStore`
    - Verify the persisted `PitchMatchingRecord` has correct `interval` (7), `tuningSystem`, and `targetNote` values
  - [x] Write a verification test in `PerceptualProfileTests.swift`:
    - Create a `CompletedComparison` with an interval (e.g., `.perfectFifth`)
    - Call `comparisonCompleted(_:)` on `PerceptualProfile`
    - Verify profile uses `referenceNote` as key (not targetNote) — profile indexes by reference note
  - [x] Write a verification test in `PerceptualProfileTests.swift`:
    - Create a `CompletedPitchMatching` with an interval
    - Call `pitchMatchingCompleted(_:)` on `PerceptualProfile`
    - Verify profile uses `referenceNote` as key

- [x] Task 5: Add localization entries to String Catalog (AC: #1, #3, #5)
  - [x] The `String(localized:)` calls will auto-extract to `Localizable.xcstrings`
  - [x] After building, add German translations for all interval display names:
    - "Perfect Fifth Up" → "Reine Quinte aufwärts"
    - "Minor Second Up" → "Kleine Sekunde aufwärts"
    - "Major Second Up" → "Große Sekunde aufwärts"
    - "Minor Third Up" → "Kleine Terz aufwärts"
    - "Major Third Up" → "Große Terz aufwärts"
    - "Perfect Fourth Up" → "Reine Quarte aufwärts"
    - "Tritone Up" → "Tritonus aufwärts"
    - "Minor Sixth Up" → "Kleine Sexte aufwärts"
    - "Major Sixth Up" → "Große Sexte aufwärts"
    - "Minor Seventh Up" → "Kleine Septime aufwärts"
    - "Major Seventh Up" → "Große Septime aufwärts"
    - "Octave Up" → "Oktave aufwärts"
    - "Prime" → "Prime"
    - "Target interval: %@" → "Zielintervall: %@"

- [x] Task 6: Run full test suite and commit (AC: all)
  - [x] Run: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] Run: `tools/check-dependencies.sh`
  - [x] All tests pass, no dependency violations

## Dev Notes

### Current State of Each File (Read These First)

| Type | File | Current State |
|------|------|---------------|
| `Interval` | `Peach/Core/Audio/Interval.swift` (46 lines) | Enum with 13 cases (prime-octave), `semitones`, `between()`, no display name |
| `ComparisonScreen` | `Peach/Comparison/ComparisonScreen.swift` (167 lines) | VStack with DifficultyDisplayView + Higher/Lower buttons, no interval label |
| `PitchMatchingScreen` | `Peach/PitchMatching/PitchMatchingScreen.swift` (73 lines) | VerticalPitchSlider with feedback overlay, no interval label |
| `ComparisonSession` | `Peach/Comparison/ComparisonSession.swift` (321 lines) | Has `currentInterval: Interval?` (line 25), `isIntervalMode` (line 99) — already observable |
| `PitchMatchingSession` | `Peach/PitchMatching/PitchMatchingSession.swift` (251 lines) | Has `currentInterval: Interval?` (line 37), `isIntervalMode` (line 38) — already observable |
| `TrainingDataStore` | `Peach/Core/Data/TrainingDataStore.swift` (161 lines) | `ComparisonObserver` (line 134), `PitchMatchingObserver` (line 109) — both compute interval from notes, persist `tuningSystem` |
| `PerceptualProfile` | `Peach/Core/Profile/PerceptualProfile.swift` (193 lines) | `ComparisonObserver` (line 173) uses `referenceNote`, `PitchMatchingObserver` (line 188) uses `referenceNote` |

### How the Interval Label Works

Both sessions already have all the observable state needed. The screens simply need to read it:

**ComparisonSession (Story 23.2):**
```swift
// Line 25 — observable, set per comparison exercise
private(set) var currentInterval: Interval? = nil

// Line 99 — computed from currentInterval
var isIntervalMode: Bool { currentInterval != nil && currentInterval != .prime }
```

**PitchMatchingSession (Story 23.3):**
```swift
// Line 37 — observable, set per challenge
private(set) var currentInterval: Interval? = nil

// Line 38 — computed from currentInterval
var isIntervalMode: Bool { currentInterval != nil && currentInterval != .prime }
```

The `@Observable` macro on both session classes means SwiftUI automatically re-renders when `currentInterval` or `isIntervalMode` changes. No additional wiring needed.

### Interval Display Name — Localization Pattern

The project uses `String(localized:)` for localizable strings (see `PitchMatchingFeedbackIndicator.swift:54-88`, `VerticalPitchSlider.swift:65`). String Catalogs (`Localizable.xcstrings`) auto-extract these on build.

Add to `Interval`:
```swift
var displayName: String {
    switch self {
    case .prime: String(localized: "Prime")
    case .minorSecond: String(localized: "Minor Second Up")
    case .majorSecond: String(localized: "Major Second Up")
    // ... etc
    }
}
```

**Important:** `Interval` lives in `Core/Audio/` which must NOT import SwiftUI. Use `import Foundation` — `String(localized:)` is Foundation API, not SwiftUI. This is correct and safe.

### ComparisonScreen Label Placement

Current body structure (simplified):
```swift
VStack(spacing: 8) {
    if let difficulty = comparisonSession.currentDifficulty {
        DifficultyDisplayView(...)          // ← existing
    }
    // INSERT INTERVAL LABEL HERE
    Group {
        if isCompactHeight { HStack { ... } }
        else { VStack { ... } }
    }
}
```

The interval label goes between `DifficultyDisplayView` and the answer button `Group`, at the same nesting level. This positions it "below navigation buttons and above the training interaction area" as required.

### PitchMatchingScreen Label Placement

Current body is just `VerticalPitchSlider(...)` with modifiers. Need to wrap in a VStack:
```swift
VStack(spacing: 8) {
    if pitchMatchingSession.isIntervalMode, let interval = pitchMatchingSession.currentInterval {
        Text(interval.displayName)
            .font(.title3)
            .accessibilityLabel(String(localized: "Target interval: \(interval.displayName)"))
    }
    VerticalPitchSlider(...)
        .padding()
        .overlay { ... }
        .animation(...)
}
// Move .navigationTitle, .toolbar, .onAppear, .onDisappear to VStack level
```

### Observer Verification — What to Confirm

The observers already handle interval data correctly (implemented in Stories 23.1-23.3). The verification tests confirm this works end-to-end:

**TrainingDataStore (line 109-160):**
- `PitchMatchingObserver`: Computes `interval` from `result.referenceNote` and `result.targetNote` via `Interval.between()`. Persists `tuningSystem.storageIdentifier`. Both work regardless of interval value.
- `ComparisonObserver`: Computes `interval` from `comparison.referenceNote` and `comparison.targetNote.note` via `Interval.between()`. Same pattern.

**PerceptualProfile (line 173-192):**
- `ComparisonObserver`: Uses `comparison.referenceNote` as index key, `comparison.targetNote.offset.magnitude` as the cent data. Does NOT filter by interval — all data feeds into the profile regardless. Correct.
- `PitchMatchingObserver`: Uses `result.referenceNote` as index key, `result.userCentError` as the cent data. Does NOT filter by interval. Correct.

**Key point:** Profiles receive ALL data regardless of interval. No interval-aware aggregation or filtering. This is the correct design — interval-specific profile views are a future epic concern. For now, all training data contributes equally to the overall profile.

### Existing Test Files for Verification Tests

| Test File | Location |
|-----------|----------|
| `TrainingDataStoreTests.swift` | `PeachTests/Core/Data/TrainingDataStoreTests.swift` |
| `PerceptualProfileTests.swift` | `PeachTests/Core/Profile/PerceptualProfileTests.swift` |
| `IntervalTests.swift` | `PeachTests/Core/Audio/IntervalTests.swift` |

### `Interval.displayName` is Core/ — No SwiftUI Import Needed

`String(localized:)` is `Foundation.String` API (available since iOS 16). `Peach/Core/Audio/Interval.swift` already imports `Foundation`. No import changes needed. The dependency checker (`tools/check-dependencies.sh`) will pass without issues.

### Accessibility Considerations

Standard `Text` views are VoiceOver-readable by default. The explicit `.accessibilityLabel` adds "Target interval:" prefix for extra context. Dynamic Type is automatically supported by `.title3` font.

### Project Structure Notes

All changes stay within established directories:
- `Peach/Core/Audio/Interval.swift` — add `displayName` computed property (Core/ file, Foundation only)
- `Peach/Comparison/ComparisonScreen.swift` — add conditional interval label
- `Peach/PitchMatching/PitchMatchingScreen.swift` — add conditional interval label
- `PeachTests/Core/Audio/IntervalTests.swift` — new tests for `displayName`
- `PeachTests/Core/Data/TrainingDataStoreTests.swift` — verification tests for observer with interval data
- `PeachTests/Core/Profile/PerceptualProfileTests.swift` — verification tests for profile with interval data

No new files created. No new directories. No cross-feature coupling. No new dependencies.

### References

- [Source: docs/planning-artifacts/epics.md#Story 23.4] — Full acceptance criteria
- [Source: docs/planning-artifacts/epics.md#Epic 23] — Epic context and all stories overview
- [Source: docs/project-context.md#Testing Rules] — Swift Testing, TDD workflow
- [Source: docs/project-context.md#Critical Don't-Miss Rules] — TuningSystem bridge, views are thin
- [Source: docs/project-context.md#Framework-Specific Rules] — @Observable, @Environment, no business logic in views
- [Source: docs/implementation-artifacts/23-3-pitchmatchingsession-interval-parameterization.md] — Previous story learnings and patterns
- [Source: docs/implementation-artifacts/23-2-comparisonsession-and-strategy-interval-parameterization.md] — ComparisonSession interval pattern
- [Source: Peach/Core/Audio/Interval.swift] — Current Interval enum (no displayName)
- [Source: Peach/Comparison/ComparisonScreen.swift] — Current screen layout (no interval label)
- [Source: Peach/PitchMatching/PitchMatchingScreen.swift] — Current screen layout (no interval label)
- [Source: Peach/Comparison/ComparisonSession.swift:25,99] — currentInterval, isIntervalMode
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:37,38] — currentInterval, isIntervalMode
- [Source: Peach/Core/Data/TrainingDataStore.swift:109-160] — Observer conformances computing interval from notes
- [Source: Peach/Core/Profile/PerceptualProfile.swift:173-192] — Profile observer using referenceNote as key

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- DisplayName tests initially failed in full suite due to simulator locale set to `de-DE`. `String(localized:)` returned German translations, causing exact English string comparisons to fail. Fixed by using `String(localized:)` in test expectations to be locale-independent.

### Completion Notes List

- Task 1: Added `displayName` computed property to `Interval` enum with `String(localized:)` for all 13 cases. Added 5 tests: prime/perfectFifth/octave key verification, non-empty check, uniqueness check.
- Task 2: Added conditional interval label to `ComparisonScreen` between `DifficultyDisplayView` and answer buttons. Uses `.title3` font with `.accessibilityLabel` for VoiceOver. Hidden in unison mode via `if isIntervalMode`.
- Task 3: Wrapped `PitchMatchingScreen` body in `VStack(spacing: 8)`, added conditional interval label above `VerticalPitchSlider`. Same styling and accessibility pattern as ComparisonScreen.
- Task 4: Added 4 verification tests confirming observers persist correct interval (7 for perfectFifth), tuningSystem ("equalTemperament"), and targetNote. Confirmed PerceptualProfile indexes by referenceNote, not targetNote.
- Task 5: Added 14 localization entries to `Localizable.xcstrings` — 13 interval display names + "Target interval: %@" accessibility label, all with German translations.
- Task 6: Full test suite passes, dependency checker passes.

### File List

- Peach/Core/Audio/Interval.swift (modified) — added `displayName` computed property
- Peach/Comparison/ComparisonScreen.swift (modified) — added conditional interval label
- Peach/PitchMatching/PitchMatchingScreen.swift (modified) — wrapped body in VStack, added conditional interval label
- Peach/Resources/Localizable.xcstrings (modified) — added 14 localization entries with German translations
- PeachTests/Core/Audio/IntervalTests.swift (modified) — added 5 displayName tests
- PeachTests/Core/Data/TrainingDataStoreTests.swift (modified) — added 2 interval context verification tests
- PeachTests/Core/Profile/PerceptualProfileTests.swift (modified) — added 2 interval context verification tests
- docs/implementation-artifacts/23-4-training-screen-interval-label-and-observer-verification.md (modified) — task tracking
- docs/implementation-artifacts/sprint-status.yaml (modified) — status update

### Change Log

- 2026-03-01: Implemented story 23.4 — Added interval display names to Interval enum, conditional interval labels to ComparisonScreen and PitchMatchingScreen, verification tests for observer/profile data flows, and German localization for all interval names.

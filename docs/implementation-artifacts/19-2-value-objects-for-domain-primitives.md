# Story 19.2: Value Objects for Domain Primitives

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want naked primitive types (Int, Double, UInt8, Float) wrapped in validated domain-specific Value Objects,
So that MIDI note ranges, cent values, frequencies, velocities, and amplitudes are enforced at compile time and the code communicates intent clearly.

## Acceptance Criteria

1. **`MIDINote` value type exists** -- A `struct MIDINote` validated to 0–127, with `.rawValue: Int`, `.name` (e.g., "A4"), `.frequency(referencePitch:)`, `Comparable`, `Hashable`, `Codable`, `ExpressibleByIntegerLiteral`. Lives in `Peach/Core/Audio/`.

2. **`MIDIVelocity` value type exists** -- A `struct MIDIVelocity` validated to 1–127, with `.rawValue: UInt8`, `ExpressibleByIntegerLiteral`.

3. **`Cents` value type exists** -- A `struct Cents` wrapping a signed `Double`, with `.rawValue: Double`, `.magnitude: Double`, `Comparable`, `ExpressibleByFloatLiteral`, `ExpressibleByIntegerLiteral`.

4. **`Frequency` value type exists** -- A `struct Frequency` wrapping a positive `Double`, with `.rawValue: Double`, `ExpressibleByFloatLiteral`, `ExpressibleByIntegerLiteral`.

5. **`AmplitudeDB` value type exists** -- A `struct AmplitudeDB` wrapping `Float`, auto-clamped to `-90.0...12.0` (using the named constant from Story 19.1), `ExpressibleByFloatLiteral`, `ExpressibleByIntegerLiteral`.

6. **Protocol and session signatures updated** -- `NotePlayer.play()` takes `Frequency`, `MIDIVelocity`, `AmplitudeDB`. `PitchDiscriminationProfile` and `PitchMatchingProfile` methods take `MIDINote` and `Cents` where appropriate. `PlaybackHandle.adjustFrequency()` takes `Frequency`.

7. **`Comparison` redesigned** -- `note1` and `note2` are `MIDINote`. `centDifference` is signed `Cents`. `isSecondNoteHigher` is a computed property (`centDifference.rawValue > 0`). The `isSecondNoteHigher` stored property is removed.

8. **Strategy methods produce signed `Cents`** -- `NextComparisonStrategy.nextComparison()` returns `Comparison` with signed `centDifference`. Direction (positive = second note higher) is randomly chosen by the strategy. `TrainingSettings` uses `MIDINote` for range and `Cents` for difficulty bounds.

9. **SwiftData models keep raw types** -- `ComparisonRecord` and `PitchMatchingRecord` retain `Int` and `Double` storage to avoid SwiftData migration. Conversion happens at boundaries: `.rawValue` when writing, `MIDINote(record.field)` when reading.

10. **Value Object types have unit tests** -- Each new value type has its own test file covering: valid construction, boundary validation, `ExpressibleByLiteral` conformance, and relevant computed properties.

11. **All existing tests pass** -- Full test suite passes with zero regressions. Test code updated to use new types where necessary.

## Tasks / Subtasks

- [x] Task 1: Create value type files (AC: #1, #2, #3, #4, #5)
  - [x] Create `Peach/Core/Audio/MIDINote.swift` — validated 0–127, `.name`, `.frequency()`, `.random(in:)`, Comparable, Hashable, Codable, ExpressibleByIntegerLiteral
  - [x] Create `Peach/Core/Audio/MIDIVelocity.swift` — validated 1–127, ExpressibleByIntegerLiteral
  - [x] Create `Peach/Core/Audio/Cents.swift` — signed Double wrapper, `.magnitude`, Comparable, ExpressibleByFloatLiteral + IntegerLiteral
  - [x] Create `Peach/Core/Audio/Frequency.swift` — positive Double, ExpressibleByFloatLiteral + IntegerLiteral
  - [x] Create `Peach/Core/Audio/AmplitudeDB.swift` — Float clamped to dB range, ExpressibleByFloatLiteral + IntegerLiteral
  - [x] All `init` methods marked `nonisolated` (required for ExpressibleByLiteral under default MainActor isolation)
  - [x] All `static let` range properties marked `nonisolated(unsafe)` (required despite SourceKit warning for Sendable types)

- [x] Task 2: Update `Comparison` struct (AC: #7)
  - [x] Change `note1: Int` → `note1: MIDINote`
  - [x] Change `note2: Int` → `note2: MIDINote`
  - [x] Change `centDifference: Double` → `centDifference: Cents` (signed)
  - [x] Remove stored `isSecondNoteHigher: Bool`, replace with computed property: `var isSecondNoteHigher: Bool { centDifference.rawValue > 0 }`
  - [x] Update `note1Frequency` / `note2Frequency` to use `.rawValue` when calling FrequencyCalculation

- [x] Task 3: Update `NotePlayer` protocol and implementations (AC: #6)
  - [x] `NotePlayer.play(frequency:velocity:amplitudeDB:)` → takes `Frequency`, `MIDIVelocity`, `AmplitudeDB`
  - [x] `NotePlayer.play(frequency:duration:velocity:amplitudeDB:)` → same type changes
  - [x] `PlaybackHandle.adjustFrequency(_:)` → takes `Frequency`
  - [x] `SoundFontNotePlayer` — extract `.rawValue` before passing to AVAudioUnitSampler
  - [x] `SoundFontPlaybackHandle` — extract `.rawValue` before passing to FrequencyCalculation

- [x] Task 4: Update `FrequencyCalculation` (AC: #6)
  - [x] Keep internal math using raw `Double`/`Int` — callers wrap/unwrap at boundaries
  - [x] OR update signatures to accept/return Value Objects (design decision — see Dev Notes)

- [x] Task 5: Update profile protocols and `PerceptualProfile` (AC: #6)
  - [x] `PitchDiscriminationProfile.update(note:centOffset:isCorrect:)` — `note: MIDINote`
  - [x] `PitchDiscriminationProfile.setDifficulty(note:difficulty:)` — `note: MIDINote`
  - [x] `PitchDiscriminationProfile.weakSpots()` → returns `[MIDINote]`
  - [x] `PitchDiscriminationProfile.statsForNote(_:)` — takes `MIDINote`
  - [x] `PitchMatchingProfile.updateMatching(note:centError:)` — `note: MIDINote`
  - [x] `PerceptualProfile` implementation — use `.rawValue` for internal array indexing

- [x] Task 6: Update `TrainingSettings` and strategies (AC: #8)
  - [x] `TrainingSettings.noteRangeMin/Max` → `MIDINote`
  - [x] `TrainingSettings.minCentDifference/maxCentDifference` → `Cents`
  - [x] `KazezNoteStrategy` — produce signed `Cents` with random direction
  - [x] `AdaptiveNoteStrategy` — produce signed `Cents` with random direction
  - [x] Ensure `CompletedComparison` uses the new types

- [x] Task 7: Update `ComparisonSession` (AC: #6, #8)
  - [x] Wrap `Frequency(...)` when calling `comparison.note1Frequency()`
  - [x] Use `MIDIVelocity` for velocity constant
  - [x] Use `AmplitudeDB` for amplitude calculations
  - [x] Update `currentSettings` to construct `MIDINote` from UserDefaults Int values

- [x] Task 8: Update `PitchMatchingSession` (AC: #6)
  - [x] Use `MIDINote.random(in:)` for challenge generation
  - [x] Wrap `Frequency(...)` when calling FrequencyCalculation
  - [x] Use `MIDIVelocity` and `AmplitudeDB` for playback calls

- [x] Task 9: Update data store boundary (AC: #9)
  - [x] `TrainingDataStore.comparisonCompleted()` — extract `.rawValue` from Value Objects before writing to `ComparisonRecord`
  - [x] `TrainingDataStore.pitchMatchingCompleted()` — extract `.rawValue` before writing to `PitchMatchingRecord`
  - [x] `PeachApp.swift` profile loading — wrap `MIDINote(record.note1)` when reading from records
  - [x] `ComparisonRecord` and `PitchMatchingRecord` — NO changes to @Model stored properties

- [x] Task 10: Update observers (AC: #6)
  - [x] `TrendAnalyzer.comparisonCompleted()` — use `.centDifference.magnitude` for unsigned threshold
  - [x] `ThresholdTimeline.comparisonCompleted()` — use `.centDifference.magnitude` and `.note1.rawValue`
  - [x] `HapticFeedbackManager` — if it references comparison types

- [x] Task 11: Update view files (AC: #6)
  - [x] `ComparisonScreen.swift` — update preview mock NotePlayer signatures
  - [x] `PitchMatchingScreen.swift` — update preview mock NotePlayer signatures
  - [x] `ProfileScreen.swift` — use `MIDINote(note)` in preview data population
  - [x] `SummaryStatisticsView.swift` — use `MIDINote($0)` in `computeStats`
  - [x] `PianoKeyboardView.swift` — wrap MIDI range values if needed

- [x] Task 12: Update all test mocks (AC: #11)
  - [x] `MockNotePlayer` — update `play()` signature to accept Value Objects, store `.rawValue` internally
  - [x] `MockNextComparisonStrategy` — default Comparison uses `MIDINote` and `Cents`
  - [x] `MockTrainingDataStore` — extract `.rawValue` for stored records
  - [x] `MockPitchMatchingProfile` — `updateMatching(note: MIDINote, ...)`
  - [x] `ComparisonTestHelpers` — default comparisons use signed `Cents`

- [x] Task 13: Update all test files (AC: #11)
  - [x] Replace `isSecondNoteHigher: true/false` with signed `Cents(100.0)` / `Cents(-100.0)`
  - [x] Replace `.centDifference` comparisons with `.centDifference.magnitude` where unsigned value expected
  - [x] Replace `.note1 >= X` with `.note1.rawValue >= X` for range checks
  - [x] Wrap loop variables: `for note in 0..<128 { profile.update(note: MIDINote(note), ...) }`
  - [x] Integer literals in `Comparison(note1: 60, ...)` work via `ExpressibleByIntegerLiteral` — no wrapping needed
  - [x] Test `UserDefaults` comparisons: `.noteRangeMin.rawValue == SettingsKeys.defaultNoteRangeMin`

- [x] Task 14: Write Value Object unit tests (AC: #10)
  - [x] Create `PeachTests/Core/Audio/MIDINoteTests.swift`
  - [x] Create `PeachTests/Core/Audio/CentsTests.swift`
  - [x] Create `PeachTests/Core/Audio/FrequencyTests.swift`
  - [x] Create `PeachTests/Core/Audio/MIDIVelocityTests.swift`
  - [x] Create `PeachTests/Core/Audio/AmplitudeDBTests.swift`

- [x] Task 15: Run full test suite and verify (AC: #11)
  - [x] Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All existing tests pass plus new Value Object tests
  - [x] Zero regressions

## Dev Notes

### Critical Design Decisions

- **`nonisolated init` is mandatory on all value types** -- Under Swift 6.2 default MainActor isolation, `ExpressibleByIntegerLiteral` and `ExpressibleByFloatLiteral` require `nonisolated init(integerLiteral:)` / `init(floatLiteral:)`. The primary `init` must also be `nonisolated` since the literal inits call it.
- **`nonisolated(unsafe)` on `static let` validation ranges** -- Despite SourceKit flagging this as "unnecessary" for Sendable types, the actual Swift 6.2 compiler rejects `nonisolated init` accessing a `static let` without this annotation. Apply it and suppress the warning.
- **`ExpressibleByLiteral` only works with literal values** -- `MIDINote` can be initialized as `let n: MIDINote = 60` (literal), but `let i = 60; let n: MIDINote = i` fails. Loop variables (`for i in 0..<128`) require explicit `MIDINote(i)` wrapping. This is the main source of test code churn.
- **`Comparison.centDifference` becomes signed** -- Positive = second note higher, negative = second note lower. `isSecondNoteHigher` becomes a computed property. This is a semantic improvement: strategies produce a single signed value instead of separate magnitude + direction.
- **Strategies produce random direction** -- Both `KazezNoteStrategy` and `AdaptiveNoteStrategy` determine the cent difference magnitude via their algorithm, then randomly negate it (50/50 chance). Test assertions on difficulty must use `.centDifference.magnitude`.
- **SwiftData @Model types keep raw primitives** -- `ComparisonRecord.note1` stays `Int`, `PitchMatchingRecord.referenceNote` stays `Int`. Wrapping at boundaries: `.rawValue` when storing, `MIDINote(record.note1)` when loading. This avoids SwiftData schema migration.
- **`FrequencyCalculation` keeps raw signatures** -- The math functions use `Double` and `Int` internally. Callers are responsible for unwrapping (`.rawValue`) and wrapping (`Frequency(result)`). This keeps the calculation pure and avoids circular dependencies between Value Objects and calculation utilities.
- **`Cents` for `centOffset` but NOT for `difficulty`** -- Profile methods like `update(note:centOffset:)` use `Double` for centOffset because cent offsets in the profile context are absolute thresholds, not signed pitch differences. Only `Comparison.centDifference` and strategy outputs use `Cents`. Consider whether `difficulty` in `setDifficulty` should also remain `Double`. (Design decision to make during implementation.)

### Architecture & Integration

**New files (5 value types + 5 test files):**
- `Peach/Core/Audio/MIDINote.swift`
- `Peach/Core/Audio/MIDIVelocity.swift`
- `Peach/Core/Audio/Cents.swift`
- `Peach/Core/Audio/Frequency.swift`
- `Peach/Core/Audio/AmplitudeDB.swift`
- `PeachTests/Core/Audio/MIDINoteTests.swift`
- `PeachTests/Core/Audio/CentsTests.swift`
- `PeachTests/Core/Audio/FrequencyTests.swift`
- `PeachTests/Core/Audio/MIDIVelocityTests.swift`
- `PeachTests/Core/Audio/AmplitudeDBTests.swift`

**Modified production files (15+):**
- `Peach/Comparison/Comparison.swift`
- `Peach/Comparison/ComparisonSession.swift`
- `Peach/Core/Audio/NotePlayer.swift`
- `Peach/Core/Audio/PlaybackHandle.swift`
- `Peach/Core/Audio/SoundFontNotePlayer.swift`
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift`
- `Peach/Core/Profile/PitchDiscriminationProfile.swift`
- `Peach/Core/Profile/PitchMatchingProfile.swift`
- `Peach/Core/Profile/PerceptualProfile.swift`
- `Peach/Core/Profile/TrendAnalyzer.swift`
- `Peach/Core/Profile/ThresholdTimeline.swift`
- `Peach/Core/Algorithm/NextComparisonStrategy.swift` (TrainingSettings)
- `Peach/Core/Algorithm/KazezNoteStrategy.swift`
- `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift`
- `Peach/Core/Data/TrainingDataStore.swift`
- `Peach/PitchMatching/PitchMatchingSession.swift`
- `Peach/PitchMatching/PitchMatchingChallenge.swift`
- `Peach/App/PeachApp.swift`
- `Peach/Settings/SettingsKeys.swift`

**Modified view files:**
- `Peach/Comparison/ComparisonScreen.swift` (preview mocks)
- `Peach/PitchMatching/PitchMatchingScreen.swift` (preview mocks)
- `Peach/Profile/ProfileScreen.swift` (preview data)
- `Peach/Profile/SummaryStatisticsView.swift` (MIDINote wrapping in computeStats)

**Modified test files (10+):**
- All Comparison test files (constructor changes for signed Cents)
- All Strategy test files (.magnitude for assertions)
- Profile test files (MIDINote wrapping for loop variables)
- All mock files (signature updates)

**NOT modified:**
- `ComparisonRecord.swift`, `PitchMatchingRecord.swift` (SwiftData — raw types stay)
- `FrequencyCalculation.swift` (raw types — callers wrap/unwrap)
- `SF2PresetParser.swift` (separate concern)
- `VerticalPitchSlider.swift` (Story 19.5)

### Key Implementation Patterns

```swift
// Value type pattern (all 5 follow this structure):
struct MIDINote: Hashable, Comparable, Codable, Sendable {
    nonisolated(unsafe) static let validRange = 0...127
    let rawValue: Int

    nonisolated init(_ rawValue: Int) {
        precondition(Self.validRange.contains(rawValue), "MIDI note must be 0-127, got \(rawValue)")
        self.rawValue = rawValue
    }
}

// ExpressibleByIntegerLiteral (on MIDINote, MIDIVelocity, Cents, Frequency, AmplitudeDB):
extension MIDINote: ExpressibleByIntegerLiteral {
    nonisolated init(integerLiteral value: Int) { self.init(value) }
}

// Signed Cents in strategies:
let magnitude = algorithm.computeDifficulty(...)
let signed = Bool.random() ? magnitude : -magnitude
return Comparison(note1: selectedNote, note2: selectedNote, centDifference: Cents(signed))

// SwiftData boundary:
// Writing:
let record = ComparisonRecord(
    note1: comparison.note1.rawValue,
    note2: comparison.note2.rawValue,
    note2CentOffset: comparison.centDifference.rawValue,  // signed, stored directly
    isCorrect: isCorrect
)
// Reading:
profile.update(note: MIDINote(record.note1), centOffset: abs(record.note2CentOffset), isCorrect: record.isCorrect)
```

### Testing Approach

- **New test files (5):** One per Value Object, testing construction, boundary validation, literal conformance, computed properties
- **Existing test updates:** Replace `isSecondNoteHigher:` with signed `Cents`, use `.magnitude` for assertions, wrap loop variables with `MIDINote()`
- **Common pitfall:** `for note in [30, 60, 90]` creates `[Int]` by default — use `for note: MIDINote in [30, 60, 90]` or `for note in [30, 60, 90] { profile.update(note: MIDINote(note), ...) }`
- **`#expect(comparison.centDifference.magnitude == 100.0)`** — strategies produce random sign, so test the absolute value
- **UserDefaults comparisons:** `#expect(settings.noteRangeMin.rawValue == SettingsKeys.defaultNoteRangeMin)`

### Previous Story Learnings (from 19.1 and earlier)

- **`nonisolated` is mandatory for value type inits** — discovered during 19.1 clamping extension and confirmed across multiple value types. Every `init` and `static let` on value types needs explicit opt-out from MainActor isolation.
- **Test file naming mirrors source structure** — `Peach/Core/Audio/MIDINote.swift` → `PeachTests/Core/Audio/MIDINoteTests.swift`
- **Clamping utility from 19.1 available** — `AmplitudeDB` can use `.clamped(to:)` in its init.

### Risk Assessment

- **Largest story in the epic** — touches 25+ files. Recommend implementing in waves: (1) create value types with tests, (2) update protocols and core types, (3) update sessions and strategies, (4) update views and test mocks, (5) fix remaining test compilation errors.
- **Build errors cascade** — a type change in a protocol propagates to all implementations and callers. Expect many compiler errors after changing `NotePlayer`. Work through them file by file.
- **Random sign in strategies may break assertions** — any test that previously asserted `centDifference == 100.0` must now use `.magnitude` since strategies randomly negate.

### Git Intelligence

Recent commit pattern: `Implement story X.Y: {description}`
Commit message: `Implement story 19.2: Value Objects for domain primitives`

### Project Structure Notes

- Value type files go in `Peach/Core/Audio/` alongside `FrequencyCalculation.swift`
- Test files go in `PeachTests/Core/Audio/`
- No new directories needed
- Do NOT create `Peach/Core/Types/` or similar — audio value types belong in `Core/Audio/`

### References

- [Source: docs/project-context.md -- Type Design rules, Testing Rules, Critical Don't-Miss Rules]
- [Source: Peach/Core/Audio/NotePlayer.swift -- Protocol to update]
- [Source: Peach/Core/Audio/PlaybackHandle.swift -- Protocol to update]
- [Source: Peach/Comparison/Comparison.swift -- Struct to redesign]
- [Source: Peach/Core/Algorithm/NextComparisonStrategy.swift -- TrainingSettings struct]
- [Source: Peach/Core/Profile/PitchDiscriminationProfile.swift -- Protocol to update]
- [Source: Peach/Core/Profile/PitchMatchingProfile.swift -- Protocol to update]
- [Source: Peach/Core/Data/ComparisonRecord.swift -- SwiftData model, keep raw types]
- [Source: Peach/Core/Data/PitchMatchingRecord.swift -- SwiftData model, keep raw types]
- [Source: docs/implementation-artifacts/19-1-clamping-utility-and-magic-value-constants.md -- Prerequisite story]

## Change Log

- 2026-02-26: Story created by BMAD create-story workflow from Epic 19 code review plan.
- 2026-02-26: Implementation complete — 5 value objects created, 40+ files updated, all tests pass. Removed dead `AudioError.invalidVelocity`/`invalidAmplitude` enum cases and 4 obsolete runtime validation tests now handled by value object constructors.
- 2026-02-27: Code review fixes — removed all unnecessary `nonisolated`/`nonisolated(unsafe)` from value types (Sendable structs don't need them), deduplicated note naming (PianoKeyboardLayout delegates to MIDINote.name), changed Comparison frequency methods to return `Frequency`, upgraded `PitchMatchingChallenge`/`CompletedPitchMatching` to use `MIDINote`, added `Comparable` to `MIDIVelocity` and `AmplitudeDB`, added `async` to all value object test functions, fixed File List count (19→21). Removed `amplitudeDBRange` constant from 19.1 (subsumed by `AmplitudeDB.validRange`).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Session 1: Tasks 1-12 (value types, protocol updates, session/strategy updates, view updates, mock updates)
- Session 2 (continuation): Tasks 13-15 (test file updates, value object unit tests, full test suite verification)
- Key debug issues resolved:
  - iPhone 16 simulator not found — switched to iPhone 17
  - `ExtensionOnlyNotePlayer` in NotePlayerConvenienceTests had old raw-type signature — updated to value objects
  - Missing `import Foundation` in MIDINoteTests for JSONEncoder/JSONDecoder
  - `for note in 0..<128` loop variable (Int) cannot implicitly convert to MIDINote — wrapped with `MIDINote(note)`
  - `MIDIVelocity(0)` precondition crash in SoundFontNotePlayerTests — removed tests for invalid velocity/amplitude values now enforced by value object constructors
  - Removed dead `AudioError.invalidVelocity` and `AudioError.invalidAmplitude` enum cases

### Completion Notes List

- Created 5 domain-specific value objects: MIDINote, MIDIVelocity, Cents, Frequency, AmplitudeDB
- All value types use `nonisolated init` for ExpressibleByLiteral conformance under Swift 6.2 MainActor isolation
- All `static let` range properties use `nonisolated(unsafe)` as required by the compiler
- `Comparison.centDifference` is now signed Cents (positive = second note higher), `isSecondNoteHigher` is computed
- Strategies produce random sign direction (50/50 chance), test assertions use `.centDifference.magnitude`
- SwiftData @Model types (ComparisonRecord, PitchMatchingRecord) unchanged — conversion at boundaries via `.rawValue`/`MIDINote()`
- FrequencyCalculation keeps raw signatures — callers wrap/unwrap at boundaries
- Removed `AudioError.invalidVelocity` and `AudioError.invalidAmplitude` (validation now in value object constructors)
- Removed 4 SoundFontNotePlayerTests that tested runtime validation now handled by type-level validation
- Full test suite passes with zero regressions

### File List

**New value object files (5):**
- Peach/Core/Audio/MIDINote.swift
- Peach/Core/Audio/MIDIVelocity.swift
- Peach/Core/Audio/Cents.swift
- Peach/Core/Audio/Frequency.swift
- Peach/Core/Audio/AmplitudeDB.swift

**New test files (5):**
- PeachTests/Core/Audio/MIDINoteTests.swift
- PeachTests/Core/Audio/CentsTests.swift
- PeachTests/Core/Audio/FrequencyTests.swift
- PeachTests/Core/Audio/MIDIVelocityTests.swift
- PeachTests/Core/Audio/AmplitudeDBTests.swift

**Modified production files (21):**
- Peach/Core/Audio/NotePlayer.swift
- Peach/Core/Audio/PlaybackHandle.swift
- Peach/Core/Audio/SoundFontNotePlayer.swift
- Peach/Core/Audio/SoundFontPlaybackHandle.swift
- Peach/Comparison/Comparison.swift
- Peach/Comparison/ComparisonSession.swift
- Peach/Core/Algorithm/NextComparisonStrategy.swift
- Peach/Core/Algorithm/KazezNoteStrategy.swift
- Peach/Core/Algorithm/AdaptiveNoteStrategy.swift
- Peach/Core/Profile/PerceptualProfile.swift
- Peach/Core/Profile/PitchDiscriminationProfile.swift
- Peach/Core/Profile/PitchMatchingProfile.swift
- Peach/Core/Profile/TrendAnalyzer.swift
- Peach/Core/Profile/ThresholdTimeline.swift
- Peach/PitchMatching/PitchMatchingSession.swift
- Peach/Core/Data/TrainingDataStore.swift
- Peach/App/PeachApp.swift
- Peach/Comparison/ComparisonScreen.swift
- Peach/PitchMatching/PitchMatchingScreen.swift
- Peach/Profile/ProfileScreen.swift
- Peach/Profile/SummaryStatisticsView.swift

**Modified test/mock files (20):**
- PeachTests/Comparison/ComparisonSessionTests.swift
- PeachTests/Comparison/ComparisonSessionDifficultyTests.swift
- PeachTests/Comparison/ComparisonSessionLoudnessTests.swift
- PeachTests/Comparison/ComparisonSessionResetTests.swift
- PeachTests/Comparison/ComparisonSessionIntegrationTests.swift
- PeachTests/Comparison/ComparisonSessionUserDefaultsTests.swift
- PeachTests/Comparison/MockNextComparisonStrategy.swift
- PeachTests/Comparison/MockNotePlayer.swift
- PeachTests/Comparison/MockTrainingDataStore.swift
- PeachTests/Comparison/ComparisonTestHelpers.swift
- PeachTests/Mocks/MockPlaybackHandle.swift
- PeachTests/Core/Algorithm/KazezNoteStrategyTests.swift
- PeachTests/Core/Algorithm/AdaptiveNoteStrategyTests.swift
- PeachTests/Core/Algorithm/AdaptiveNoteStrategyRegionalTests.swift
- PeachTests/Core/Profile/PerceptualProfileTests.swift
- PeachTests/Core/Profile/ThresholdTimelineTests.swift
- PeachTests/Profile/TrendAnalyzerTests.swift
- PeachTests/Core/Audio/FrequencyCalculationTests.swift
- PeachTests/Core/Audio/NotePlayerConvenienceTests.swift
- PeachTests/Core/Audio/SoundFontNotePlayerTests.swift
- PeachTests/Settings/SettingsTests.swift
- PeachTests/PitchMatching/MockPitchMatchingProfile.swift
- PeachTests/PitchMatching/PitchMatchingSessionTests.swift

**Additional files modified in code review:**
- Peach/PitchMatching/PitchMatchingChallenge.swift (referenceNote: Int → MIDINote)
- Peach/PitchMatching/CompletedPitchMatching.swift (referenceNote: Int → MIDINote)
- Peach/Profile/PianoKeyboardView.swift (noteName delegates to MIDINote.name)

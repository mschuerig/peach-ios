# Story 18.1: Display Pitch Matching Statistics on Profile Screen

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to see my pitch matching accuracy on the Profile Screen alongside my discrimination profile,
So that I can track improvement in both training modes from one place.

## Acceptance Criteria

1. **Matching statistics section added to Profile Screen** -- A new section displays: matching mean absolute error (cents), matching standard deviation (cents), and matching sample count. The section is visually distinct from the discrimination section.

2. **Statistics computed from PitchMatchingProfile** -- When the user has pitch matching data, matching statistics are computed from the `PitchMatchingProfile` protocol properties (`matchingMean`, `matchingStdDev`, `matchingSampleCount`). Values are formatted to a reasonable precision (e.g., 1 decimal place for cents).

3. **Cold start empty state** -- When the user has NO pitch matching data (`matchingSampleCount == 0`), the matching section shows an empty state message like "Start pitch matching to see your accuracy" (localized). No placeholder numbers are shown.

4. **Localized labels** -- All labels and the empty state message are localized in English and German.

5. **Responsive layout** -- When the device is rotated to landscape, the matching statistics section reflows with the existing layout.

6. **All existing tests pass** -- The full test suite passes with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Create `MatchingStatisticsView` subview (AC: #1, #2, #3, #5)
  - [x] Create `Peach/Profile/MatchingStatisticsView.swift` following `SummaryStatisticsView` pattern
  - [x] Read `@Environment(\.perceptualProfile)` for matching data
  - [x] Display three stat items: Mean Error, Std Dev, Sample Count
  - [x] Format mean and stdDev as cents with 1 decimal place (e.g., "12.3 cents", "±5.1 cents")
  - [x] Format sample count as plain integer
  - [x] Handle cold start: show localized empty state message when `matchingSampleCount == 0`
  - [x] Extract `computeMatchingStats` and formatting as `static` methods for testability
  - [x] Add accessibility labels for all stat items and empty state

- [x] Task 2: Integrate `MatchingStatisticsView` into `ProfileScreen` (AC: #1, #5)
  - [x] Add `MatchingStatisticsView()` below `SummaryStatisticsView` in `ProfileScreen.body`
  - [x] Add a section header or visual separator to distinguish the two stat sections
  - [x] Verify layout in portrait and landscape

- [x] Task 3: Add localization strings (AC: #4)
  - [x] Add English + German entries in `Localizable.xcstrings`:
    - "Mean Error" / "Mittlerer Fehler"
    - "Samples" / "Übungen"
    - Matching-specific cents formatting
    - Empty state: "Start pitch matching to see your accuracy" / "Starte Tonhöhenübungen, um deine Genauigkeit zu sehen"

- [x] Task 4: Add unit tests for static methods (AC: #2, #3)
  - [x] Create `PeachTests/Profile/MatchingStatisticsViewTests.swift`
  - [x] Test `computeMatchingStats` with data present
  - [x] Test `computeMatchingStats` returns nil when no matching data
  - [x] Test formatting methods (mean, stdDev, sample count)
  - [x] Test accessibility label generation

- [x] Task 5: Update ProfileScreen previews (AC: #1, #3)
  - [x] Update "With Data" preview to include pitch matching data on the profile
  - [x] Verify "Cold Start" preview shows matching empty state

- [x] Task 6: Run full test suite and verify (AC: #6)
  - [x] Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All existing tests pass plus new MatchingStatisticsView tests

## Dev Notes

### Critical Design Decisions

- **Separate subview, not inline** -- Create `MatchingStatisticsView` as a distinct subview file, following the pattern of `SummaryStatisticsView`. Do NOT inline matching stats into `SummaryStatisticsView` -- they are conceptually different training modes.
- **Read from `PerceptualProfile` directly** -- The `PerceptualProfile` already conforms to `PitchMatchingProfile` and exposes `matchingMean`, `matchingStdDev`, `matchingSampleCount`. These are Welford's algorithm accumulators updated incrementally. No additional computation needed.
- **No trend indicator for matching** -- There is no `TrendAnalyzer` equivalent for pitch matching yet. Do NOT add one. The story scope is mean, stdDev, and sample count only.
- **1 decimal place for cents** -- Discrimination stats use `Int` rounding (e.g., "42 cents"). Matching stats should use 1 decimal place (e.g., "12.3 cents") because matching accuracy is finer-grained and sub-cent precision is meaningful.
- **Sample count displayed** -- Unlike discrimination (which shows trend), matching shows sample count. This gives the user a sense of how much data backs the statistics.

### Architecture & Integration

- **File location:** `Peach/Profile/MatchingStatisticsView.swift` (new subview)
- **Modified files:** `Peach/Profile/ProfileScreen.swift` (adds new subview), `Peach/Resources/Localizable.xcstrings` (adds strings)
- **New test file:** `PeachTests/Profile/MatchingStatisticsViewTests.swift`
- **No new protocols, services, or @Model types**
- **No changes to PeachApp.swift** -- `PerceptualProfile` is already injected via `@Environment(\.perceptualProfile)` and already conforms to `PitchMatchingProfile`

### PitchMatchingProfile API (already implemented)

```swift
protocol PitchMatchingProfile: AnyObject {
    func updateMatching(note: Int, centError: Double)
    var matchingMean: Double? { get }       // Mean absolute error in cents, nil if no data
    var matchingStdDev: Double? { get }     // Std dev of absolute errors, nil if < 2 samples
    var matchingSampleCount: Int { get }    // Total matching exercises completed
    func resetMatching()
}
```

`PerceptualProfile` implements this using Welford's online algorithm:
- `matchingMean` → `matchingCount > 0 ? matchingMeanAbs : nil`
- `matchingStdDev` → requires `matchingCount >= 2`
- `matchingSampleCount` → `matchingCount`

### Existing Code to Reference (DO NOT MODIFY unless specified)

- **`SummaryStatisticsView.swift`** -- The primary pattern reference. Follow its structure: `@Environment` reads, `HStack` with `statItem` helper, `static` methods for computation and formatting, accessibility labels. [Source: Peach/Profile/SummaryStatisticsView.swift]
- **`ProfileScreen.swift`** -- The parent screen. Currently has `ThresholdTimelineView` + `SummaryStatisticsView` in a `VStack`. Add `MatchingStatisticsView` below `SummaryStatisticsView`. [Source: Peach/Profile/ProfileScreen.swift]
- **`PerceptualProfile.swift`** -- The data source. Conforms to `PitchMatchingProfile`. Properties: `matchingMean`, `matchingStdDev`, `matchingSampleCount`. [Source: Peach/Core/Profile/PerceptualProfile.swift]
- **`PitchMatchingProfile.swift`** -- Protocol definition for matching stats. [Source: Peach/Core/Profile/PitchMatchingProfile.swift]

### ProfileScreen Current Structure

```swift
struct ProfileScreen: View {
    @Environment(\.perceptualProfile) private var profile
    @Environment(\.thresholdTimeline) private var timeline
    private let midiRange: ClosedRange<Int> = 36...84

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ThresholdTimelineView()
                .padding(.horizontal)
            SummaryStatisticsView(midiRange: midiRange)
            Spacer()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

Add `MatchingStatisticsView()` after `SummaryStatisticsView(midiRange: midiRange)`. Consider a visual separator (e.g., `Divider()` or spacing) between the two stat sections.

### MatchingStatisticsView Implementation Pattern

Follow `SummaryStatisticsView` structure:

```swift
struct MatchingStatisticsView: View {
    @Environment(\.perceptualProfile) private var profile

    var body: some View {
        // Use profile.matchingMean, profile.matchingStdDev, profile.matchingSampleCount
        // HStack with stat items, or empty state message
    }

    // Static methods for computation, formatting, accessibility
    static func formatMeanError(_ value: Double?) -> String { ... }
    static func formatStdDev(_ value: Double?) -> String { ... }
    static func formatSampleCount(_ count: Int) -> String { ... }
}
```

### Testing Approach

- **New test file:** `PeachTests/Profile/MatchingStatisticsViewTests.swift`
- **Test static methods only** -- formatting, computation, accessibility labels (same pattern as existing tests)
- **Use `@Test` with behavioral descriptions** -- `@Test("formats mean error with one decimal")`, `@Test("returns nil stats when no matching data")`
- **No SwiftUI view tests** -- test the logic, not the rendering
- **Use real `PerceptualProfile` instances** -- create profile, call `updateMatching()` to populate data, then test computed properties

### Localization Strings Required

| Key | English | German |
|-----|---------|--------|
| Mean Error label | "Mean Error" | "Mittlerer Fehler" |
| Std Dev label | "Std Dev" | "Std.-Abw." (reuse existing) |
| Samples label | "Samples" | "Übungen" |
| Cents format (matching) | "%.1f cents" | "%.1f Cent" |
| ± cents format (matching) | "±%.1f cents" | "±%.1f Cent" |
| Empty state | "Start pitch matching to see your accuracy" | "Starte Tonhöhenübungen, um deine Genauigkeit zu sehen" |
| Accessibility: mean error | "Mean matching error: X cents" | "Mittlerer Abgleichfehler: X Cent" |
| Accessibility: samples | "X pitch matching exercises completed" | "X Tonhöhenübungen abgeschlossen" |
| Section header | "Pitch Matching" | "Tonhöhenübung" (reuse existing key) |

### SwiftUI Implementation Patterns

- **`@Observable` -- NEVER `ObservableObject`/`@Published`** (project convention)
- **No explicit `@MainActor`** -- default MainActor isolation project-wide
- **`@Environment` with `@Entry` for DI** -- NEVER `@EnvironmentObject`
- **Extract formatting to `static` methods** for unit testability
- **Use `String(localized:)` for all user-visible text** -- String Catalogs
- **Keep views thin** -- observe state, render; no business logic
- **`dynamicTypeSize(...DynamicTypeSize.accessibility3)`** -- follow SummaryStatisticsView's pattern

### Previous Story Learnings (from 16.3 and earlier)

- **Static method extraction for testability** -- All recent stories extract computation and formatting to `static` methods. Do the same for matching stats.
- **Cold start is a first-class state** -- ProfileScreen and SummaryStatisticsView both handle cold start. MatchingStatisticsView must do the same.
- **No dead code** -- Code review of 16.3 removed unused `isCompactHeight`. Don't add unused responsive layout code.
- **Localization includes German** -- Every user-visible string needs both English and German in `Localizable.xcstrings`.
- **Test count baseline: 535 tests** -- all must continue passing plus new tests.

### Git Intelligence (from recent commits)

Recent commit pattern:
1. `Add story X.Y` -- create story file
2. `Implement story X.Y` -- implement the code
3. `Fix code review findings for X-Y` -- post-review fixes

Files modified in recent epics that are relevant:
- `Peach/Profile/ProfileScreen.swift` (last modified in story 5.3)
- `Peach/Profile/SummaryStatisticsView.swift` (last modified in story 5.2)
- `Peach/Core/Profile/PerceptualProfile.swift` (last modified in story 14.2 -- added matching stats)
- `Peach/Resources/Localizable.xcstrings` (modified in every story)

### Project Structure Notes

- `MatchingStatisticsView.swift` goes in `Peach/Profile/` alongside `SummaryStatisticsView.swift`, `ProfileScreen.swift`
- `MatchingStatisticsViewTests.swift` goes in `PeachTests/Profile/`
- No new directories needed
- No new protocols, services, or dependencies
- No changes to `PeachApp.swift` or composition root

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 18, Story 18.1]
- [Source: docs/planning-artifacts/architecture.md -- Profile Protocol Split, v0.2 matching statistics]
- [Source: docs/project-context.md -- SwiftUI Patterns, Testing Rules, Naming Conventions]
- [Source: Peach/Profile/ProfileScreen.swift -- Parent screen structure]
- [Source: Peach/Profile/SummaryStatisticsView.swift -- Primary pattern reference for statistics display]
- [Source: Peach/Core/Profile/PerceptualProfile.swift -- Data source with matching stats implementation]
- [Source: Peach/Core/Profile/PitchMatchingProfile.swift -- Protocol definition]
- [Source: docs/implementation-artifacts/16-3-pitch-matching-screen-assembly.md -- Previous story learnings]

## Change Log

- 2026-02-26: Implemented story 18.1 — Added MatchingStatisticsView to Profile Screen displaying mean error, std dev, and sample count from PitchMatchingProfile. Added localization (EN/DE), accessibility labels, cold start empty state, and 13 unit tests. Full test suite passes (548 tests).

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Fixed locale-dependent decimal separator issue in tests: used `.formatted(.number.precision(.fractionLength(1)))` instead of hardcoded "12.3" to handle German locale decimal comma.

### Completion Notes List

- Created `MatchingStatisticsView` as a separate subview following `SummaryStatisticsView` pattern
- Three stat items displayed: Mean Error (1 decimal place), Std Dev (±, 1 decimal place), Samples (integer)
- Cold start shows localized empty state message instead of placeholder numbers
- Integrated into `ProfileScreen` with `Divider()` separator between discrimination and matching sections
- Added `dynamicTypeSize(...DynamicTypeSize.accessibility3)` for responsive type support
- All 10 localization keys added with German translations in `Localizable.xcstrings`
- 13 unit tests covering: stats computation (4), formatting (4), accessibility (3), cold start (2)
- Updated ProfileScreen "With Data" preview to include pitch matching data
- Full test suite: all tests pass, zero regressions

### File List

- `Peach/Profile/MatchingStatisticsView.swift` (new)
- `PeachTests/Profile/MatchingStatisticsViewTests.swift` (new)
- `Peach/Profile/ProfileScreen.swift` (modified — added MatchingStatisticsView + Divider, updated preview)
- `Peach/Resources/Localizable.xcstrings` (modified — added 10 localization entries with German translations)
- `docs/implementation-artifacts/sprint-status.yaml` (modified — status: in-progress → review)
- `docs/implementation-artifacts/18-1-display-pitch-matching-statistics-on-profile-screen.md` (modified — tasks marked complete, Dev Agent Record updated)

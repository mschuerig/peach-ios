# Story 16.3: Pitch Matching Screen Assembly

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want a complete Pitch Matching Screen that assembles the slider, feedback, and navigation,
So that I can do a full pitch matching training session with the same navigation patterns as comparison training.

## Acceptance Criteria

1. **SwiftUI screen observing PitchMatchingSession** -- `PitchMatchingScreen` is a SwiftUI view at `PitchMatching/PitchMatchingScreen.swift` that reads `PitchMatchingSession` from `@Environment(\.pitchMatchingSession)`. It contains: `VerticalPitchSlider`, `PitchMatchingFeedbackIndicator`, Settings button, Profile button.

2. **Session auto-starts on appear** -- When the screen appears, `pitchMatchingSession.startPitchMatching()` is called. When the screen disappears, `pitchMatchingSession.stop()` is called. Same `.onAppear`/`.onDisappear` pattern as `ComparisonScreen`.

3. **Slider inactive during reference** -- When `session.state == .playingReference`, the `VerticalPitchSlider` is visible but `isActive = false` (disabled, dimmed). The feedback indicator is hidden.

4. **Slider active during tunable** -- When `session.state == .playingTunable`, the `VerticalPitchSlider` is `isActive = true`. The screen calls `session.adjustFrequency()` via the slider's `onFrequencyChange` callback. The `referenceFrequency` is passed from `session.referenceFrequency` (must be changed from `private` to `private(set)` -- see Dev Notes).

5. **Release commits result** -- When the user releases the slider (`onRelease`), the screen calls `session.commitResult(userFrequency:)` with the final frequency.

6. **Feedback overlay** -- When `session.state == .showingFeedback`, `PitchMatchingFeedbackIndicator(centError: session.lastResult?.userCentError)` is shown as a centered `.overlay` with `.transition(.opacity)`. Animation controlled by `accessibilityReduceMotion` (nil if reduce motion, `.easeInOut(duration: 0.2)` otherwise). Same pattern as `ComparisonScreen`.

7. **Navigation toolbar** -- Settings (gearshape) and Profile (chart.xyaxis.line) buttons in a trailing `ToolbarItem`, same as `ComparisonScreen`. Both are `NavigationLink`s that navigate to `.settings` and `.profile` respectively. Session stops automatically via `.onDisappear`.

8. **Responsive layout** -- Uses `@Environment(\.verticalSizeClass)` to detect compact height. Slider remains vertical in both orientations. Layout adapts for landscape (reduced height).

9. **Environment wiring in PeachApp.swift** -- `PitchMatchingSession` is created in `PeachApp.init()` using the shared `notePlayer`, `profile` (as `PitchMatchingProfile`), and appropriate observers (`[dataStore, profile]`). Injected via `.environment(\.pitchMatchingSession, pitchMatchingSession)`.

10. **Navigation routing** -- Add `.pitchMatching` case to `NavigationDestination`. Add routing in `StartScreen`'s `.navigationDestination(for:)`. Add "Pitch Matching" button on `StartScreen` below "Start Training" with secondary prominence (`.bordered` style, not `.borderedProminent`).

11. **App lifecycle handling** -- `ContentView` stops `pitchMatchingSession` on app backgrounding, same as it does for `comparisonSession`. On foregrounding, navigation returns to Start Screen (already handled by clearing `navigationPath`).

12. **Tests pass** -- All existing tests pass (537 baseline). No new unit tests required for the screen itself (SwiftUI rendering concern), but the wiring and navigation additions must not break existing tests.

## Tasks / Subtasks

- [x] Task 1: Define `@Entry var pitchMatchingSession` environment key (AC: #1, #9)
  - [x] Add `@Entry var pitchMatchingSession` in an `extension EnvironmentValues` inside `PitchMatchingScreen.swift`
  - [x] Default value creates a preview mock (same pattern as `ComparisonScreen`'s `@Entry var comparisonSession`)
  - [x] Create private `MockNotePlayerForPitchMatchingPreview`, `MockPlaybackHandleForPitchMatchingPreview` (minimal implementations for previews)

- [x] Task 2: Create `PitchMatchingScreen` view (AC: #1, #2, #3, #4, #5, #6, #7, #8)
  - [x] Define struct with `@Environment(\.pitchMatchingSession)`, `@Environment(\.accessibilityReduceMotion)`, `@Environment(\.verticalSizeClass)`
  - [x] Compute `isCompactHeight` from `verticalSizeClass == .compact`
  - [x] Change `PitchMatchingSession.referenceFrequency` from `private` to `private(set)` (line 37 of `PitchMatchingSession.swift`)
  - [x] Body: `VerticalPitchSlider` with `isActive: session.state == .playingTunable`, `referenceFrequency: session.referenceFrequency ?? 440.0`, callbacks wired to session
  - [x] `.overlay` with `PitchMatchingFeedbackIndicator` shown when `session.state == .showingFeedback`
  - [x] `.transition(.opacity)` and `.animation(feedbackAnimation, value: session.state == .showingFeedback)`
  - [x] `.navigationTitle("Pitch Matching")` and `.navigationBarTitleDisplayMode(.inline)`
  - [x] `.toolbar` with Settings + Profile `NavigationLink`s (matching `ComparisonScreen` exactly)
  - [x] `.onAppear { pitchMatchingSession.startPitchMatching() }`
  - [x] `.onDisappear { pitchMatchingSession.stop() }`
  - [x] Extract `static func feedbackAnimation(reduceMotion: Bool) -> Animation?` for testability

- [x] Task 3: Wire `PitchMatchingSession` in `PeachApp.swift` (AC: #9)
  - [x] Add `@State private var pitchMatchingSession: PitchMatchingSession` property
  - [x] In `init()`, create `PitchMatchingSession(notePlayer: notePlayer, profile: profile, observers: [dataStore, profile])`
  - [x] Add `.environment(\.pitchMatchingSession, pitchMatchingSession)` to `ContentView()`
  - [x] Note: NO `HapticFeedbackManager` observer for pitch matching (no haptics -- UX spec decision)

- [x] Task 4: Add `.pitchMatching` navigation destination (AC: #10)
  - [x] Add `case pitchMatching` to `NavigationDestination` enum
  - [x] Add routing in `StartScreen`'s `.navigationDestination(for:)`: `.pitchMatching -> PitchMatchingScreen()`

- [x] Task 5: Add "Pitch Matching" button to `StartScreen` (AC: #10)
  - [x] Add `NavigationLink(value: NavigationDestination.pitchMatching)` below "Start Training"
  - [x] Style: `.bordered` (secondary prominence, not `.borderedProminent`)
  - [x] Label: "Pitch Matching" text with `waveform` SF Symbol icon
  - [x] Position: below Start Training, clearly visible but visually subordinate

- [x] Task 6: Handle `PitchMatchingSession` in app lifecycle (AC: #11)
  - [x] In `ContentView`, read `@Environment(\.pitchMatchingSession)`
  - [x] In the `.onChange(of: scenePhase)` handler, call `pitchMatchingSession.stop()` alongside `comparisonSession.stop()` on backgrounding

- [x] Task 7: Add SwiftUI previews for `PitchMatchingScreen` (AC: #1)
  - [x] Preview wrapped in `NavigationStack`

- [x] Task 8: Add localization strings (AC: #7, #10)
  - [x] "Pitch Matching" navigation title -- English + German ("Tonhöhenübung") in `Localizable.xcstrings`
  - [x] "Pitch Matching" button label on StartScreen -- same key, shared with navigation title

- [x] Task 9: Run full test suite and verify (AC: #12)
  - [x] Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All 537 tests pass (0 failures)
  - [x] Manual preview verification of PitchMatchingScreen in portrait and landscape

## Dev Notes

### Critical Design Decisions

- **"Listen. Search. Release."** -- The core interaction metaphor. Reference note plays (listen), tunable note auto-starts and user drags slider (search), slider release commits the result (release). No separate submit button.
- **No visual feedback during tuning** -- The slider track is deliberately blank. The user tunes purely by ear. Do NOT add any proximity indicators, meter readouts, or visual cues during the `playingTunable` state.
- **No haptic feedback** -- Unlike comparison training (haptic on incorrect), pitch matching is purely visual. Do NOT add `HapticFeedbackManager` to the pitch matching observers array.
- **Auto-start tunable note** -- The tunable note begins playing immediately when the reference note ends. There is no "waiting for touch" state. This is a deliberate training design: the moment after the reference note stops is the highest-value training window.
- **Same feedback timing** -- 400ms feedback display, managed by `PitchMatchingSession`'s state machine, not by the screen.
- **Secondary prominence on Start Screen** -- Pitch Matching button uses `.bordered` style, not `.borderedProminent`. Start Training retains hero status.

### Architecture & Integration

- **File location:** `Peach/PitchMatching/PitchMatchingScreen.swift`
- **This is a screen view** -- it observes `PitchMatchingSession` via `@Environment` and composes `VerticalPitchSlider` + `PitchMatchingFeedbackIndicator`. It contains NO business logic.
- **Changes PeachApp.swift** -- adds `PitchMatchingSession` creation and environment injection.
- **Changes NavigationDestination.swift** -- adds `.pitchMatching` case.
- **Changes StartScreen.swift** -- adds "Pitch Matching" button and `.pitchMatching` routing.
- **Changes ContentView.swift** -- stops `pitchMatchingSession` on backgrounding.
- **Changes Localizable.xcstrings** -- adds "Pitch Matching" title and button strings.

### How to Wire the Slider to the Session

```swift
VerticalPitchSlider(
    isActive: pitchMatchingSession.state == .playingTunable,
    referenceFrequency: pitchMatchingSession.referenceFrequency ?? 440.0,
    onFrequencyChange: { frequency in
        pitchMatchingSession.adjustFrequency(frequency)
    },
    onRelease: { frequency in
        pitchMatchingSession.commitResult(userFrequency: frequency)
    }
)
```

**CRITICAL: `referenceFrequency` access** -- `PitchMatchingSession.referenceFrequency` is currently `private`. The slider needs this value. Change it to `private(set) var referenceFrequency: Double?` (internal read, private write) to match the pattern of `state`, `currentChallenge`, and `lastResult` which are all `private(set)`. This is a one-line change in `PitchMatchingSession.swift` line 37. `PitchMatchingChallenge` only has `referenceNote: Int` and `initialCentOffset: Double` -- no computed frequency property.

### How to Wire the Feedback Overlay

```swift
.overlay {
    if pitchMatchingSession.state == .showingFeedback {
        PitchMatchingFeedbackIndicator(
            centError: pitchMatchingSession.lastResult?.userCentError
        )
        .transition(.opacity)
    }
}
.animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchMatchingSession.state == .showingFeedback)
```

### PitchMatchingSession Public API (already implemented)

```swift
@Observable final class PitchMatchingSession {
    var state: PitchMatchingSessionState = .idle        // .idle, .playingReference, .playingTunable, .showingFeedback
    var currentChallenge: PitchMatchingChallenge?       // Set when a challenge begins
    var lastResult: CompletedPitchMatching?             // Set after slider release

    func startPitchMatching()                           // Guards .idle, starts the loop
    func adjustFrequency(_ frequency: Double)           // Guards .playingTunable, updates handle
    func commitResult(userFrequency: Double)            // Guards .playingTunable, stops note, records result
    func stop()                                         // Guards not .idle, stops everything
}
```

### PeachApp.swift Wiring Pattern

Follow the exact pattern for `ComparisonSession` creation. Key differences:
- **No strategy** -- pitch matching uses random note selection, no `NextComparisonStrategy`
- **No haptic manager** -- no haptics for pitch matching
- **Observers: `[dataStore, profile]`** -- `TrainingDataStore` persists records, `PerceptualProfile` updates matching statistics
- **Same `notePlayer`** -- share the single `SoundFontNotePlayer` instance (both sessions are never active simultaneously)

```swift
// In PeachApp.init():
let pitchMatchingSession = PitchMatchingSession(
    notePlayer: notePlayer,
    profile: profile,
    observers: [dataStore, profile]
)
self._pitchMatchingSession = State(initialValue: pitchMatchingSession)

// In body:
ContentView()
    .environment(\.pitchMatchingSession, pitchMatchingSession)
    // ... existing environment injections
```

### Environment Key Pattern

Define in `PitchMatchingScreen.swift` (same pattern as `ComparisonScreen.swift`):

```swift
extension EnvironmentValues {
    @Entry var pitchMatchingSession: PitchMatchingSession = {
        // Minimal preview mock -- never used in production
        return PitchMatchingSession(
            notePlayer: MockNotePlayerForPreview(),
            profile: PerceptualProfile(),
            observers: []
        )
    }()
}
```

Create private preview mocks at the bottom of the file (same pattern as `ComparisonScreen.swift`).

### ContentView Lifecycle Update

Read `pitchMatchingSession` from environment in `ContentView` and stop it alongside `comparisonSession` in the `.onChange(of: scenePhase)` handler:

```swift
@Environment(\.pitchMatchingSession) private var pitchMatchingSession

// In onChange(of: scenePhase):
case .background:
    comparisonSession.stop()
    pitchMatchingSession.stop()
```

### StartScreen Button and Routing

Add the Pitch Matching button below Start Training. Follow the existing button styling pattern:

```swift
// In navigationDestination(for:):
case .pitchMatching:
    PitchMatchingScreen()

// Button:
NavigationLink(value: NavigationDestination.pitchMatching) {
    Label("Pitch Matching", systemImage: "slider.vertical.3")
}
.buttonStyle(.bordered)
```

Choose an appropriate SF Symbol for the button label. `slider.vertical.3` or `waveform` or `tuningfork` are candidates -- check what looks best. The UX spec doesn't prescribe a specific icon.

### Existing Code to Reference (DO NOT MODIFY unless specified)

- **`ComparisonScreen.swift`** -- The primary pattern reference. Follow its structure exactly: environment reads, `isCompactHeight`, body structure, feedback overlay, navigation toolbar, `.onAppear`/`.onDisappear`, static layout methods, environment key definition, preview mocks. [Source: Peach/Comparison/ComparisonScreen.swift]
- **`VerticalPitchSlider.swift`** -- Story 16.1 component. Takes `isActive`, `referenceFrequency`, `onFrequencyChange`, `onRelease`. [Source: Peach/PitchMatching/VerticalPitchSlider.swift]
- **`PitchMatchingFeedbackIndicator.swift`** -- Story 16.2 component. Takes `centError: Double?`. [Source: Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift]
- **`PitchMatchingSession.swift`** -- State machine. Public API: `startPitchMatching()`, `adjustFrequency(_:)`, `commitResult(userFrequency:)`, `stop()`. Observable: `state`, `currentChallenge`, `lastResult`. [Source: Peach/PitchMatching/PitchMatchingSession.swift]
- **`PitchMatchingChallenge.swift`** -- Value type with `referenceNote: Int`, `initialCentOffset: Double`. Check for a `referenceFrequency` computed property. [Source: Peach/PitchMatching/PitchMatchingChallenge.swift]
- **`CompletedPitchMatching.swift`** -- Result type with `userCentError: Double`. [Source: Peach/PitchMatching/CompletedPitchMatching.swift]
- **`PeachApp.swift`** -- Composition root. Add `PitchMatchingSession` creation and injection here. [Source: Peach/App/PeachApp.swift]
- **`NavigationDestination.swift`** -- Add `.pitchMatching` case. [Source: Peach/App/NavigationDestination.swift]
- **`StartScreen.swift`** -- Add Pitch Matching button and routing. [Source: Peach/Start/StartScreen.swift]
- **`ContentView.swift`** -- Add `pitchMatchingSession.stop()` on backgrounding. [Source: Peach/App/ContentView.swift]

### SwiftUI Implementation Patterns

- **Use `@Observable` -- NEVER `ObservableObject`/`@Published`** (project convention)
- **No explicit `@MainActor` annotations** -- default MainActor isolation is project-wide
- **`@Environment` with `@Entry` for DI** -- NEVER `@EnvironmentObject` or manual `EnvironmentKey` structs
- **Extract layout parameters to `static` methods** for unit testability
- **Use `String(localized:)` for all user-visible text** -- String Catalogs
- **Keep the view thin** -- observe state, render, send actions; no business logic
- **`NavigationLink(value:)` for type-safe navigation** -- no string-based navigation
- **`.navigationTitle()` and `.navigationBarTitleDisplayMode(.inline)`**
- **Toolbar items in `ToolbarItem(placement: .navigationBarTrailing)`** with `HStack(spacing: 20)`

### Testing Approach

- No new unit tests required for `PitchMatchingScreen` itself (SwiftUI rendering concern)
- Static layout methods (e.g., `feedbackAnimation`) can be tested if extracted
- The primary verification is that all 537+ existing tests still pass after wiring changes
- Manual verification via SwiftUI previews in portrait and landscape
- Verify navigation flow: Start Screen -> Pitch Matching -> Settings/Profile -> back to Start Screen

### Previous Story Learnings (from 16.1 and 16.2)

- **Extracted static methods for testability** -- Stories 16.1 and 16.2 both extracted classification and layout logic to `static` methods. Follow this for any layout parameters.
- **`import Foundation` needed in test file** -- discovered in 16.1. Not directly relevant here (no new test file), but keep in mind.
- **Localization for accessibility labels** -- Stories 16.1 and 16.2 added German translations. This story must add German translations for "Pitch Matching" title and button label.
- **Test count baseline: 537 tests** -- all must continue passing.
- **`PitchMatchingFeedbackIndicator` integration pattern** -- Story 16.2 documented the exact overlay wiring code for 16.3 to use. See "How PitchMatchingScreen Will Use This Component" in 16.2 story.
- **`VerticalPitchSlider` callback API** -- Story 16.1 documented the exact callback-based API: `onFrequencyChange` for continuous updates, `onRelease` for final frequency.
- **Code review added `dragResult` to slider** -- Review of 16.1 extracted a `dragResult` static method and added a VoiceOver "Submit pitch" action. These are already in the codebase.
- **Code review nested `FeedbackBand` inside struct** -- Review of 16.2 nested the `FeedbackBand` enum inside `PitchMatchingFeedbackIndicator`. This is already in the codebase.

### Git Intelligence (from recent commits)

Recent commit pattern for this epic:
1. `Add story X.Y` -- create story file
2. `Implement story X.Y` -- implement the code
3. `Fix code review findings for X-Y` -- post-review fixes

Files modified in 16.1 and 16.2 that this story builds on:
- `Peach/PitchMatching/VerticalPitchSlider.swift` (16.1, new)
- `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` (16.2, new)
- `Peach/Resources/Localizable.xcstrings` (16.1 + 16.2, modified)

Files this story will modify:
- `Peach/PitchMatching/PitchMatchingScreen.swift` (new)
- `Peach/PitchMatching/PitchMatchingSession.swift` (modified -- `referenceFrequency` visibility)
- `Peach/App/PeachApp.swift` (modified)
- `Peach/App/NavigationDestination.swift` (modified)
- `Peach/Start/StartScreen.swift` (modified)
- `Peach/App/ContentView.swift` (modified)
- `Peach/Resources/Localizable.xcstrings` (modified)

### Project Structure Notes

- `PitchMatchingScreen.swift` goes in `Peach/PitchMatching/` alongside `VerticalPitchSlider.swift`, `PitchMatchingFeedbackIndicator.swift`, `PitchMatchingSession.swift`
- No new test file needed (screen is a SwiftUI view with no testable logic beyond static methods)
- No new protocols, services, or `@Model` types
- No new dependencies
- Changes to `PitchMatchingSession.swift`: change `private var referenceFrequency` to `private(set) var referenceFrequency` (one-line change)
- Changes to `PeachApp.swift`: add `PitchMatchingSession` `@State` property, create in `init()`, inject via `.environment()`
- Changes to `NavigationDestination.swift`: add `.pitchMatching` case
- Changes to `StartScreen.swift`: add "Pitch Matching" button, add `.pitchMatching` routing
- Changes to `ContentView.swift`: read `pitchMatchingSession` from environment, stop on backgrounding
- Changes to `Localizable.xcstrings`: add "Pitch Matching" strings (English + German)

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 16, Story 16.3]
- [Source: docs/planning-artifacts/ux-design-specification.md -- Pitch Matching Screen, Navigation Patterns, Responsive Layout, Start Screen Button Hierarchy]
- [Source: docs/planning-artifacts/architecture.md -- v0.2 Architecture Amendment, PitchMatchingSession, Navigation, Composition Root]
- [Source: docs/project-context.md -- SwiftUI Patterns, Testing Patterns, Environment Injection, Naming Conventions]
- [Source: Peach/Comparison/ComparisonScreen.swift -- Primary pattern reference for screen structure, environment key, toolbar, feedback overlay]
- [Source: Peach/PitchMatching/PitchMatchingSession.swift -- State machine API, observable properties]
- [Source: Peach/PitchMatching/VerticalPitchSlider.swift -- Slider component API (isActive, referenceFrequency, callbacks)]
- [Source: Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift -- Feedback component API (centError)]
- [Source: Peach/PitchMatching/PitchMatchingChallenge.swift -- Challenge value type]
- [Source: Peach/PitchMatching/CompletedPitchMatching.swift -- Result value type with userCentError]
- [Source: Peach/App/PeachApp.swift -- Composition root, environment injection pattern]
- [Source: Peach/App/NavigationDestination.swift -- Navigation enum]
- [Source: Peach/Start/StartScreen.swift -- Button layout, navigation routing]
- [Source: Peach/App/ContentView.swift -- App lifecycle handling, backgrounding]
- [Source: docs/implementation-artifacts/16-1-vertical-pitch-slider-component.md -- Previous story learnings]
- [Source: docs/implementation-artifacts/16-2-pitch-matching-feedback-indicator.md -- Previous story learnings, integration pattern]

## Change Log

- 2026-02-26: Implemented story 16.3 — Pitch Matching Screen Assembly. Created PitchMatchingScreen view, wired PitchMatchingSession in PeachApp, added navigation routing and Start Screen button, added app lifecycle handling, added English + German localization. All 537 tests pass.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Created `PitchMatchingScreen.swift` following `ComparisonScreen` pattern exactly: environment key with `@Entry`, preview mocks, slider + feedback overlay composition, navigation toolbar, `.onAppear`/`.onDisappear` lifecycle
- Changed `PitchMatchingSession.referenceFrequency` from `private` to `private(set)` for slider read access
- Wired `PitchMatchingSession` in `PeachApp.swift` with `[dataStore, profile]` observers (no haptics per design)
- Added `.pitchMatching` to `NavigationDestination` enum
- Added "Pitch Matching" button with `.bordered` style and `waveform` SF Symbol on Start Screen
- Added `pitchMatchingSession.stop()` to `ContentView` background handler
- Added "Pitch Matching" / "Tonhöhenübung" localization entry
- All 537 existing tests pass with zero regressions

### File List

- `Peach/PitchMatching/PitchMatchingScreen.swift` (new)
- `Peach/PitchMatching/PitchMatchingSession.swift` (modified — `referenceFrequency` visibility)
- `Peach/App/PeachApp.swift` (modified — session creation and environment injection)
- `Peach/App/NavigationDestination.swift` (modified — `.pitchMatching` case)
- `Peach/Start/StartScreen.swift` (modified — button and routing)
- `Peach/App/ContentView.swift` (modified — lifecycle handling)
- `Peach/Resources/Localizable.xcstrings` (modified — "Pitch Matching" strings)
- `docs/implementation-artifacts/16-3-pitch-matching-screen-assembly.md` (modified — task completion)
- `docs/implementation-artifacts/sprint-status.yaml` (modified — status update)

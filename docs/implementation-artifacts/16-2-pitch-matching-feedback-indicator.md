# Story 16.2: Pitch Matching Feedback Indicator

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to see a brief directional arrow and cent offset after each pitch matching attempt,
So that I know how close I was and in which direction I erred — without judgment.

## Acceptance Criteria

1. **Custom SwiftUI view** — `PitchMatchingFeedbackIndicator` is a SwiftUI view at `PitchMatching/PitchMatchingFeedbackIndicator.swift`. It takes a `centError: Double?` parameter (nil = no feedback to show).

2. **Dead center display** — When `centError` is approximately 0 cents, a green dot (`circle.fill` SF Symbol) is shown in system green with text "0 cents".

3. **Close match display (< 10 cents)** — When the absolute cent error is > 0 and < 10, a short arrow (`arrow.up` for positive/sharp, `arrow.down` for negative/flat) is shown in system green with the signed offset text (e.g., "+4 cents", "-3 cents").

4. **Moderate match display (10–30 cents)** — When the absolute cent error is 10–30, a medium-sized arrow (matching direction) is shown in system yellow with signed offset text.

5. **Far off display (> 30 cents)** — When the absolute cent error exceeds 30, a large arrow (matching direction) is shown in system red with signed offset text.

6. **Transition and timing** — The indicator uses `.transition(.opacity)`, same as `ComparisonFeedbackIndicator`. Display duration (~400ms) is managed by `PitchMatchingSession`'s state machine, not by this component.

7. **VoiceOver support** — The indicator announces results verbally: "4 cents sharp", "27 cents flat", or "Dead center". Uses `.accessibilityRemoveTraits(.isImage)` like `ComparisonFeedbackIndicator`.

8. **No haptic feedback** — Pitch matching feedback is purely visual. No haptic vibration occurs (UX spec decision).

9. **Tests pass** — All existing tests pass. New tests verify: correct arrow direction and color for each band, cent offset text formatting, green dot for dead center, band threshold boundaries (0, 10, 30), VoiceOver label generation, nil centError shows nothing.

## Tasks / Subtasks

- [ ] Task 1: Create `PitchMatchingFeedbackIndicator` view (AC: #1, #2, #3, #4, #5, #6)
  - [ ] Define view struct with `centError: Double?` parameter and configurable `iconSize: CGFloat`
  - [ ] Implement `FeedbackBand` classification: `deadCenter`, `close`, `moderate`, `far` — extract to `static func band(centError: Double) -> FeedbackBand`
  - [ ] Render green dot (`circle.fill`) for dead center
  - [ ] Render directional arrows (`arrow.up`/`arrow.down`) with size varying by band (short/medium/long)
  - [ ] Apply system colors: `.green` for dead center and close, `.yellow` for moderate, `.red` for far
  - [ ] Display signed cent offset text below icon (e.g., "+4 cents", "-3 cents", "0 cents")
  - [ ] Extract text formatting to `static func centOffsetText(centError: Double) -> String`
  - [ ] Extract arrow SF Symbol name to `static func arrowSymbolName(centError: Double) -> String`
  - [ ] Extract color to `static func feedbackColor(band: FeedbackBand) -> Color`
- [ ] Task 2: Add VoiceOver accessibility (AC: #7)
  - [ ] Set combined accessibility label via `static func accessibilityLabel(centError: Double) -> String`
  - [ ] Format: "4 cents sharp", "27 cents flat", "Dead center"
  - [ ] Apply `.accessibilityRemoveTraits(.isImage)` — same pattern as `ComparisonFeedbackIndicator`
  - [ ] Add `.accessibilityElement(children: .combine)` to group icon + text as single element
- [ ] Task 3: Add localization strings (AC: #7)
  - [ ] Add English and German strings to `Localizable.xcstrings` for: "cents sharp", "cents flat", "Dead center", "0 cents", "cents"
- [ ] Task 4: Write tests for `PitchMatchingFeedbackIndicator` (AC: #9)
  - [ ] Test `band()` returns `.deadCenter` for 0.0
  - [ ] Test `band()` returns `.close` for errors 0 < |e| < 10
  - [ ] Test `band()` returns `.moderate` for errors 10 <= |e| <= 30
  - [ ] Test `band()` returns `.far` for errors |e| > 30
  - [ ] Test exact boundary values: 0.0, 9.99, 10.0, 30.0, 30.01
  - [ ] Test arrow direction: positive centError → `arrow.up`, negative → `arrow.down`, zero → `circle.fill`
  - [ ] Test colors: green for deadCenter/close, yellow for moderate, red for far
  - [ ] Test `centOffsetText()` formatting: "+4 cents", "-3 cents", "0 cents"
  - [ ] Test `centOffsetText()` rounds to nearest integer
  - [ ] Test `accessibilityLabel()`: "4 cents sharp", "27 cents flat", "Dead center"
  - [ ] Test nil centError produces no view content
- [ ] Task 5: Add SwiftUI previews
  - [ ] Preview for dead center (0 cents)
  - [ ] Preview for close match (+4 cents)
  - [ ] Preview for moderate miss (-22 cents)
  - [ ] Preview for far off (+55 cents)
  - [ ] Preview for nil (no feedback)

## Dev Notes

### Critical Design Decisions

- **Arrow length is categorical, not proportional** — Short/medium/long maps to three bands. The signed cent offset text provides exact detail. Do NOT scale arrow size linearly with cent error.
- **"Dead center" threshold** — Define as exactly 0 when rounded to nearest integer (i.e., `abs(centError).rounded() == 0`). The UX spec says "approximately 0 cents" — rounding to integer is the practical boundary.
- **No visual feedback during tuning** — This indicator appears ONLY after slider release, during the `showingFeedback` state. Never during `playingReference` or `playingTunable`.
- **Same screen position and transition as comparison feedback** — Centered on screen, `.transition(.opacity)`, same visual weight. The two feedback patterns never appear on the same screen.
- **No haptic feedback** — Unlike comparison training (haptic on incorrect), pitch matching is purely visual. This is a deliberate UX decision documented in the spec.

### Architecture & Integration

- **File location:** `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift`
- **Test location:** `PeachTests/PitchMatching/PitchMatchingFeedbackIndicatorTests.swift`
- **This is a standalone UI component** — it does NOT observe `PitchMatchingSession` directly. It receives `centError: Double?` as a parameter. The parent `PitchMatchingScreen` (Story 16.3) will wire it to `session.lastResult?.userCentError`.
- **Pattern match:** Follows the exact same component architecture as `ComparisonFeedbackIndicator` — a thin view struct that takes data, renders it, and has static methods for testable logic.
- **No changes to `PeachApp.swift`** — this is a pure view component; wiring happens in Story 16.3.
- **No new protocols, services, or `@Model` types** — purely a SwiftUI view.

### How `PitchMatchingScreen` (Story 16.3) Will Use This Component

```swift
.overlay {
    if pitchMatchingSession.state == .showingFeedback {
        PitchMatchingFeedbackIndicator(
            centError: pitchMatchingSession.lastResult?.userCentError
        )
        .transition(.opacity)
    }
}
.animation(feedbackAnimation, value: pitchMatchingSession.state == .showingFeedback)
```

The `PitchMatchingSession` already exposes:
- `state: PitchMatchingSessionState` — check for `.showingFeedback`
- `lastResult: CompletedPitchMatching?` — contains `userCentError: Double`

### Band Classification Logic

| Band | Condition (on rounded integer) | SF Symbol | Color | Arrow Size |
|---|---|---|---|---|
| Dead center | `rounded == 0` | `circle.fill` | `.green` | Default icon size |
| Close | `0 < rounded < 10` | `arrow.up` / `arrow.down` | `.green` | Small (~40pt) |
| Moderate | `10 <= rounded <= 30` | `arrow.up` / `arrow.down` | `.yellow` | Medium (~70pt) |
| Far | `rounded > 30` | `arrow.up` / `arrow.down` | `.red` | Large (~100pt, matches `ComparisonFeedbackIndicator.defaultIconSize`) |

Arrow direction: positive `centError` = sharp = `arrow.up`; negative = flat = `arrow.down`.

### Text Formatting

- Round `centError` to nearest integer for display
- Positive: "+4 cents" (include `+` sign)
- Negative: "-3 cents" (sign is natural)
- Zero: "0 cents" (no sign)
- Use `String(localized:)` for the "cents" unit — needs localization

### Existing Code to Reference (DO NOT MODIFY)

- **`ComparisonFeedbackIndicator.swift`** — Analogous component. Follow its pattern exactly: `let` parameter, optional `iconSize`, `static` helper for accessibility label, previews. [Source: Peach/Comparison/ComparisonFeedbackIndicator.swift]
- **`CompletedPitchMatching.swift`** — The `userCentError` property is what this indicator displays. Positive = sharp, negative = flat. [Source: Peach/PitchMatching/CompletedPitchMatching.swift]
- **`PitchMatchingSession.swift`** — The `state` and `lastResult` properties drive feedback display. [Source: Peach/PitchMatching/PitchMatchingSession.swift]
- **`ComparisonScreen.swift`** — Shows how feedback overlay is wired: `.overlay { if showFeedback { ... } }` with `.transition(.opacity)` and `.animation()`. [Source: Peach/Comparison/ComparisonScreen.swift:46-55]

### SwiftUI Implementation Patterns

- **Use `@Observable` — NEVER `ObservableObject`/`@Published`** (project convention)
- **No explicit `@MainActor` annotations** — default MainActor isolation is project-wide
- **Extract all classification and formatting logic to `static` methods** for unit testability
- **Use `.font(.system(size:))` for arrow sizing** — same approach as `ComparisonFeedbackIndicator`
- **Use `String(localized:)` for all user-visible text** — project uses String Catalogs
- **Use `.accessibilityRemoveTraits(.isImage)` on SF Symbol Images** — same as `ComparisonFeedbackIndicator`
- **Keep the view thin** — only rendering; classification logic lives in static methods

### Testing Approach

- **Swift Testing only** — `@Test("behavioral description")`, `@Suite`, `#expect()`
- **Every `@Test` function must be `async`**
- **No `test` prefix** — name describes behavior: `func returnsDeadCenterBandForZeroCentError()`
- **Extract all logic to `static` methods** so tests verify band classification, text formatting, symbol name, color, and accessibility label without instantiating SwiftUI views
- **Key static methods to test:**
  - `static func band(centError: Double) -> FeedbackBand`
  - `static func centOffsetText(centError: Double) -> String`
  - `static func arrowSymbolName(centError: Double) -> String`
  - `static func feedbackColor(band: FeedbackBand) -> Color`
  - `static func accessibilityLabel(centError: Double) -> String`

### Previous Story Learnings (from 16.1)

- **Extracted static methods for testability** — Story 16.1 extracted `centOffset()`, `frequency()`, `thumbPosition()` as static methods. Follow the same pattern here for `band()`, `centOffsetText()`, `arrowSymbolName()`, `feedbackColor()`, `accessibilityLabel()`.
- **`import Foundation` needed in test file** for math functions — discovered in 16.1.
- **Type inference issues with numeric literals** — Story 16.1 hit `Int128` ambiguity with `abs(pos - 0)`. Avoid similar patterns; be explicit with types.
- **Localization for accessibility labels** — Story 16.1 added German translations for "Pitch adjustment slider" / "Tonhöhenregler". This story must similarly add German translations for all new localized strings.
- **Test count baseline: 501 tests** — all must continue passing.

### Project Structure Notes

- File goes in `Peach/PitchMatching/` alongside `VerticalPitchSlider.swift`, `PitchMatchingSession.swift`, `PitchMatchingChallenge.swift`, `CompletedPitchMatching.swift`, `PitchMatchingObserver.swift`
- Tests go in `PeachTests/PitchMatching/PitchMatchingFeedbackIndicatorTests.swift`
- No new dependencies, protocols, or services needed — this is a pure SwiftUI view component
- No changes to `PeachApp.swift` composition root (wiring happens in Story 16.3)
- No new `@Model` types or SwiftData changes
- Localization: add English + German strings to `Localizable.xcstrings` for feedback text and accessibility labels

### References

- [Source: docs/planning-artifacts/epics.md — Epic 16, Story 16.2]
- [Source: docs/planning-artifacts/ux-design-specification.md — Pitch Matching Feedback Indicator, Post-Release Feedback Design, Feedback Pattern Comparison]
- [Source: docs/planning-artifacts/prd.md — FR49: Post-release visual feedback]
- [Source: docs/planning-artifacts/architecture.md — v0.2 Architecture Amendment]
- [Source: docs/project-context.md — SwiftUI Patterns, Testing Patterns, Naming Conventions]
- [Source: Peach/Comparison/ComparisonFeedbackIndicator.swift — Analogous component pattern]
- [Source: Peach/Comparison/ComparisonScreen.swift:46-55 — Feedback overlay wiring pattern]
- [Source: Peach/PitchMatching/PitchMatchingSession.swift — state, lastResult properties]
- [Source: Peach/PitchMatching/CompletedPitchMatching.swift — userCentError property]
- [Source: docs/implementation-artifacts/16-1-vertical-pitch-slider-component.md — Previous story learnings]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

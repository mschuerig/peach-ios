# Story 16.1: Vertical Pitch Slider Component

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want a large vertical slider that changes the pitch of the tunable note as I drag it,
So that I can tune by ear using an intuitive physical gesture — up for sharper, down for flatter.

## Acceptance Criteria

1. **Custom SwiftUI view using `DragGesture`** — `VerticalPitchSlider` is a custom SwiftUI view at `PitchMatching/VerticalPitchSlider.swift` that uses `DragGesture` for vertical pitch control. Dragging up increases the cent offset (sharper), dragging down decreases it (flatter).

2. **Large touch target** — The slider thumb/handle significantly exceeds 44x44pt for imprecise one-handed grip. The track has no markings — no tick marks, no labels, no center indicator (a blank instrument).

3. **Fixed starting position** — The slider always starts at the same physical position (center of track) regardless of the pitch offset when a new pitch matching challenge begins.

4. **Inactive state during reference note** — When the slider is in `inactive` state (during reference note / `playingReference`), it does not respond to touch and is visually dimmed per stock SwiftUI disabled appearance.

5. **Active state during tunable note** — When the slider is in `active` state (`playingTunable`), dragging the thumb produces a continuous cent offset value and the `onFrequencyChange` callback fires with the computed frequency.

6. **Release commits result** — When the user releases the slider (drag gesture ends), the `onRelease` callback fires with the final frequency. The slider returns to inactive appearance.

7. **VoiceOver support** — The slider has accessibility label "Pitch adjustment slider" and supports `accessibilityAdjustableAction` for increment/decrement tuning as a fallback.

8. **Orientation support** — In both portrait and landscape, the slider remains vertical (up=higher is non-negotiable). In landscape, it uses the reduced screen height, mapping the same ±100 cent range.

9. **Tests pass** — All existing tests pass. New tests verify: cent offset calculation from drag position, frequency computation from cent offset (using `FrequencyCalculation`), callback invocations, inactive state ignores gestures.

## Tasks / Subtasks

- [ ] Task 1: Create `VerticalPitchSlider` view with `DragGesture` (AC: #1, #2, #3, #4, #5, #6)
  - [ ] Define view struct with `isActive: Bool`, `centRange: Double` (default 100), `referenceFrequency: Double`, `onFrequencyChange: (Double) -> Void`, `onRelease: (Double) -> Void` parameters
  - [ ] Implement `DragGesture` on the track area that maps vertical position to cent offset (-100 to +100)
  - [ ] Compute frequency from cent offset using `FrequencyCalculation.frequency(midiNote:cents:referencePitch:)` or direct formula: `referenceFrequency * pow(2.0, centOffset / 1200.0)`
  - [ ] Render large thumb handle (well above 44x44pt) on a blank track (no markings)
  - [ ] Thumb always starts at vertical center on each new challenge (reset via `isActive` transition)
  - [ ] Disable gesture and dim appearance when `isActive == false`
  - [ ] Fire `onFrequencyChange` continuously during drag, `onRelease` on gesture end
- [ ] Task 2: Add VoiceOver accessibility (AC: #7)
  - [ ] Set accessibility label "Pitch adjustment slider"
  - [ ] Implement `accessibilityAdjustableAction` for increment/decrement
- [ ] Task 3: Verify orientation support (AC: #8)
  - [ ] Test slider remains vertical in landscape with reduced height
  - [ ] Ensure ±100 cent range maps correctly in both orientations
- [ ] Task 4: Write tests for `VerticalPitchSlider` (AC: #9)
  - [ ] Test cent offset calculation from drag position (top = +100, center = 0, bottom = -100)
  - [ ] Test frequency computation from cent offset using `FrequencyCalculation`
  - [ ] Test `onFrequencyChange` callback fires during drag
  - [ ] Test `onRelease` callback fires on gesture end
  - [ ] Test inactive state ignores gestures (no callbacks when `isActive == false`)
  - [ ] Test thumb resets to center when `isActive` transitions from false to true
  - [ ] Extract layout/calculation logic to `static` methods for unit testability

## Dev Notes

### Critical Design Decisions

- **No visual feedback during tuning** — The slider track is deliberately blank (no tick marks, no labels, no center indicator). This is a non-negotiable UX decision: the user must tune purely by ear. Do NOT add any visual cues about pitch accuracy during dragging.
- **"Listen. Search. Release."** — This is the core interaction metaphor. The slider release IS the answer gesture. There is no separate submit button.
- **Up = sharper, down = flatter** — This mapping is non-negotiable across all orientations.
- **±100 cents range** — One semitone in each direction. The `centRange` parameter allows flexibility but defaults to 100.

### Architecture & Integration

- **File location:** `Peach/PitchMatching/VerticalPitchSlider.swift`
- **Test location:** `PeachTests/PitchMatching/VerticalPitchSliderTests.swift`
- **This is a standalone UI component** — it does NOT observe `PitchMatchingSession` directly. Instead, it receives state and callbacks as parameters. The parent `PitchMatchingScreen` (Story 16.3) will wire the slider to the session.
- **Callback-based API** — `onFrequencyChange: (Double) -> Void` for continuous updates, `onRelease: (Double) -> Void` for final frequency. The parent screen maps these to `session.adjustFrequency()` and `session.commitResult(userFrequency:)`.

### Frequency Calculation

- Use `FrequencyCalculation.frequency(midiNote:cents:referencePitch:)` from `Peach/Core/Audio/FrequencyCalculation.swift` for Hz conversion — **never reimplement frequency math**.
- Alternative direct formula for cent-to-frequency: `referenceFrequency * pow(2.0, centOffset / 1200.0)` — but prefer the existing utility.
- The slider maps vertical drag position to a cent offset in range `[-centRange, +centRange]`. Top of track = `+centRange` (sharper), bottom = `-centRange` (flatter), center = 0.

### SwiftUI Implementation Patterns

- **Use `@Observable` — NEVER `ObservableObject`/`@Published`** (project convention)
- **No explicit `@MainActor` annotations** — default MainActor isolation is enabled project-wide
- **Extract layout parameters to `static` methods** for unit testability (pattern from `ComparisonScreen`)
- **Use `DragGesture` with `.onChanged` and `.onEnded`** — pattern used in `ThresholdTimelineView.swift`
- **Use `.contentShape(Rectangle())` on the track** for reliable hit testing
- **Use `GeometryReader` minimally** — only to determine available height for drag-to-cent mapping
- **Disable with `.disabled(!isActive)` and `.opacity(isActive ? 1.0 : 0.4)`** — match stock SwiftUI dimmed appearance
- **Keep the view thin** — no business logic; only gesture-to-value mapping and rendering

### Testing Approach

- **Swift Testing only** — `@Test("behavioral description")`, `@Suite`, `#expect()`
- **Every `@Test` function must be `async`**
- **No `test` prefix** — name describes behavior: `func computesCentOffsetFromDragPosition()`
- **Extract calculation logic to `static` methods** so tests can verify cent offset and frequency computation without instantiating SwiftUI views
- **Key static methods to extract:**
  - `static func centOffset(dragY: CGFloat, trackHeight: CGFloat, centRange: Double) -> Double`
  - `static func frequency(centOffset: Double, referenceFrequency: Double) -> Double`
  - `static func thumbPosition(centOffset: Double, trackHeight: CGFloat, centRange: Double) -> CGFloat`

### Previous Story Learnings (from 15.1 and 15.2)

- **Handle race conditions** — Story 15.1 discovered that `commitResult` and `stop()` must capture handle locally and nil `currentHandle` synchronously before spawning async stop Task. The slider's `onRelease` callback feeds into this pattern.
- **Settings read live** — Read from `UserDefaults` on each challenge, not cached. The slider doesn't need settings directly but the parent screen/session does.
- **Task cancellation pattern** — Check `CancellationError` separately before generic error handling (relevant for parent screen lifecycle).
- **`AudioSessionInterruptionMonitor` extracted** — Interruption handling is already in `PitchMatchingSession` (Story 15.2). The slider does not handle interruptions — the session sets state to `idle` which makes `isActive = false`.
- **Test count baseline: 473 tests** — all must continue passing.

### Project Structure Notes

- File goes in `Peach/PitchMatching/` alongside existing `PitchMatchingSession.swift`, `PitchMatchingChallenge.swift`, `CompletedPitchMatching.swift`, `PitchMatchingObserver.swift`
- Tests go in `PeachTests/PitchMatching/VerticalPitchSliderTests.swift`
- No new dependencies, protocols, or services needed — this is a pure SwiftUI view component
- No changes to `PeachApp.swift` composition root (wiring happens in Story 16.3)
- No new `@Model` types or SwiftData changes
- Localization: accessibility label "Pitch adjustment slider" must be added to `Localizable.xcstrings` (English + German)

### References

- [Source: docs/planning-artifacts/epics.md — Epic 16, Story 16.1]
- [Source: docs/planning-artifacts/architecture.md — v0.2 Architecture Amendment, NotePlayer Protocol Redesign]
- [Source: docs/planning-artifacts/ux-design-specification.md — Pitch Matching Screen, Vertical Slider]
- [Source: docs/project-context.md — SwiftUI Patterns, Testing Patterns, Naming Conventions]
- [Source: Peach/Core/Audio/FrequencyCalculation.swift — frequency() and midiNoteAndCents() API]
- [Source: Peach/PitchMatching/PitchMatchingSession.swift — adjustFrequency(), commitResult(), state enum]
- [Source: Peach/Comparison/ComparisonScreen.swift — UI pattern reference: environment injection, responsive layout, static layout params]
- [Source: Peach/Comparison/ComparisonFeedbackIndicator.swift — UI pattern reference: simple subview, accessibility labels]
- [Source: Peach/Profile/ThresholdTimelineView.swift — DragGesture implementation pattern]
- [Source: docs/implementation-artifacts/15-1-pitchmatchingsession-core-state-machine.md — Previous story learnings]
- [Source: docs/implementation-artifacts/15-2-pitchmatchingsession-interruption-and-lifecycle-handling.md — Interruption patterns]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

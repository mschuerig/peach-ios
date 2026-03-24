# Story 60.2: Touch-Down Trigger for Tap Button

Status: ready-for-dev

## Story

As a user tapping along to the rhythm,
I want the tap sound to play the instant my finger touches the screen,
so that the sound feels immediate and in time with my physical tap.

## Acceptance Criteria

### AC 1: Touch-down trigger

**Given** `ContinuousRhythmMatchingScreen`'s tap button
**When** the user presses down on it
**Then** `session.handleTap()` fires on touch-down (finger press), not touch-up (finger lift)

### AC 2: Single fire per press

**Given** the user holds their finger down or drags
**When** `onChanged` fires repeatedly
**Then** `handleTap()` is called only once per press — a `@State` debounce flag (`isTouchActive`) prevents redundant calls, reset in `onEnded`

### AC 3: Visual appearance

**Given** the tap button's visual appearance
**When** rendered
**Then** it matches the current `.borderedProminent` style (accent background, white foreground, rounded rectangle)

### AC 4: Accessibility

**Given** the tap button
**When** VoiceOver is active
**Then** it retains its accessibility label ("Tap") and hint

### AC 5: No regressions

**Given** the full test suite
**When** run
**Then** all tests pass with zero regressions

## Tasks / Subtasks

- [ ] Task 1: Replace Button with DragGesture (AC: 1, 2)
  - [ ] 1.1 Add `@State private var isTouchActive = false` to `ContinuousRhythmMatchingScreen`
  - [ ] 1.2 Replace `Button { session.handleTap() }` with a `VStack` + `.gesture(DragGesture(minimumDistance: 0))`
  - [ ] 1.3 In `.onChanged`: guard `!isTouchActive`, set `isTouchActive = true`, call `session.handleTap()`
  - [ ] 1.4 In `.onEnded`: set `isTouchActive = false`
- [ ] Task 2: Match visual style (AC: 3)
  - [ ] 2.1 Apply `.background(.tint, in: RoundedRectangle(cornerRadius: 12))` and `.foregroundStyle(.white)` to match `.borderedProminent` appearance
  - [ ] 2.2 Verify visual match on device (the exact styling may need adjustment to match `borderedProminent`'s padding/insets)
- [ ] Task 3: Accessibility (AC: 4)
  - [ ] 3.1 Add `.accessibilityLabel("Tap")` and `.accessibilityHint(...)` to the gesture view
  - [ ] 3.2 Add `.accessibilityAddTraits(.isButton)` since it's no longer a semantic Button
- [ ] Task 4: Run test suite (AC: 5)
  - [ ] 4.1 Run full test suite, verify zero regressions

## Dev Notes

### Key Files

| File | Role |
|------|------|
| `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift:104-123` | **Modify** — replace `Button` with `DragGesture`-based tap view |

### Context

SwiftUI `Button` fires its action on `.touchUpInside` (finger lift). For a rhythm training app, the sound must play on finger press — the same behavior as every professional iOS music app. `DragGesture(minimumDistance: 0).onChanged` fires on the first touch point, equivalent to `touchesBegan`.

The `onChanged` handler fires continuously as the finger moves, so the `isTouchActive` debounce flag is essential to prevent multiple `handleTap()` calls per press. The session already guards against double-counting via `hitCycleIndices`, but `playImmediateNote()` would fire redundant note-ons without the UI-level debounce.

### Alternative Approach

If `DragGesture` introduces unexpected SwiftUI overhead or gesture conflicts, fall back to a `UIViewRepresentable` wrapping a `UIView` with `touchesBegan`:

```swift
struct TouchDownView: UIViewRepresentable {
    let onTouchDown: () -> Void
    func makeUIView(context: Context) -> UIView {
        let view = TouchView()
        view.onTouchDown = onTouchDown
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
    private class TouchView: UIView {
        var onTouchDown: (() -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            onTouchDown?()
        }
    }
}
```

### References

- [Architecture amendment v0.6](../planning-artifacts/architecture.md) — Touch-down for audio triggers constraint
- [Technical research report](../planning-artifacts/research/technical-ios-audio-latency-rhythm-training-research-2026-03-24.md) — Fix 1

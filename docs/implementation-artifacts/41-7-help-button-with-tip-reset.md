# Story 41.7: Help Button with Tip Reset

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a returning user,
I want a "?" button in the Profile screen navigation bar that replays all chart help tips,
so that I can re-read the explanations whenever I need a refresher.

## Design Change from Original Epic

**CRITICAL:** The original epic described a "?" button on **each progress card header**. This has been changed:

- **NOT** a button on each card's headline row
- **ONE** button in the **navigation bar trailing area**, styled as a pill — exactly the same placement and style as the help button on the training screens (PitchComparisonScreen, PitchMatchingScreen)
- Uses `questionmark.circle` SF Symbol in a toolbar button, matching the existing pattern

## Acceptance Criteria

1. **Given** the Profile screen navigation bar, **When** the screen renders, **Then** a "?" button is visible in the trailing toolbar area, matching the training screen help button placement

2. **Given** all tips have been previously dismissed, **When** the user taps the "?" button, **Then** all chart tips are reset and the sequential tip flow restarts from the first tip

3. **Given** the "?" button, **When** VoiceOver is active, **Then** the button has an accessibility label "Show chart help"

## Tasks / Subtasks

- [ ] Task 1: Add toolbar help button to ProfileScreen (AC: #1)
  - [ ] Add `@State private var` flag (if needed) for managing tip reset
  - [ ] Add `.toolbar { ToolbarItem(placement: .navigationBarTrailing) }` with `questionmark.circle` button
  - [ ] Style must match training screens exactly — `Label("Help", systemImage: "questionmark.circle")` inside a `Button`
- [ ] Task 2: Implement tip reset on tap (AC: #2)
  - [ ] On button tap, call `Tips.resetDatastore()` to clear TipKit's persistent dismissal state
  - [ ] After reset, reinitialize the `tipGroup` so the sequential flow restarts
  - [ ] Verify tips replay in original order: ChartOverviewTip → EWMALineTip → StdDevBandTip → BaselineTip → GranularityZoneTip
- [ ] Task 3: Accessibility (AC: #3)
  - [ ] Add `.accessibilityLabel(String(localized: "Show chart help"))` to the button
- [ ] Task 4: Localization
  - [ ] Add "Show chart help" to Localizable.xcstrings with German translation using `bin/add-localization.py`
- [ ] Task 5: Manual verification
  - [ ] Verify button appears in nav bar trailing position
  - [ ] Verify tapping resets and replays all five tips in order
  - [ ] Verify VoiceOver reads "Show chart help"
  - [ ] Run `bin/test.sh` — all existing tests must pass
  - [ ] Run `bin/build.sh` — no warnings or errors

## Dev Notes

### Critical Design Decision

The help button lives in **ProfileScreen's navigation toolbar**, NOT in ProgressChartView's headline row. This is consistent with:
1. The user's explicit instruction to match the training screen pattern
2. The 41.6 review decision that moved TipGroup to ProfileScreen (tips are screen-level, not card-level)

### Existing Pattern to Follow

The training screens (PitchComparisonScreen, PitchMatchingScreen, SettingsScreen) all use the same toolbar help button pattern:

```swift
// From PitchComparisonScreen.swift:109-116
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            // action
        } label: {
            Label("Help", systemImage: "questionmark.circle")
        }
    }
}
```

ProfileScreen currently has NO toolbar items. Add one with just the help button (no settings or other nav links needed — Profile is a leaf destination reached from training screens).

### TipKit Reset Implementation

`Tips.resetDatastore()` is an async throwing function. After calling it, the `@State tipGroup` needs to be recreated to pick up the reset state. Approach:

```swift
// Option A: Reset and recreate tipGroup
Button {
    Task {
        try? Tips.resetDatastore()
        tipGroup = TipGroup(.ordered) {
            ChartOverviewTip()
            EWMALineTip()
            StdDevBandTip()
            BaselineTip()
            GranularityZoneTip()
        }
    }
} label: {
    Label("Show chart help", systemImage: "questionmark.circle")
}
```

**Important:** `Tips.resetDatastore()` resets ALL tips globally, not just chart tips. This is acceptable because chart tips are the only TipKit tips in the app (as established in 41.6).

### Files to Modify

| File | Change |
|------|--------|
| `Peach/Profile/ProfileScreen.swift` | Add `.toolbar` modifier with help button; add tip reset logic |
| `Peach/Localization/Localizable.xcstrings` | Add "Show chart help" EN+DE |

**No new files needed.** Do NOT modify ProgressChartView — the button does not go on cards.

### What NOT to Do

- Do NOT add a button to `ProgressChartView.headlineRow()` — the original epic's per-card design was overridden
- Do NOT add a help sheet — this button resets TipKit tips inline, not a modal sheet
- Do NOT pass tipGroup to ProgressChartView — it stays entirely in ProfileScreen

### Project Structure Notes

- Alignment: Button follows established toolbar pattern from training screens
- No new dependencies — TipKit already imported in ProfileScreen.swift
- No architecture violations — UI-only change within Profile feature boundary

### References

- [Source: Peach/Profile/ProfileScreen.swift] — current ProfileScreen with TipGroup
- [Source: Peach/Profile/ChartTips.swift] — five tip definitions
- [Source: Peach/PitchComparison/PitchComparisonScreen.swift:109-116] — toolbar help button pattern to match
- [Source: docs/implementation-artifacts/41-6-tipkit-help-overlay-system.md] — previous story establishing TipKit foundation
- [Source: docs/project-context.md] — project conventions

### Previous Story Intelligence (41.6)

- TipGroup was moved from ProgressChartView to ProfileScreen during review — tips are screen-level
- Tips use `TipGroup(.ordered)` for sequential display
- `Tips.configure()` is called in PeachApp.init
- All five tips have English + German localizations
- TipView renders inline above progress cards in the ScrollView

### Git Intelligence

Recent commits show the pattern: create story → implement → review with architectural adjustments. The 41.6 review moved TipGroup to ProfileScreen, which aligns perfectly with this story's approach of putting the reset button at screen level too.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

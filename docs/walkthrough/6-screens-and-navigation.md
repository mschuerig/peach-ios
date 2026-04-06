# Layer 6: Screens & Navigation

**Status:** done
**Session date:** 2026-04-06

## Architecture Overview

The UI layer follows a hub-and-spoke navigation pattern rooted in `StartScreen`. All screens are thin SwiftUI views that read session state from `@Environment` — no view models, no Combine, no intermediate presentation layer.

```
StartScreen (hub)
    │
    ├── PitchDiscriminationScreen ─── Higher / Lower buttons
    ├── PitchMatchingScreen ────────── PitchSlider + commit
    ├── RhythmOffsetDetectionScreen ── Early / Late buttons + RhythmDotView
    ├── ContinuousRhythmMatchingScreen ── Tap button + ContinuousRhythmMatchingDotView
    ├── ProfileScreen ──────────────── ProgressChartView (pitch) + RhythmProfileCardView (rhythm)
    ├── SettingsScreen ─────────────── Form with @AppStorage bindings
    └── InfoScreen (sheet) ─────────── Static help content
```

**Consistent screen pattern:** All 4 training screens share the same structure:
1. `statsHeader` — latest result + session best + feedback indicator (top)
2. Visual element — dots (rhythm) or slider (matching) (middle)
3. Answer buttons — full-width, large tap targets (bottom)
4. Toolbar — principal title + help/settings/profile links
5. Keyboard/focus — `.focusable()` + `.onKeyPress()` for arrows, letters, escape
6. Lifecycle — `onAppear` → `lifecycle.trainingScreenAppeared()`, `onDisappear` → `lifecycle.trainingScreenDisappeared()`
7. Help sheet — modal with `HelpContentView(sections:)`

## `StartScreen.swift` (218 lines)

Hub with 6 training cards organized in 3 sections (Pitch, Intervals, Rhythm). Adapts between portrait (VStack scroll) and landscape (HStack columns) via `verticalSizeClass`.

Each card is a `NavigationLink` wrapping a `trainingCard()` view that includes a `ProgressSparklineView` — a mini trend chart showing bucket means and EWMA.

`TrainingCardButtonStyle` — custom press animation (opacity 0.7 on press).

The `.navigationDestination(for:)` switch maps all 6 `NavigationDestination` cases to their screens. This is the only place where destination → screen routing is defined.

## Training Screens

### `PitchDiscriminationScreen.swift` (284 lines)

Two large Higher/Lower buttons (vertical in portrait, horizontal in landscape). Keyboard shortcuts: arrow keys + localized letter keys. `AnswerDirection` private enum encapsulates button metadata.

Help sections are static `[HelpSection]` arrays — localized strings defined inline. The Intervals section only appears when `isIntervalMode`.

### `PitchMatchingScreen.swift` (220 lines)

Wraps `PitchSlider` with callbacks for `onValueChange` (continuous drag) and `onCommit` (release). Three input sources: slider touch, keyboard arrows (fine pitch step), MIDI pitch bend. `externalValue` drives thumb position from MIDI/keyboard.

### `RhythmOffsetDetectionScreen.swift` (248 lines)

Early/Late buttons (always horizontal). `RhythmDotView` shows 4 dots lighting up as the pattern plays — the 3rd dot (tested note) is a double-circle visual. Grid alignment handled by the session.

### `ContinuousRhythmMatchingScreen.swift` (233 lines)

Single large Tap button using a `DragGesture(minimumDistance: 0)` for instant touch response (fires on `.onChanged`, not `.onEnded`). `isTouchActive` state prevents double-tap within a single gesture. `ContinuousRhythmMatchingDotView` shows gap as outlined circle vs filled.

Cycle progress counter ("4/16") shows position within the current trial.

## Feedback Indicators

| Indicator | Session | Display |
|-----------|---------|---------|
| `PitchDiscriminationFeedbackIndicator` | Pitch compare | Checkmark/X (green/red) |
| `PitchMatchingFeedbackIndicator` | Pitch match | Arrow + cent offset, 4-band color (dead center/close/moderate/far) |
| `RhythmOffsetDetectionFeedbackView` | Rhythm compare | Checkmark/X + percentage |
| `RhythmTimingFeedbackIndicator` | Rhythm match | Arrow (early/late) + ms offset, color from `SpectrogramThresholds` |

All feedback indicators use the same pattern: visible content when data is non-nil, hidden placeholder (for layout stability) when nil.

## Stats Views

- `TrainingStatsView` (in App/) — pitch stats: latest value + session best + trend arrow. Used by both pitch screens.
- `RhythmStatsView` — rhythm stats: percentage + ms values. Includes trend symbol/color/label helpers.
- Both are reused by their respective screens' `statsHeader`.

## Profile Adapters

Each training discipline has a `*ProfileAdapter` (observer → profile bridge):
- `PitchDiscriminationProfileAdapter` — routes correct answers to `.pitch(mode)` key, using cent offset magnitude
- `PitchMatchingProfileAdapter` — routes all answers (no `isCorrect` gate) to `.pitch(mode)` key, using cent error magnitude
- `RhythmOffsetDetectionProfileAdapter` — routes correct answers to `.rhythm(mode, range, direction)` key
- `ContinuousRhythmMatchingProfileAdapter` — computes signed mean of gap offsets, routes to `.rhythm(mode, range, direction)` key

## Profile Screen (`ProfileScreen.swift`, 152 lines)

Iterates `TrainingDisciplineID.allCases`, rendering:
- Pitch modes → `ProgressChartView` (if data exists)
- Rhythm modes → `RhythmProfileCardView` (always shown, with empty state)

TipKit integration: ordered `TipGroup` with 5 progressive tips explaining chart features.

## `ProgressChartView.swift` (629 lines)

The largest view in the codebase. Multi-layered Swift Charts visualization:

1. Zone backgrounds (colored `RectangleMark`)
2. Zone dividers + year boundary dividers
3. Stddev band (`AreaMark`)
4. EWMA trend line (`LineMark`)
5. Session dots (`PointMark`)
6. Baseline (`RuleMark`, dashed green)
7. Selection indicator with annotation popup

**Scrolling:** Automatically scrollable when buckets exceed `visibleBucketCount` (8). Session buckets use compact spacing (0.3 vs 1.0 for day/month).

**Line bridge:** `lineDataWithSessionBridge` extends the EWMA line from the last day bucket to the session zone boundary, using weighted-average session data. This prevents a visual gap between zones.

**Contrast:** All opacity values have `contrastAdjustedOpacity` variants for Increase Contrast accessibility.

**Year labels:** Positioned via `chartOverlay` + `GeometryReader` below the X-axis.

**Share:** `ChartImageRenderer` renders `ExportChartView` (a non-interactive replica) to PNG via `ImageRenderer`.

## `RhythmSpectrogramView.swift` (270 lines)

Tempo × time heat map grid. Each cell is a colored `Rectangle` sized dynamically based on column/range count. Scrolls horizontally with `.defaultScrollAnchor(.trailing)`.

Tap on cell shows detail overlay (early/late stats with mean%, stddev%, hit count). VoiceOver gets per-column accessibility summaries.

`SpectrogramAccuracyLevel.color` extension maps levels to colors (teal/green/yellow/orange/red).

## Settings Screen (`SettingsScreen.swift`, 367 lines)

`Form` with 7 sections, all settings backed by `@AppStorage`:

1. **Training Range** — Note min/max steppers with `MIDINote.name` display
2. **Intervals** — `IntervalSelectorView` (direction × interval grid)
3. **Sound** — Picker + preview button + duration stepper + concert pitch stepper + tuning system picker
4. **Difficulty** — Vary loudness slider + note gap stepper
5. **Rhythm** — Tempo BPM stepper
6. **Gap Positions** — `GridToggleRow` (generic toggle grid)
7. **Data** — Export (ShareLink), Import (file picker → mode dialog → summary), Reset (confirmation dialog)

`IntervalSelection` — JSON-encoded `Set<DirectedInterval>` stored as `@AppStorage` string. `GapPositionEncoding` — comma-separated raw values stored as `@AppStorage` string.

Import flow: file picker → `coordinator.prepareImport()` → `ImportDialogModifier` (replace/merge dialog) → `coordinator.executeImport()` → summary alert.

Platform-conditional import: iOS uses `.fileImporter`, macOS uses `NSOpenPanel` directly.

## `AppUserSettings.swift` (81 lines)

Concrete `UserSettings` implementation reading from `UserDefaults`. Each property reads a key, validates, and wraps in a domain type (e.g., `MIDINote`, `Frequency`, `NoteDuration`). Defensive: falls back to defaults if the stored value is nil or invalid.

## `SettingsKeys.swift` (65 lines)

Enum namespace with `@AppStorage` key names, default values, note range bounds, and sound source validation. Single source of truth for key strings and defaults.

## `InfoScreen.swift` (99 lines)

Static content: app description, training mode descriptions, getting started text, acknowledgments (FluidR3_GM, GeneralUser GS SoundFonts), copyright, version, GitHub link.

## Files read

**Start/** (2): StartScreen, ProgressSparklineView
**PitchDiscrimination/** (UI only, 3): Screen, FeedbackIndicator, ProfileAdapter
**PitchMatching/** (UI only, 4): Screen, FeedbackIndicator, PitchSlider, ProfileAdapter
**RhythmOffsetDetection/** (UI only, 4): Screen, FeedbackView, DotView, RhythmStatsView, ProfileAdapter
**ContinuousRhythmMatching/** (UI only, 4): Screen, DotView, TimingFeedbackIndicator, ProfileAdapter
**Profile/** (7): ProfileScreen, ProgressChartView, RhythmProfileCardView, RhythmSpectrogramView, ExportChartView, ChartImageRenderer, ChartTips
**Settings/** (8): SettingsScreen, AppUserSettings, SettingsKeys, IntervalSelectorView, IntervalSelection, ImportDialogModifier, GridToggleRow, GapPositionEncoding, CSVDocument
**Info/** (1): InfoScreen

## Observations and questions

1. **All 4 training screens duplicate the same boilerplate.** Each has: `@FocusState` + `@State showHelpSheet`, `focusable()` + `focusEffectDisabled()` + `focused()`, `onKeyPress(.escape)` dismiss, `onAppear/onDisappear` lifecycle calls, help sheet `onChange` with `lifecycle.helpSheetPresented/Dismissed()`, toolbar with help + settings + profile links, and `trainingIdleOverlay()`. This is 30+ lines of identical scaffolding per screen. A `TrainingScreenModifier` view modifier could absorb all of it, leaving each screen to define only its unique content (buttons/slider/dots) and help sections.

2. **`ProgressChartView` is 629 lines — the largest file in the codebase and needs structural decomposition.** Almost all computation is layout/presentation, with one exception: `lineDataWithSessionBridge()` performs a weighted mean/variance computation that belongs in the data layer — it's a statistical calculation, not a view concern. But even setting that aside, 629 lines of layout code is too much. The file conflates at least 6 distinct responsibilities: (a) chart data preparation — positions, zones, line bridge, year boundaries (→ extract to a `ChartData` struct), (b) chart rendering — the 7-layer `Chart` body, (c) axis formatting and domain configuration, (d) scroll/selection interaction, (e) accessibility (contrast, VoiceOver), (f) share/export coordination. A `ChartData` struct would also clean up `ExportChartView`, which currently duplicates the same static method calls to reconstruct chart data independently.

3. **`SettingsScreen` uses `@AppStorage` directly instead of going through `AppUserSettings`.** The screen defines 11 `@AppStorage` properties that duplicate the key names and defaults from `SettingsKeys`. `AppUserSettings` reads the same keys from `UserDefaults`. This means settings have three sources of truth: `SettingsKeys` (key names + defaults), `@AppStorage` in `SettingsScreen` (with defaults that must match), and `AppUserSettings` (with defaults that must match). If any default drifts, the UI and session will disagree on the setting value.

4. **Help sections are defined inline in each screen as static arrays.** All 4 training screens, the settings screen, and the profile screen each define `static let helpSections: [HelpSection]`. The help text is co-located with its screen, which is convenient, but the `HelpSection` type and rendering via `HelpContentView` is shared. The macOS menu bar (`PeachCommands`) needs access to these same sections — it currently references them as `PitchDiscriminationScreen.helpSections`. This coupling between the menu system and individual screen types could be avoided by centralizing help content.

5. **`PitchMatchingProfileAdapter` routes all results (correct or not), while `PitchDiscriminationProfileAdapter` only routes correct answers.** This is because pitch matching has no binary correct/incorrect — every attempt produces a continuous cent error value. But this asymmetry is undocumented and could confuse someone reading the code. A brief comment explaining the difference would help.

6. **`ContinuousRhythmMatchingScreen` uses `DragGesture(minimumDistance: 0)` instead of `Button` for the tap button.** This is intentional — it fires on touch-down (`.onChanged`) rather than touch-up, which is critical for timing accuracy. But the result is that the "button" is actually a gesture on a styled `VStack`, and the accessibility support has to be manually added (`.accessibilityAddTraits(.isButton)`, `.accessibilityAction(.default)`). This is well-done but should be documented as a deliberate accessibility-aware design choice.

7. **`SettingsScreen.importTrainingData()` uses `NSOpenPanel` directly on macOS.** This is a platform-conditional method within the view itself (`#if os(macOS)` / `#elseif os(iOS)`). Unlike the other platform abstractions that live in `App/Platform/`, this one is inline. Consistent with the ContentView observation (Layer 5 #8) — platform-specific import logic would move naturally if SettingsScreen were also split per-platform.

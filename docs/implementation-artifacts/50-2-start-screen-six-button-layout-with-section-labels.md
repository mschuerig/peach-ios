# Story 50.2: Start Screen Six-Button Layout with Section Labels

Status: review

## Story

As a **musician using Peach**,
I want the Start Screen to show six training buttons organized by section (Pitch, Intervals, Rhythm),
so that I can easily find and start any training mode (FR104).

## Acceptance Criteria

1. **Given** the Start Screen in portrait, **when** displayed, **then** it shows section labels ("Pitch", "Intervals", "Rhythm") with two buttons per section in a scrollable vertical stack (UX-DR6).

2. **Given** the button styling, **when** displayed, **then** Pitch Comparison remains `.borderedProminent` (hero button), all others use `.bordered` style (UX-DR6).

3. **Given** the Rhythm section, **when** displayed, **then** it shows "Rhythm Comparison" and "Rhythm Matching" buttons that navigate to `RhythmOffsetDetectionScreen` and `RhythmMatchingScreen` respectively.

4. **Given** landscape orientation, **when** the Start Screen is displayed, **then** it uses a 3-column grid layout with one section per column (UX-DR6).

5. **Given** iPad, **when** the Start Screen is displayed, **then** layout adapts to the wider form factor (UX-DR14).

6. **Given** the `.rhythmPOC` navigation case, **when** this story is complete, **then** `.rhythmPOC` is removed from `NavigationDestination` and `RhythmPOCScreen` is deleted.

7. **Given** the Rhythm training cards, **when** displayed, **then** each shows a `ProgressSparklineView` with the appropriate `TrainingDiscipline` (`.rhythmOffsetDetection` and `.rhythmMatching`).

## Tasks / Subtasks

- [x] Task 1: Rename "Single Notes" section label to "Pitch" (AC: #1)
  - [x] Change `Text("Single Notes")` to `Text("Pitch")` in `singleNotesSection` (rename the computed property to `pitchSection`)
  - [x] Verify German localization for "Pitch" exists in `Localizable.xcstrings` (add via `bin/add-localization.swift` if missing)

- [x] Task 2: Add Rhythm section with two training cards (AC: #1, #3, #7)
  - [x] Create `rhythmSection` computed property following the pattern of `pitchSection` / `intervalsSection`
  - [x] "Rhythm Comparison" button navigates to `.rhythmOffsetDetection`, uses `.rhythmOffsetDetection` for sparkline
  - [x] "Rhythm Matching" button navigates to `.rhythmMatching`, uses `.rhythmMatching` for sparkline
  - [x] Choose appropriate SF Symbols (e.g., `"metronome"` for comparison, `"hand.tap"` for matching)
  - [x] Add German localizations for "Rhythm", "Rhythm Comparison", "Rhythm Matching"

- [x] Task 3: Apply hero styling to Pitch Comparison button (AC: #2)
  - [x] The first button in the Pitch section ("Hear & Compare", unison pitch discrimination) should be visually more prominent than all other buttons
  - [x] Consider using `.tint(.accentColor)` or a bolder background fill for the hero card while keeping `.regularMaterial` for others
  - [x] Subtle differentiation is fine — this is the most common starting point for new users

- [x] Task 4: Update portrait layout to scrollable vertical stack (AC: #1)
  - [x] Wrap the VStack in a `ScrollView(.vertical)` so all 6 cards + section labels fit smaller screens
  - [x] Keep the existing spacing logic from `sectionSpacing` and `cardSpacing` static methods
  - [x] Remove the `Spacer()` calls that were centering content (scrollable content fills naturally)

- [x] Task 5: Update landscape layout to 3-column grid (AC: #4, #5)
  - [x] Replace the current `HStack` (which only shows 2 sections side-by-side) with a 3-column layout
  - [x] Each column contains one section (Pitch, Intervals, Rhythm) with its label and 2 cards
  - [x] Use `HStack(spacing:)` with equal-width columns, or `LazyVGrid` with 3 flexible columns
  - [x] On iPad landscape, the wider form factor should naturally accommodate the 3-column layout

- [x] Task 6: Remove `.rhythmPOC` navigation case and `RhythmPOCScreen` (AC: #6)
  - [x] Remove `case rhythmPOC` from `NavigationDestination` enum
  - [x] Remove the `.rhythmPOC` case from the `navigationDestination` switch in `StartScreen`
  - [x] Remove the `rhythmPOCButton` computed property from `StartScreen`
  - [x] Remove all references to `rhythmPOCButton` from the body layout
  - [x] Delete `Peach/RhythmPOC/RhythmPOCScreen.swift` (confirm no other references first)
  - [x] Remove `RhythmPOC/` directory if empty after deletion

- [x] Task 7: Run full test suite
  - [x] `bin/test.sh` — all tests must pass

## Dev Notes

### Current StartScreen layout

The Start Screen currently has 5 buttons in 2 named sections plus a standalone rhythm POC button:
- **"Single Notes"** section: "Hear & Compare" (unison discrimination), "Tune & Match" (unison matching)
- **"Intervals"** section: "Hear & Compare" (interval discrimination), "Tune & Match" (interval matching)
- **"Rhythm POC"** standalone button with orange accent styling

The layout switches on `verticalSizeClass`:
- Portrait (regular height): VStack with Spacers for vertical centering
- Landscape (compact height): HStack with 2 sections side-by-side + rhythm POC below

### Target layout (6 buttons, 3 sections)

```
Portrait:                    Landscape:
┌─────────────────┐         ┌───────┬───────┬───────┐
│     Pitch       │         │ Pitch │ Inter │Rhythm │
│ ┌─────────────┐ │         │       │       │       │
│ │Hear&Compare │ │         │ H&C   │ H&C   │ R.Cmp │
│ └─────────────┘ │         │ T&M   │ T&M   │ R.Mtc │
│ ┌─────────────┐ │         │       │       │       │
│ │Tune & Match │ │         └───────┴───────┴───────┘
│ └─────────────┘ │
│    Intervals    │
│ ┌─────────────┐ │
│ │Hear&Compare │ │
│ └─────────────┘ │
│ ┌─────────────┐ │
│ │Tune & Match │ │
│ └─────────────┘ │
│     Rhythm      │
│ ┌─────────────┐ │
│ │Rhythm Comp. │ │
│ └─────────────┘ │
│ ┌─────────────┐ │
│ │Rhythm Match │ │
│ └─────────────┘ │
└─────────────────┘
```

### Existing patterns to reuse

- **`trainingCard(_:systemImage:mode:)`** — reuse for rhythm cards, passing `.rhythmOffsetDetection` and `.rhythmMatching` as the `TrainingDiscipline` mode
- **`TrainingCardButtonStyle`** — keep the existing press-opacity animation
- **`ProgressSparklineView(mode:)`** — already supports all 6 disciplines via `TrainingDiscipline`
- **Section label pattern** — `Text("Label").font(.title3).foregroundStyle(.secondary)` already used for "Single Notes" and "Intervals"
- **`sectionSpacing` / `cardSpacing` static methods** — keep for unit-testable layout parameters

### Hero button approach

The AC says Pitch Comparison should be `.borderedProminent` (hero). The current implementation uses custom `TrainingCardButtonStyle` with `.regularMaterial` backgrounds — there are no system button styles in use. To satisfy the AC within the existing design language:
- Give the Pitch Comparison card a more prominent background (e.g., `.thinMaterial` + subtle accent tint, or a thicker border)
- Keep all other cards at `.regularMaterial`
- The differentiation should be noticeable but not garish

### Removing RhythmPOCScreen

Story 50.1 explicitly deferred `.rhythmPOC` cleanup to this story. Before deleting:
1. Check `RhythmPOCScreen.swift` has no unique logic needed elsewhere (it was a proof-of-concept)
2. Remove the `case rhythmPOC` from `NavigationDestination`
3. The real rhythm screens (`RhythmOffsetDetectionScreen`, `RhythmMatchingScreen`) replace all POC functionality

### ScrollView for portrait

With 6 training cards + 3 section labels, the content may overflow smaller iPhone screens (especially iPhone SE). Wrapping in `ScrollView(.vertical)` ensures all content is accessible. Remove the `Spacer()` calls used for centering — scrollable content should start from the top with padding.

### What NOT to do

- Do NOT modify any training sessions, settings, or data layer — this is purely a UI story
- Do NOT add new NavigationDestination cases — `.rhythmOffsetDetection` and `.rhythmMatching` already exist from story 50.1
- Do NOT use `ObservableObject`/`@Published` — project uses `@Observable`
- Do NOT add explicit `@MainActor` — redundant with default isolation
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT modify `ProgressSparklineView` — it already supports rhythm disciplines
- Do NOT add a tempo stepper to Settings — that's Story 50.3

### Project Structure Notes

Modified files:
```
Peach/
├── App/
│   └── NavigationDestination.swift   # REMOVE case rhythmPOC
├── Start/
│   └── StartScreen.swift             # REWRITE layout: 3 sections, 6 buttons, scroll, 3-col landscape
├── RhythmPOC/
│   └── RhythmPOCScreen.swift         # DELETE file and directory
```

### References

- [Source: Peach/Start/StartScreen.swift — main file to modify]
- [Source: Peach/App/NavigationDestination.swift — remove rhythmPOC case]
- [Source: Peach/RhythmPOC/RhythmPOCScreen.swift — file to delete]
- [Source: Peach/Core/Profile/ProgressTimeline.swift:18-24 — TrainingDiscipline enum with .rhythmOffsetDetection and .rhythmMatching]
- [Source: Peach/Start/ProgressSparklineView.swift — already supports all 6 modes]
- [Source: docs/planning-artifacts/epics.md#Epic 50 Story 50.2 — acceptance criteria]
- [Source: docs/planning-artifacts/epics.md — UX-DR6: section labels, portrait/landscape layout]
- [Source: docs/planning-artifacts/epics.md — UX-DR14: iPad adaptive layout]
- [Source: docs/planning-artifacts/epics.md — FR104: six training buttons]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None

### Completion Notes List

- Renamed "Single Notes" section to "Pitch" with `pitchSection` computed property
- Added `rhythmSection` with "Rhythm Comparison" (`metronome` icon, `.rhythmOffsetDetection`) and "Rhythm Matching" (`hand.tap` icon, `.rhythmMatching`)
- Hero styling: Pitch Comparison card uses `.thinMaterial` background + subtle accent-colored stroke border; all others use `.regularMaterial`
- Portrait layout: `ScrollView(.vertical)` wrapping `VStack` with 3 sections, no `Spacer()` centering
- Landscape layout: `HStack` with 3 equal-width columns (Pitch, Intervals, Rhythm)
- Removed `case rhythmPOC` from `NavigationDestination` enum
- Deleted `Peach/RhythmPOC/RhythmPOCScreen.swift` and `RhythmPOC/` directory
- Added German localizations: "Pitch" → "Tonhöhe", "Rhythm" → "Rhythmus", "Rhythm Comparison" → "Rhythmusvergleich", "Rhythm Matching" → "Rhythmusanpassung"
- All 1356 tests pass, no regressions

### Change Log

- 2026-03-21: Implemented six-button layout with section labels, hero styling, scroll/grid layouts, removed RhythmPOC

### File List

- `Peach/Start/StartScreen.swift` (modified)
- `Peach/App/NavigationDestination.swift` (modified)
- `Peach/RhythmPOC/RhythmPOCScreen.swift` (deleted)
- `Peach/Resources/Localizable.xcstrings` (modified)

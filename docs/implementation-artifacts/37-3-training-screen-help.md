# Story 37.3: Training Screen Help

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to understand the goal of the current training and how to use the controls,
So that I can focus on training rather than figuring out the interface.

## Acceptance Criteria

1. **Given** a Training Screen (comparison or pitch matching) **When** help is accessed (e.g., help button — must not interfere with training flow) **Then** a help view explains: the goal of this specific training mode, how to interact with the controls (buttons for comparison, slider for pitch matching), and what the feedback indicators mean

2. **Given** interval training mode **When** the help is shown **Then** it additionally explains what interval training means and how it differs from unison

3. **Given** the help trigger **When** it is available during active training **Then** accessing help pauses or stops the current training (no state corruption)

4. **Given** the help content **When** displayed in English or German **Then** all text is properly localized

5. **Given** the help view **When** the user dismisses it **Then** they return to the Training Screen without side effects and training can resume

## Tasks / Subtasks

- [ ] Task 1: Design help content for ComparisonScreen (AC: #1, #2)
  - [ ] 1.1 Write help section explaining the goal of Hear & Compare training (listen to two notes, decide which is higher)
  - [ ] 1.2 Write help section explaining the controls (Higher/Lower buttons, when they become active)
  - [ ] 1.3 Write help section explaining the feedback indicator (checkmark/X overlay, what correct/incorrect means)
  - [ ] 1.4 Write help section explaining the difficulty display (cent difference, session best)
  - [ ] 1.5 Write help section for interval mode: what intervals are, how interval training differs from unison comparison

- [ ] Task 2: Design help content for PitchMatchingScreen (AC: #1, #2)
  - [ ] 2.1 Write help section explaining the goal of Tune & Match training (hear a note, match its pitch)
  - [ ] 2.2 Write help section explaining the controls (vertical slider, touch to start target note, drag to adjust, release to commit)
  - [ ] 2.3 Write help section explaining the feedback indicator (cent error display, what values mean)
  - [ ] 2.4 Write help section for interval mode: how pitch matching works with intervals

- [ ] Task 3: Add help button and sheet to ComparisonScreen (AC: #1, #3, #5)
  - [ ] 3.1 Add `@State private var showHelpSheet = false` to `ComparisonScreen`
  - [ ] 3.2 Add toolbar help button (`questionmark.circle`) alongside existing Settings and Profile buttons
  - [ ] 3.3 Add `.sheet(isPresented: $showHelpSheet)` presenting help content via `HelpContentView`
  - [ ] 3.4 Wrap help content in `NavigationStack` with localized title and "Done" dismiss button (same pattern as SettingsScreen)
  - [ ] 3.5 Define `static let helpSections: [HelpSection]` on `ComparisonScreen` with all help texts using `String(localized:)`
  - [ ] 3.6 Ensure showing the help sheet stops training via `comparisonSession.stop()` and dismissing restarts it — OR verify that `.onDisappear`/`.onAppear` already handles this naturally when the sheet covers the screen

- [ ] Task 4: Add help button and sheet to PitchMatchingScreen (AC: #1, #3, #5)
  - [ ] 4.1 Add `@State private var showHelpSheet = false` to `PitchMatchingScreen`
  - [ ] 4.2 Add toolbar help button (`questionmark.circle`) alongside existing Settings and Profile buttons
  - [ ] 4.3 Add `.sheet(isPresented: $showHelpSheet)` presenting help content via `HelpContentView`
  - [ ] 4.4 Wrap help content in `NavigationStack` with localized title and "Done" dismiss button
  - [ ] 4.5 Define `static let helpSections: [HelpSection]` on `PitchMatchingScreen` with all help texts using `String(localized:)`
  - [ ] 4.6 Same training stop/restart consideration as Task 3.6

- [ ] Task 5: Add localization for all help strings (AC: #4)
  - [ ] 5.1 Add all new English help strings as `String(localized:)` in SwiftUI (auto-detected by String Catalog)
  - [ ] 5.2 Add German translations for all new strings using `bin/add-localization.py`
  - [ ] 5.3 Verify with `bin/add-localization.py --missing` that no translations are missing

- [ ] Task 6: Write tests (AC: #1, #2, #4)
  - [ ] 6.1 Test that `ComparisonScreen.helpSections` returns expected section count
  - [ ] 6.2 Test that each ComparisonScreen help section title matches expected titles in order
  - [ ] 6.3 Test that each ComparisonScreen help section has a non-empty body
  - [ ] 6.4 Test that ComparisonScreen includes interval-related help content
  - [ ] 6.5 Test that `PitchMatchingScreen.helpSections` returns expected section count
  - [ ] 6.6 Test that each PitchMatchingScreen help section title matches expected titles in order
  - [ ] 6.7 Test that each PitchMatchingScreen help section has a non-empty body
  - [ ] 6.8 Test that PitchMatchingScreen includes interval-related help content

- [ ] Task 7: Build and verify (AC: #1, #2, #3, #4, #5)
  - [ ] 7.1 Run `bin/build.sh` — clean build
  - [ ] 7.2 Run `bin/test.sh` — all tests pass
  - [ ] 7.3 Run `bin/check-dependencies.sh` — dependency rules pass
  - [ ] 7.4 Verify English and German help content manually in simulator

## Dev Notes

### Implementation Approach: HelpContentView Sheet on Both Training Screens

The `HelpContentView` reusable component (created in the quick spec "Template-Based Localized Help Content") already exists at `Peach/App/HelpContentView.swift`. It takes `[HelpSection]` and renders each section as a `.headline` title + Markdown body text with `AttributedString(markdown:)`.

The approach is to add a toolbar help button to **both** `ComparisonScreen` and `PitchMatchingScreen` that presents a `.sheet()` containing `HelpContentView` with mode-specific help sections. This mirrors exactly how `SettingsScreen` already implements help.

**Proposed help presentation structure (same for both screens):**
```swift
.sheet(isPresented: $showHelpSheet) {
    NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                HelpContentView(sections: Self.helpSections)
            }
            .padding()
        }
        .navigationTitle("Training Help")  // or mode-specific title
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { showHelpSheet = false }
            }
        }
    }
}
```

### Training Session Stop/Restart on Help Access (AC #3)

**Critical consideration:** When the help sheet appears, training must not corrupt state.

Both training screens use `.onDisappear { session.stop() }` and `.onAppear { session.start(intervals:) }`. A SwiftUI `.sheet()` does **NOT** trigger `onDisappear` of the presenting view — the parent view remains in the hierarchy.

**Two approaches:**
1. **Explicit stop/start:** Add an `.onChange(of: showHelpSheet)` modifier that calls `session.stop()` when true and `session.start(intervals:)` when false
2. **Natural behavior:** The sheet covers the screen, audio continues playing in background — this may actually be fine since the user can't interact with buttons/slider while the sheet is showing

**Recommended:** Use approach 1 (explicit stop/start) to be safe. Audio playing while reading help would be confusing. Wire `showHelpSheet` changes to session stop/start.

### Help Content Design for Each Screen

**ComparisonScreen help sections:**

| Section | Content Focus |
|---------|--------------|
| Goal | What Hear & Compare does: two notes play, you decide which is higher |
| Controls | Higher/Lower buttons, they activate after both notes play |
| Feedback | Checkmark = correct, X = incorrect, shown briefly after each answer |
| Difficulty | The number shows the cent difference between notes — smaller = harder, session best tracks your peak |
| Intervals | (Only relevant for interval mode) What intervals are, how they change the training |

**PitchMatchingScreen help sections:**

| Section | Content Focus |
|---------|--------------|
| Goal | What Tune & Match does: hear a reference note, slide to match it |
| Controls | Vertical slider — touch to hear your note, drag to adjust pitch, release to lock in answer |
| Feedback | Shows how close you were in cents — smaller number = better match |
| Intervals | (Only relevant for interval mode) How intervals change the pitch matching target |

### Help Content Guidelines

- **Tone:** Friendly, encouraging, non-technical — same as Story 37.1 and 37.2
- **Length:** Brief — 2-4 sentences per section. Training help should be practical, not encyclopedic
- **Interval section:** Include in both screens' helpSections as the last section — it applies to interval training variants of both modes
- **German translations:** Must be idiomatic German, not literal translations

### Key Files to Modify

| File | Change |
|------|--------|
| `Peach/Comparison/ComparisonScreen.swift` | Add `helpSections` static property, `showHelpSheet` state, help button in toolbar, help sheet, stop/start on sheet toggle |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Same changes as ComparisonScreen but with pitch matching-specific help content |
| `Peach/Resources/Localizable.xcstrings` | Add German translations for all new help strings |
| `PeachTests/Comparison/ComparisonScreenLayoutTests.swift` | Add help section tests (or create separate test file — follow convention) |
| `PeachTests/PitchMatching/PitchMatchingScreenTests.swift` | Add help section tests |

### No New Files Needed

All changes go into existing files. The `HelpContentView` and `HelpSection` types already exist in `Peach/App/HelpContentView.swift`. Test additions go into existing test files.

### Existing Patterns to Follow

- **`SettingsScreen` help implementation (Story 37.2):** `static let helpSections: [HelpSection]`, `@State private var showHelpSheet`, toolbar `questionmark.circle` button, `.sheet` with `NavigationStack` + `ScrollView` + `HelpContentView` + "Done" button — **replicate this pattern exactly**
- **`String(localized:)` for help text:** Each section body is a `String(localized:)` with Markdown formatting for bold terms
- **Toolbar button placement:** Both training screens already have a `ToolbarItem(placement: .navigationBarTrailing)` with Settings + Profile buttons in an `HStack(spacing: 20)` — add the help button to this same HStack
- **Static constants:** Define help content as `static let` properties for testability
- **Test pattern:** Title verification in order, non-empty body check, key term verification for specific sections (see `SettingsTests.swift` lines 240-279)

### Architecture & Constraints

- **No new dependencies** — pure SwiftUI text content, reuses existing `HelpContentView`
- **No cross-feature coupling** — changes stay within `Comparison/` and `PitchMatching/` feature directories plus shared `Resources/`; `HelpContentView` is in `App/` (shared layer), accessible from all features
- **No business logic** — static help text only (plus session stop/start for AC #3)
- **SwiftUI String Catalogs** — English strings defined in code, German translations added via `bin/add-localization.py`
- **Zero third-party dependencies** — do not add any external packages
- **Dependency direction:** `Comparison/` and `PitchMatching/` can import from `Core/` and use `App/` types — `HelpContentView` in `App/` is already accessible

### What NOT to Do

- Do NOT create separate help screen files (`ComparisonHelpScreen.swift`, etc.) — build the help sheet directly in the training screens using `HelpContentView`
- Do NOT add images or illustrations — text only
- Do NOT add interactive tutorials or animated walkthroughs — that would be a separate story
- Do NOT modify existing training logic — help is read-only content presentation plus session pause/resume
- Do NOT change the training session protocols — use the existing `stop()` and `start(intervals:)` methods
- Do NOT add per-control inline help — this story adds a comprehensive help sheet per screen
- Do NOT let audio continue playing while the help sheet is shown — stop the session

### Previous Story Intelligence

**From Story 37.2 (Settings Screen Help):**
- `SettingsScreen.helpSections` pattern works well — static array of `HelpSection` with `String(localized:)` bodies
- Toolbar `questionmark.circle` button integrates cleanly with existing navigation bar items
- Sheet presentation with `NavigationStack` + "Done" button is the standard pattern
- Tests verify: section count, title order, non-empty bodies, key terms in specific sections
- 944 tests passing as of story 37.2 completion

**From Story 37.1 (Start Screen Help) and Quick Spec (Template-Based Localized Help Content):**
- `HelpContentView` component lives at `Peach/App/HelpContentView.swift`
- `HelpSection` struct has `title: String` and `body: String` properties
- Markdown supports **bold**, *italic*, [links](url), but NOT headers, lists, or block-level elements
- `\n\n` creates paragraph breaks within a section body
- Help content uses `String(localized:)` for all user-visible text

**From Story 36.1 (Localization and Wording Review):**
- German terminology settled: "Cent" singular/plural, "Übung" for training
- Training screen titles: "Hear & Compare" / "Tune & Match" (English), localized equivalents in German

### Git Intelligence

Recent commits (most recent first):
1. `c2fbce5` Review story 37.2: Stronger tests with title verification and title-based lookup
2. `7f6cde2` Implement story 37.2: Settings Screen Help
3. `89e8162` Create story 37.2: Settings Screen Help
4. `1cee06b` Implement quick spec: Template-Based Localized Help Content
5. `0f7feed` Create quick spec: Template-Based Localized Help Content

The codebase is clean and stable. The `HelpContentView` pattern is fresh, proven, and used in both InfoScreen and SettingsScreen.

### Training Session Lifecycle Reference

**ComparisonSession:**
- `start(intervals:)` — begins training, transitions from `.idle` to `.playingNote1`
- `stop()` — halts training, transitions back to `.idle`
- Guards prevent double-start or double-stop

**PitchMatchingSession:**
- `start(intervals:)` — begins training
- `stop()` — halts training, transitions back to `.idle`
- Same guard pattern as ComparisonSession

Both sessions are injected via `@Environment` and are `@Observable`. The screens call `start()` in `.onAppear` and `stop()` in `.onDisappear`. For the help sheet, use `.onChange(of: showHelpSheet)` since sheets don't trigger appear/disappear on the parent.

### Project Structure Notes

- Changes align with existing `Comparison/` and `PitchMatching/` feature directories
- No new directories or files needed
- `HelpContentView` in `App/` is already accessible from both feature directories
- Test coverage extends existing test files in `PeachTests/Comparison/` and `PeachTests/PitchMatching/`

### References

- [Source: docs/planning-artifacts/epics.md#Epic 37, Story 37.3]
- [Source: docs/project-context.md#Framework-Specific Rules — SwiftUI Views, String Catalogs]
- [Source: Peach/Comparison/ComparisonScreen.swift — current ComparisonScreen with toolbar and session lifecycle]
- [Source: Peach/PitchMatching/PitchMatchingScreen.swift — current PitchMatchingScreen with toolbar and session lifecycle]
- [Source: Peach/App/HelpContentView.swift — reusable HelpContentView component]
- [Source: Peach/Settings/SettingsScreen.swift — pattern for help button + sheet implementation]
- [Source: docs/implementation-artifacts/37-2-settings-screen-help.md — previous story learnings]
- [Source: docs/implementation-artifacts/37-1-start-screen-help.md — first help story learnings]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

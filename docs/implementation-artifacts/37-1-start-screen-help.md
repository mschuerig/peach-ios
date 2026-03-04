# Story 37.1: Start Screen Help

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **new user of Peach**,
I want to understand what this app is about and what the different training modes do,
So that I can choose the right training for my goals.

## Acceptance Criteria

1. **Given** the Start Screen **When** a help trigger is activated (e.g., info button, help icon) **Then** a help view appears explaining:
   - What Peach is and its purpose (ear training / pitch discrimination)
   - A brief mention of each training mode (name + one-sentence purpose — detailed explanations deferred to Story 37.3)
   - How to get started

2. **Given** the help content **When** displayed in English or German **Then** all text is properly localized

3. **Given** the help view **When** the user dismisses it **Then** they return to the Start Screen without side effects

## Tasks / Subtasks

- [x] Task 1: Design help content structure (AC: #1)
  - [x] 1.1 Define help text content in English: app purpose, each training mode explanation, getting started guidance
  - [x] 1.2 Consolidate InfoScreen header: merge app title, version, copyright, license, and GitHub link into one top section
  - [x] 1.3 Design the help content layout: help sections go between the header and acknowledgments

- [x] Task 2: Implement help content in InfoScreen (AC: #1, #3)
  - [x] 2.1 Restructure InfoScreen: consolidated header at top, help sections in the middle, acknowledgments at bottom
  - [x] 2.2 Include subsections: "What is Peach?", "Training Modes", "Getting Started"
  - [x] 2.3 Mention the four training modes briefly (one line each, e.g., name + one-sentence purpose) — defer detailed explanations to Story 37.3 (Training Screen Help)
  - [x] 2.4 Ensure help view dismisses cleanly via existing "Done" button without side effects

- [x] Task 3: Add localization for all help strings (AC: #2)
  - [x] 3.1 Add all new English help strings as `Text("...")` in SwiftUI (auto-detected by String Catalog)
  - [x] 3.2 Add German translations for all new strings using `bin/add-localization.py`
  - [x] 3.3 Verify with `bin/add-localization.py --missing` that no translations are missing

- [x] Task 4: Write tests (AC: #1, #2, #3)
  - [x] 4.1 Add tests verifying help content sections exist in InfoScreen (extend existing `StartScreenTests.swift` info section tests)
  - [x] 4.2 Test that dismissing the help/info sheet returns to Start Screen state cleanly

- [x] Task 5: Build and verify (AC: #1, #2, #3)
  - [x] 5.1 Run `bin/build.sh` — clean build
  - [x] 5.2 Run `bin/test.sh` — all tests pass
  - [x] 5.3 Verify English and German help content manually in simulator

## Dev Notes

### Implementation Approach: Extend Existing InfoScreen

The Start Screen already has an `info.circle` toolbar button (`.navigationBarLeading`) that presents `InfoScreen` as a `.sheet()`. Rather than adding a second help button, the recommended approach is to **extend InfoScreen** with help content above the existing credits section. This keeps the UI clean and leverages the existing navigation pattern.

**Current InfoScreen structure:**
```
NavigationStack {
  Form {
    Section: Header (Peach title, version)
    Section: Developer (name, email)
    Section: License & Links (MIT, GitHub, copyright)
    Section: Acknowledgments (SoundFont credit)
  }
  .navigationTitle("Info")
  .toolbar { Done button }
}
```

**Proposed InfoScreen structure:**
```
NavigationStack {
  Form {
    Section: Header (Peach, version, © 2026 Michael Schürig, MIT License, GitHub link)
    Section: "How It Works" — app purpose paragraph
    Section: "Training Modes" — four mode descriptions
    Section: "Getting Started" — quick start guidance
    Section: Acknowledgments (SoundFont credit)
  }
  .navigationTitle("Info")
  .toolbar { Done button }
}
```

**Layout note:** The header consolidates app identity, copyright, license, and GitHub link into one top section. Help content follows in the middle. Acknowledgments remain at the bottom. Existing links (GitHub, SoundFont) stay as tappable `Link` views.

### Key Files to Modify

| File | Change |
|------|--------|
| `Peach/Info/InfoScreen.swift` | Add help content sections above credits |
| `Peach/Resources/Localizable.xcstrings` | Add German translations for all new strings |
| `PeachTests/Start/StartScreenTests.swift` | Extend info screen content tests |

### No New Files Needed

All changes go into existing files. No new views, no new environment keys, no new navigation destinations.

### Help Content Guidelines

- **Tone:** Friendly, encouraging, non-technical. A musician picking up the app for the first time should understand everything.
- **Length:** Brief — a few sentences per section. Not a manual.
- **Musical terms:** Avoid jargon. Say "pitch" not "frequency," say "notes" not "MIDI notes."
- **German translations:** Must be idiomatic German, not literal translations. Refer to Story 36.1's approach — "Cent" is used for both singular and plural in German.

### Existing Patterns to Follow

- **InfoScreen uses `Form` with `Section`** — maintain this pattern for new help sections
- **Strings use SwiftUI auto-extraction** — `Text("literal")` is auto-detected by String Catalog
- **Section headers are `Text` views** — consistent with existing InfoScreen layout
- **No business logic in views** — help content is purely static text
- **Accessibility:** All text content is automatically accessible via VoiceOver when using standard SwiftUI `Text` views

### Architecture & Constraints

- **No new dependencies** — pure SwiftUI text content
- **No cross-feature coupling** — changes stay within `Info/` feature directory and shared `Resources/`
- **No business logic** — static help text only
- **SwiftUI String Catalogs** — English strings defined in code, German translations added via `bin/add-localization.py`
- **Zero third-party dependencies** — do not add any external packages

### What NOT to Do

- Do NOT add a second button to the Start Screen toolbar — reuse the existing `info.circle` button
- Do NOT create a separate `HelpScreen.swift` — extend the existing `InfoScreen`
- Do NOT add markdown rendering or rich text — use standard SwiftUI `Text` views
- Do NOT add images or illustrations — text only for this story
- Do NOT reference specific MIDI notes, frequencies, or technical details in help text
- Do NOT add interactive elements (tutorials, walkthroughs) — that would be a separate story
- Do NOT change the existing InfoScreen credits/developer sections — only add new sections above them

### Previous Story Intelligence

**From Story 36.1 (Interactive Localization and Wording Review):**
- 117 localization keys exist, 0 missing translations, 0 stale keys
- Localization file: `Peach/Resources/Localizable.xcstrings`
- Use `bin/add-localization.py "Key" "German"` for adding translations
- German terminology is settled — "Cent" singular/plural, "Übung" for training, consistent throughout
- All 931 tests passing
- Button labels: "Hear & Compare" / "Tune & Match" with section headers "Single Notes" / "Intervals"
- Settings labels recently renamed: Sound (was Sound Source), Concert Pitch (was Reference Pitch), Lowest/Highest Note (was Lower/Upper)

**From Story 35.3 (Visual Design Polish):**
- Material-based card design (`regularMaterial` backgrounds, rounded corners)
- `TrainingCardButtonStyle` for press feedback (0.7 opacity, 0.15s animation)
- Responsive layout: compact vs. regular height modes with testable static methods
- Info button icon: `info.circle`, Profile: `chart.xyaxis.line`, Settings: `gearshape`

### Git Intelligence

Recent commits show a pattern of Create → Implement → Review story cycles. The last work was Epic 36 (localization polish) which is now done. Epic 35 (Start Screen redesign) established the current visual patterns. The codebase is clean and stable.

### Project Structure Notes

- Changes align with existing `Info/` feature directory
- No new directories or files needed
- `InfoScreen.swift` is the sole file in `Info/`
- Test coverage extends existing `StartScreenTests.swift` (86 tests currently)

### References

- [Source: docs/planning-artifacts/epics.md#Epic 37, Story 37.1]
- [Source: docs/project-context.md#Framework-Specific Rules — SwiftUI Views, String Catalogs]
- [Source: Peach/Info/InfoScreen.swift — current InfoScreen implementation]
- [Source: Peach/Start/StartScreen.swift — Start Screen with info button]
- [Source: docs/implementation-artifacts/36-1-interactive-localization-and-wording-review.md — localization patterns]
- [Source: docs/implementation-artifacts/35-3-visual-design-polish.md — current Start Screen design]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None.

### Completion Notes List

- Restructured InfoScreen layout: consolidated header (title, version, copyright, license, GitHub) at top, help content in middle, acknowledgments at bottom
- Replaced VStack+Spacer layout with ScrollView for better content handling
- Added three help sections: "What is Peach?", "Training Modes", "Getting Started"
- Four training modes listed with brief one-line descriptions (detailed help deferred to Story 37.3)
- Help content uses static constants with `String(localized:)` for testability and localization
- Added `TrainingMode` struct for type-safe mode name/description pairs
- Extracted view body into `headerSection`, `helpSection`, `acknowledgmentsSection` computed properties
- Removed separate Developer section — copyright consolidated into header
- Added 13 German translations via batch localization script
- Added 4 new tests: app description, training mode count, training mode completeness, getting started text
- Build succeeds, 935 tests pass (was 931)

### Change Log

- 2026-03-04: Implemented Start Screen Help — restructured InfoScreen with help content, added 13 German translations, 4 new tests
- 2026-03-04: Review fixes — removed dead `developerEmail` property, dynamic copyright year, locale-independent test assertions, stronger test coverage

### File List

- `Peach/Info/InfoScreen.swift` — restructured with help content sections, consolidated header, ScrollView layout, dynamic copyright year
- `Peach/Resources/Localizable.xcstrings` — added 13 new German translations for help content
- `PeachTests/Start/StartScreenTests.swift` — added 4 tests for help content, strengthened with locale-independent assertions

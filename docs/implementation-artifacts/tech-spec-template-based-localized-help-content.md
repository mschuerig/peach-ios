---
title: 'Template-Based Localized Help Content'
slug: 'template-based-localized-help-content'
created: '2026-03-05'
status: 'complete'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'SwiftUI', 'String Catalogs (xcstrings)', 'iOS 26']
files_to_modify: ['Peach/App/HelpContentView.swift (new)', 'Peach/Info/InfoScreen.swift', 'Peach/Resources/Localizable.xcstrings', 'PeachTests/Start/StartScreenTests.swift', 'PeachTests/App/HelpContentViewTests.swift (new)']
code_patterns: ['String(localized:) for localized content', 'AttributedString(markdown:) for Markdown rendering from String variables', 'VStack with .leading alignment for help sections', 'Static constants for testability', 'Zero third-party dependencies']
test_patterns: ['Swift Testing (@Test, @Suite, #expect)', 'Async test functions', 'Locale-independent assertions (check for "Peach" not English-specific words)', 'Static property testing for content verification']
---

# Tech-Spec: Template-Based Localized Help Content

**Created:** 2026-03-05

## Overview

### Problem Statement

InfoScreen has 13+ individual `String(localized:)` calls for small text fragments. This fragments context for translators, creates many localization keys, and makes content hard to maintain. Upcoming stories 37.2 (Settings help) and 37.3 (Training help) will add even more fragmented strings following the same pattern.

### Solution

Replace per-fragment localization with per-section localized Markdown templates using Swift string interpolation for dynamic values. Create a reusable `HelpContentView` component that renders localized Markdown content, usable across InfoScreen, SettingsScreen, and TrainingScreen help screens.

### Scope

**In Scope:**
- Refactor InfoScreen to use localized Markdown templates instead of many individual strings
- Create a reusable help content rendering component
- Use native SwiftUI Markdown support + `String(localized:)` interpolation
- Update German translations for consolidated keys
- Update tests

**Out of Scope:**
- Custom templating engine
- Stories 37.2 / 37.3 implementation (those will use the new pattern)
- Changes to non-help screens

## Context for Development

### Codebase Patterns

- **Localization**: `String(localized: "English text")` — the English text IS the String Catalog key. German translations added via `bin/add-localization.py`.
- **SwiftUI Markdown**: `Text("**bold**")` with string literals renders Markdown automatically. But `Text(stringVariable)` does NOT render Markdown — must use `Text(AttributedString(markdown: str))` or `Text(LocalizedStringKey(str))`.
- **Markdown limitations in SwiftUI Text**: Only inline Markdown: **bold**, *italic*, ~~strikethrough~~, `code`, [links](url). No headers, lists, or block-level elements. `\n\n` creates paragraph breaks.
- **View structure**: Views are thin — no business logic. Subviews extracted at ~40 lines. `@Environment(\.dismiss)` for sheet dismissal.
- **File placement**: Feature directories (`Info/`, `Settings/`, etc.) must not reference types from other features. Shared UI goes in `App/`. Shared non-UI types go in `Core/` (no SwiftUI imports).
- **Static constants**: Help content uses `static let` properties with `String(localized:)` for testability (tests can access `InfoScreen.appDescription` etc.).
- **Test rules**: Swift Testing only, `async` on all test functions, locale-independent assertions (simulator may run in German).

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Info/InfoScreen.swift` | Current implementation with 13+ individual localized strings |
| `Peach/Resources/Localizable.xcstrings` | String Catalog with English keys + German translations |
| `PeachTests/Start/StartScreenTests.swift` | Existing tests for InfoScreen content (lines 169-192) |
| `Peach/App/ContentView.swift` | Example of shared SwiftUI component in App/ |
| `docs/project-context.md` | Project rules and conventions |

### Technical Decisions

- **Markdown rendering**: Use `AttributedString(markdown:)` to parse Markdown from `String(localized:)` results, since `Text(stringVar)` doesn't render Markdown.
- **Section structure**: Section headers remain as SwiftUI `Text` views with `.headline` font. Section bodies are localized Markdown strings rendered via `AttributedString`. This keeps visual hierarchy clear while consolidating localization keys.
- **Template granularity**: One localized string per section body. Training modes consolidated from 8 strings → 1 Markdown string with bold names. Overall reduction: 13+ keys → ~6.
- **Reusable component location**: `Peach/App/HelpContentView.swift` — the App/ directory is the shared SwiftUI layer accessible from all features.
- **No custom templating**: Swift string interpolation within `String(localized:)` for dynamic values. No placeholder replacement engine.
- **Header stays structured**: The header section (large title, version, copyright, license, GitHub link) keeps its structured SwiftUI layout because it requires varied font sizes (`.largeTitle` vs `.caption`) that can't be achieved in a single Markdown string.
- **Acknowledgments via Markdown link**: The acknowledgments section can use a Markdown `[text](url)` link within a template string, rendered by `HelpContentView`.

## Implementation Plan

### Tasks

- [x] Task 1: Create `HelpSection` and `HelpContentView` in `Peach/App/HelpContentView.swift`
  - File: `Peach/App/HelpContentView.swift` (new)
  - Action: Create a `HelpSection` struct with `title: String` and `body: String` properties. Create `HelpContentView` that takes `[HelpSection]` and renders each section as a `.headline` title + Markdown body text.
  - Details:
    - `HelpSection` has two `String` properties (both expected to be already localized by the caller)
    - `HelpContentView` uses `VStack(alignment: .leading, spacing: 20)` for sections
    - Each section: `VStack(alignment: .leading, spacing: 8)` with `Text(title).font(.headline)` + `Text(AttributedString(markdown: body))` with `.foregroundStyle(.secondary)`
    - Provide a private helper `func markdownText(_ string: String) -> Text` that handles `AttributedString(markdown:)` with fallback to plain text
    - Add `.frame(maxWidth: .infinity, alignment: .leading)`
    - Add `#Preview` with sample sections

- [x] Task 2: Consolidate InfoScreen help content into template strings
  - File: `Peach/Info/InfoScreen.swift`
  - Action: Replace the 13+ individual `String(localized:)` calls with ~3 consolidated localized Markdown strings:
    - `appDescription` — stays as-is (already 1 string)
    - `trainingModesDescription` — NEW: one Markdown string with all 4 modes using **bold** names and em-dash descriptions, separated by `\n\n`
    - `gettingStartedText` — stays as-is (already 1 string)
  - Remove: `TrainingMode` struct, `trainingModes` array (no longer needed — content is in the template string)
  - Keep: Section title strings ("What is Peach?", "Training Modes", "Getting Started") as they are short and needed by `HelpSection`
  - Add a static `helpSections` property that returns `[HelpSection]` composing the 3 sections

- [x] Task 3: Refactor InfoScreen view body to use `HelpContentView`
  - File: `Peach/Info/InfoScreen.swift`
  - Action: Replace `helpSection` computed property with `HelpContentView(sections: Self.helpSections)`. Refactor `acknowledgmentsSection` to also use `HelpContentView` with a Markdown link: `[GeneralUser GS by S. Christian Collins](url)`.
  - Keep: `headerSection` as-is (needs `.largeTitle` + `.caption` font variation)
  - Remove: `helpSection` and `acknowledgmentsSection` computed properties

- [x] Task 4: Update German translations for consolidated keys
  - File: `Peach/Resources/Localizable.xcstrings`
  - Action: Use `bin/add-localization.py` to add German translations for new consolidated strings. Remove stale keys for the old individual strings (will happen automatically on next Xcode build, or manually).
  - Key changes:
    - NEW: `trainingModesDescription` template string → German Markdown equivalent
    - REMOVE (stale): individual mode name/description keys (8 keys)
    - KEEP: `appDescription`, `gettingStartedText`, section titles (unchanged)
  - Run `bin/add-localization.py --missing` to verify no translations are missing

- [x] Task 5: Update tests
  - File: `PeachTests/Start/StartScreenTests.swift`
  - Action: Update help content tests to reflect new structure:
    - Remove `infoScreenHasFourTrainingModes` (no more `trainingModes` array)
    - Remove `infoScreenTrainingModesAreComplete` (no more `TrainingMode` struct)
    - Add test for `trainingModesDescription` containing key terms (e.g., "–" separator, "Peach" not required here)
    - Add test for `helpSections` returning expected count (3 sections)
    - Keep `infoScreenHasAppDescription` and `infoScreenHasGettingStarted` (unchanged)
  - File: `PeachTests/App/HelpContentViewTests.swift` (new)
  - Action: Add tests for `HelpContentView` / `HelpSection`:
    - `HelpSection` can be instantiated with title and body
    - `HelpContentView` can be instantiated with an array of sections

- [x] Task 6: Build, test, and verify
  - Action: Run `bin/build.sh` — clean build with no errors
  - Action: Run `bin/test.sh` — all tests pass
  - Action: Run `bin/add-localization.py --missing` — no new missing translations
  - Action: Run `bin/check-dependencies.sh` — dependency rules pass

### Acceptance Criteria

- [x] AC 1: Given InfoScreen is displayed, when viewing help content, then all three help sections (What is Peach?, Training Modes, Getting Started) appear with correct content and inline Markdown formatting (bold mode names).

- [x] AC 2: Given InfoScreen in German locale, when viewing help content, then all section titles and body text appear in German with correct Markdown formatting.

- [x] AC 3: Given the `HelpContentView` component, when used with an array of `HelpSection` values, then each section renders with a `.headline` title and Markdown-formatted body text.

- [x] AC 4: Given the refactored InfoScreen, when counting localization keys for help content, then there are fewer keys than before (~6 vs 13+) while maintaining the same user-visible content.

- [x] AC 5: Given the acknowledgments section, when rendered, then the SoundFont credit appears as a clickable Markdown link.

- [x] AC 6: Given the header section, when displayed, then it still shows Peach title (large), version, dynamic copyright year, license, and GitHub link — unchanged from current behavior.

## Additional Context

### Dependencies

- No external dependencies. Pure SwiftUI refactor.
- Depends on Story 37.1 being complete (done).

### Testing Strategy

- **Unit tests**: Verify static content properties exist and contain expected content (locale-independent checks using "Peach", "–", link URLs).
- **Component tests**: Verify `HelpContentView` and `HelpSection` can be instantiated.
- **Integration**: `bin/build.sh` + `bin/test.sh` + `bin/check-dependencies.sh` as gate.
- **Manual**: Verify Markdown renders correctly (bold text, clickable links) in simulator for both English and German.

### Notes

- **Markdown rendering fallback**: If `AttributedString(markdown:)` throws (malformed Markdown), fall back to plain `AttributedString(str)`. This ensures the screen never crashes on bad content.
- **String Catalog key format**: Multiline localized strings will have multiline keys in the xcstrings file. This is standard — Xcode handles it correctly.
- **Future reuse**: Stories 37.2 and 37.3 will create their own `helpSections` arrays and pass them to `HelpContentView`. No changes to the component needed.
- **Training mode names contain "–" (en dash)**: This character is present in both English and German names, making it a reliable locale-independent test anchor.

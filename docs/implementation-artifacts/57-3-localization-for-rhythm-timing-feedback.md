# Story 57.3: Localization for Rhythm Timing Feedback

Status: done

## Story

As a **user with German locale**,
I want the timing feedback indicator and updated help text to be properly localized,
So that the new feedback is understandable in my language.

## Context

Story 57.2 introduces `RhythmTimingFeedbackIndicator` with direction arrows, millisecond offsets, and updated help text. This story adds German translations for all new strings and ensures VoiceOver labels are localized.

### Key files

- `Peach/ContinuousRhythmMatching/RhythmTimingFeedbackIndicator.swift` — new feedback strings
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` — updated help text
- `Peach/Localizable.xcstrings` — string catalog
- `bin/add-localization.swift` — localization tool

## Acceptance Criteria

1. **Feedback indicator in German** — The millisecond unit and any direction terms are translated.

2. **Help text in German** — The updated "Feedback" help section is translated, using informal "du" form.

3. **VoiceOver in German** — Accessibility labels like "5 Millisekunden zu früh" / "3 Millisekunden zu spät" / "Volltreffer" are provided.

4. **No missing keys** — `bin/add-localization.swift --missing` reports no missing keys for rhythm timing feedback strings.

## Tasks / Subtasks

- [x] Task 1: Identify all new localizable strings from Story 57.2
  - [x] Feedback text: "ms" unit, direction accessibility labels
  - [x] Help text: updated "Feedback" section content
  - [x] Any new accessibility hints

- [x] Task 2: Add German translations
  - [x] Use `bin/add-localization.swift` for each string
  - [x] Ensure informal form ("du"/imperative) per project convention
  - [x] Accessibility: "X Millisekunden zu früh" / "X Millisekunden zu spät" / "Volltreffer"

- [x] Task 3: Verify completeness
  - [x] Run `bin/add-localization.swift --missing`
  - [x] Confirm zero missing keys for the new strings

## Technical Notes

- "ms" is a standard abbreviation that works in both English and German. The unit string may not need translation, but the accessibility labels do (VoiceOver should read "Millisekunden", not "ms").
- Follow the pattern from `PitchMatchingFeedbackIndicator` localization: "cents sharp"/"cents flat" → "Cent zu hoch"/"Cent zu tief". The rhythm equivalent: "milliseconds early"/"milliseconds late" → "Millisekunden zu früh"/"Millisekunden zu spät".

## Dev Agent Record

### Implementation Plan

Accessibility labels in `RhythmTimingFeedbackIndicator.accessibilityLabel()` were using abbreviated "ms early"/"ms late" interpolated strings. Changed to use concatenated `String(localized: "milliseconds early")` / `String(localized: "milliseconds late")` keys so VoiceOver reads the full word "Millisekunden" in German. Updated German translations from "Millisekunden früh/spät" to "Millisekunden zu früh/zu spät" to match the pitch matching pattern ("Cent zu hoch/zu tief"). Marked old `%lld ms early`/`%lld ms late` keys as stale.

### Debug Log

No issues encountered.

### Completion Notes

- Fixed VoiceOver accessibility labels to use full "milliseconds" instead of abbreviated "ms"
- Updated German translations: "Millisekunden zu früh" / "Millisekunden zu spät" / "Volltreffer"
- Help text "Feedback" section was already translated with informal "du" form
- "ms" unit display string unchanged (same abbreviation in both languages)
- Marked stale `%lld ms early`/`%lld ms late` keys in string catalog
- Updated 3 test expectations to match new accessibility label format
- All 1460 tests pass, 0 missing localization keys

## File List

- `Peach/ContinuousRhythmMatching/RhythmTimingFeedbackIndicator.swift` — changed accessibility labels from interpolated "ms" to concatenated "milliseconds" keys
- `Peach/Resources/Localizable.xcstrings` — updated German translations for "milliseconds early/late", marked old "ms early/late" keys stale
- `PeachTests/ContinuousRhythmMatching/RhythmTimingFeedbackIndicatorTests.swift` — updated accessibility label test expectations

## Change Log

- 2026-03-23: Implemented story 57.3 — fixed VoiceOver accessibility labels and German translations for rhythm timing feedback

# Story 57.3: Localization for Rhythm Timing Feedback

Status: backlog

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

- [ ] Task 1: Identify all new localizable strings from Story 57.2
  - [ ] Feedback text: "ms" unit, direction accessibility labels
  - [ ] Help text: updated "Feedback" section content
  - [ ] Any new accessibility hints

- [ ] Task 2: Add German translations
  - [ ] Use `bin/add-localization.swift` for each string
  - [ ] Ensure informal form ("du"/imperative) per project convention
  - [ ] Accessibility: "X Millisekunden zu früh" / "X Millisekunden zu spät" / "Volltreffer"

- [ ] Task 3: Verify completeness
  - [ ] Run `bin/add-localization.swift --missing`
  - [ ] Confirm zero missing keys for the new strings

## Technical Notes

- "ms" is a standard abbreviation that works in both English and German. The unit string may not need translation, but the accessibility labels do (VoiceOver should read "Millisekunden", not "ms").
- Follow the pattern from `PitchMatchingFeedbackIndicator` localization: "cents sharp"/"cents flat" → "Cent zu hoch"/"Cent zu tief". The rhythm equivalent: "milliseconds early"/"milliseconds late" → "Millisekunden zu früh"/"Millisekunden zu spät".

# Story 54.9: Localization

Status: review

## Story

As a **musician using Peach**,
I want all continuous rhythm matching UI text available in English and German,
so that the app communicates clearly in both languages.

## Acceptance Criteria

1. **Given** the continuous rhythm matching screen, **when** displayed in German, **then** all UI text (button labels, stats, feedback, help content) is localized.

2. **Given** the gap position settings, **when** displayed in German, **then** section headers, toggle labels, and position names are localized.

3. **Given** the Start Screen button, **when** displayed in German, **then** the training mode label is localized.

4. **Given** the profile card and spectrogram, **when** displayed in German, **then** all labels, empty states, and accessibility descriptions are localized.

5. **Given** VoiceOver in German, **when** navigating the continuous rhythm matching screens, **then** all accessibility labels and hints are localized.

6. **Given** `bin/add-localization.swift --missing`, **when** run, **then** no missing keys are reported for continuous rhythm matching strings.

## Tasks / Subtasks

- [x] Task 1: Audit all string literals (AC: #1, #2, #3, #4, #5)
  - [x] Search all files created in Stories 54.1–54.8 for `String(localized:)` keys
  - [x] Compile a list of all strings needing German translations

- [x] Task 2: Add German translations (AC: #1, #2, #3, #4, #5)
  - [x] Use `bin/add-localization.swift` for batch addition
  - [x] Key translations:
    - "Fill the Gap" → "Lücke füllen"
    - "Tap" → "Tippen"
    - "Tap to fill the gap in the rhythm" → "Tippen Sie, um die Lücke im Rhythmus zu füllen"
    - Gap position labels: "Beat"/"E"/"And"/"A" → verify German equivalents
    - Help content sections
    - Stats labels
    - Profile card labels and empty states

- [x] Task 3: Verify completeness (AC: #6)
  - [x] Run `bin/add-localization.swift --missing`
  - [x] Fix any missing translations

- [x] Task 4: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Gap position labels in German

In German music pedagogy, the sixteenth-note subdivision syllables are typically "Eins", "E", "Und", "A" — very similar to the English "One", "E", "And", "A". However, since these are used as short toggle labels in settings, keep them concise. Verify the preferred German convention.

### Follow Epic 53 patterns

This story mirrors Epic 53 (Rhythm Training Localization) — follow the same approach for string extraction, translation, and verification.

### What NOT to do

- Do NOT modify existing localized strings from other training modes
- Do NOT add languages beyond English and German

### References

- [Source: docs/implementation-artifacts/53-1-rhythm-training-localization.md — localization story pattern]
- [Source: bin/add-localization.swift — localization tool usage]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Implementation Plan

Localization-only story: audit existing strings in epic 54 files, add missing German translations via batch localization script, verify zero missing keys.

### Completion Notes

Audited all 35 source files from Stories 54.1–54.8. Found 6 strings missing German translations — all in `ContinuousRhythmMatchingScreen.swift`:

1. Help section body: "A continuous stream of notes plays..." → "Ein durchgehender Notenstrom spielt..."
2. Help section body: "Tap the **Tap** button..." → "Tippe auf die **Tippen**-Taste..."
3. Help section body: "The gap dot briefly changes color..." → "Der Lückenpunkt ändert nach jedem Treffer kurz die Farbe..."
4. Accessibility hint: "Tap to fill the gap in the rhythm" → "Tippen, um die Lücke im Rhythmus zu füllen"
5. Navigation title: "Rhythm – Fill" → "Rhythmus – Füllen"
6. Stats label: "Mean offset: %@" → "Mittlere Abweichung: %@"

Gap position labels ("Beat"/"E"/"And"/"A"), Start Screen button ("Fill the Gap"/"Lücke füllen"), profile card labels, and VoiceOver labels were already translated from earlier stories. All 1585 tests pass with no regressions.

## File List

- Peach/Resources/Localizable.xcstrings (modified — 6 German translations added)

## Change Log

- 2026-03-22: Added 6 missing German translations for continuous rhythm matching UI (help content, accessibility hint, navigation title, stats label)

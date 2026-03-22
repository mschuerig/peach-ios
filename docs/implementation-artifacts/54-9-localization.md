# Story 54.9: Localization

Status: backlog

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

- [ ] Task 1: Audit all string literals (AC: #1, #2, #3, #4, #5)
  - [ ] Search all files created in Stories 54.1–54.8 for `String(localized:)` keys
  - [ ] Compile a list of all strings needing German translations

- [ ] Task 2: Add German translations (AC: #1, #2, #3, #4, #5)
  - [ ] Use `bin/add-localization.swift` for batch addition
  - [ ] Key translations:
    - "Fill the Gap" → "Lücke füllen"
    - "Tap" → "Tippen"
    - "Tap to fill the gap in the rhythm" → "Tippen Sie, um die Lücke im Rhythmus zu füllen"
    - Gap position labels: "Beat"/"E"/"And"/"A" → verify German equivalents
    - Help content sections
    - Stats labels
    - Profile card labels and empty states

- [ ] Task 3: Verify completeness (AC: #6)
  - [ ] Run `bin/add-localization.swift --missing`
  - [ ] Fix any missing translations

- [ ] Task 4: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

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

---
title: 'Fix incorrect and inconsistent localization strings'
slug: 'fix-localization-strings'
created: '2026-03-13'
status: 'completed'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['String Catalogs (Localizable.xcstrings)', 'SwiftUI Text/String(localized:)']
files_to_modify: ['Peach/Resources/Localizable.xcstrings', 'Peach/PitchComparison/PitchComparisonScreen.swift', 'Peach/Profile/ProfileScreen.swift', 'Peach/Profile/ChartTips.swift']
code_patterns: ['String Catalogs use EN text as lookup key — changing EN text requires updating Swift source refs too']
test_patterns: ['No test changes needed — string content corrections only']
---

# Tech-Spec: Fix incorrect and inconsistent localization strings

**Created:** 2026-03-13

## Overview

### Problem Statement

During web app localization alignment, two issues were found in the iOS app's `Localizable.xcstrings`:

1. The comparison controls help text incorrectly states that Higher/Lower buttons activate "after both notes have played" and that "you can't answer while the notes are still playing." In reality, buttons become active as soon as the second (target) note starts playing — users can answer while it's still sounding.
2. Five chart help body strings are complete sentences but are missing trailing periods, inconsistent with proper punctuation.

### Solution

Update the affected strings in `Localizable.xcstrings` (EN keys + DE translations) **and** the corresponding Swift source files that reference these strings by their EN key text.

### Scope

**In Scope:**
- Fix EN + DE for the comparison controls help text (1 key)
- Add trailing periods to 5 chart help body strings (EN + DE)
- Update Swift source references in 3 files where string keys change

**Out of Scope:**
- Help system logic changes
- Adding new localization keys
- TipKit structural changes

## Context for Development

### Codebase Patterns

- **String Catalogs**: `Localizable.xcstrings` uses EN source text as the key. Changing EN text = changing the key, so Swift source files using `String(localized:)` or `Text("...")` must be updated in lockstep.
- **Dual references**: Each chart help string appears in two Swift files — `ProfileScreen.swift` (help modal via `String(localized:)`) and `ChartTips.swift` (tip via `Text()`).
- **Comparison help text**: Referenced in `PitchComparisonScreen.swift` only.

### Files to Reference

| File | Purpose | Lines |
| ---- | ------- | ----- |
| `Peach/Resources/Localizable.xcstrings` | Localization catalog — 6 key+DE pairs to update | ~287, 1741, 1752, 1784, 1816, 1827 |
| `Peach/PitchComparison/PitchComparisonScreen.swift` | Help text for comparison controls | 34 |
| `Peach/Profile/ProfileScreen.swift` | Help modal body strings for chart elements | 70, 76, 82, 88, 94 |
| `Peach/Profile/ChartTips.swift` | Tip message texts for chart elements | 10, 20, 30, 40, 50 |
| `docs/implementation-artifacts/ios-corrections.md` | Source of corrections with exact replacement text | — |

### Technical Decisions

- **Not content-only** — String Catalogs key on EN text, so Swift source files must also be updated when EN text changes
- Both EN source strings and DE translations must be updated in lockstep
- No new keys — the old keys will be replaced by new keys (Xcode handles this via the xcstrings JSON structure)

## Implementation Plan

### Tasks

#### Correction 1: Comparison controls help text

- [x] Task 1: Update the help text string in `PitchComparisonScreen.swift`
  - File: `Peach/PitchComparison/PitchComparisonScreen.swift`
  - Action: At line 34, replace the `String(localized:)` argument from:
    `"After both notes have played, the **Higher** and **Lower** buttons become active. Tap the one that matches what you heard. You can't answer while the notes are still playing."`
    to:
    `"Once the second note starts playing, the **Higher** and **Lower** buttons become active. Tap the one that matches what you heard."`

- [x] Task 2: Update the localization catalog entry for the comparison help text
  - File: `Peach/Resources/Localizable.xcstrings`
  - Action: Replace the old key (`"After both notes have played, the **Higher** and **Lower** buttons become active. Tap the one that matches what you heard. You can't answer while the notes are still playing."`) with the new key (`"Once the second note starts playing, the **Higher** and **Lower** buttons become active. Tap the one that matches what you heard."`) and update the DE translation to:
    `"Sobald der zweite Ton zu spielen beginnt, werden die Tasten **Höher** und **Tiefer** aktiv. Tippe auf die Taste, die zu dem passt, was du gehört hast."`

#### Correction 2: Chart help body trailing periods

For each of the 5 strings below, append a period (`.`) to the EN key in all three locations (xcstrings, ProfileScreen, ChartTips) and append a period to the DE translation in xcstrings.

- [x] Task 3: Add trailing period to "This chart shows how your pitch perception is developing over time"
  - Files: `Peach/Profile/ProfileScreen.swift` (line 70), `Peach/Profile/ChartTips.swift` (line 10), `Peach/Resources/Localizable.xcstrings` (line ~1827)
  - Action: Append `.` to EN string in all three files. In xcstrings, also append `.` to DE value: `"Dieses Diagramm zeigt, wie sich deine Tonwahrnehmung im Laufe der Zeit entwickelt."`

- [x] Task 4: Add trailing period to "The blue line shows your smoothed average — it filters out random ups and downs to reveal your real progress"
  - Files: `Peach/Profile/ProfileScreen.swift` (line 76), `Peach/Profile/ChartTips.swift` (line 20), `Peach/Resources/Localizable.xcstrings` (line ~1741)
  - Action: Append `.` to EN string in all three files. In xcstrings, also append `.` to DE value: `"Die blaue Linie zeigt deinen geglätteten Durchschnitt — sie filtert zufällige Schwankungen heraus, um deinen echten Fortschritt zu zeigen."`

- [x] Task 5: Add trailing period to "The shaded area around the line shows how consistent you are — a narrower band means more reliable results"
  - Files: `Peach/Profile/ProfileScreen.swift` (line 82), `Peach/Profile/ChartTips.swift` (line 30), `Peach/Resources/Localizable.xcstrings` (line ~1816)
  - Action: Append `.` to EN string in all three files. In xcstrings, also append `.` to DE value: `"Der schattierte Bereich um die Linie zeigt, wie beständig du bist — ein schmaleres Band bedeutet zuverlässigere Ergebnisse."`

- [x] Task 6: Add trailing period to "The green dashed line is your goal — as the trend line approaches it, your ear is getting sharper"
  - Files: `Peach/Profile/ProfileScreen.swift` (line 88), `Peach/Profile/ChartTips.swift` (line 40), `Peach/Resources/Localizable.xcstrings` (line ~1784)
  - Action: Append `.` to EN string in all three files. In xcstrings, also append `.` to DE value: `"Die grün gestrichelte Linie ist dein Ziel — wenn sich die Trendlinie ihr nähert, wird dein Gehör schärfer."`

- [x] Task 7: Add trailing period to "The chart groups your data by time: months on the left, recent days in the middle, and today's sessions on the right"
  - Files: `Peach/Profile/ProfileScreen.swift` (line 94), `Peach/Profile/ChartTips.swift` (line 50), `Peach/Resources/Localizable.xcstrings` (line ~1752)
  - Action: Append `.` to EN string in all three files. In xcstrings, also append `.` to DE value: `"Das Diagramm gruppiert deine Daten nach Zeit: Monate links, die letzten Tage in der Mitte und die heutigen Sitzungen rechts."`

#### Verification

- [x] Task 8: Build and run tests
  - Action: Run `bin/build.sh` to verify no broken string references, then run `bin/test.sh` to confirm all tests pass

### Acceptance Criteria

- [ ] AC 1: Given the app is running in English, when the user opens the comparison controls help, then the text reads "Once the second note starts playing, the **Higher** and **Lower** buttons become active. Tap the one that matches what you heard." with no mention of "can't answer while notes are still playing."
- [ ] AC 2: Given the app is running in German, when the user opens the comparison controls help, then the text reads "Sobald der zweite Ton zu spielen beginnt, werden die Tasten **Höher** und **Tiefer** aktiv. Tippe auf die Taste, die zu dem passt, was du gehört hast."
- [ ] AC 3: Given the app is running in English, when the user views any of the 5 chart help body texts, then each ends with a period.
- [ ] AC 4: Given the app is running in German, when the user views any of the 5 chart help body texts, then each ends with a period.
- [ ] AC 5: Given the project builds, when running the full test suite, then all tests pass with no broken string references.

## Additional Context

### Dependencies

None — string content corrections only.

### Testing Strategy

- **Automated**: Build verification (`bin/build.sh`) confirms no broken string key references. Full test suite (`bin/test.sh`) confirms no regressions.
- **Manual**: Switch device language to DE and verify help modal texts display correctly with updated wording and trailing periods.

### Notes

- Corrections originated from web app team alignment effort.
- The comment fields in xcstrings reference "tip message" — these are ChartTips texts (TipKit), not tooltips.
- When editing `Localizable.xcstrings` (JSON), the old key entry must be removed and a new key entry created — do not leave orphaned keys.

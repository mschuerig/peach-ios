# Story 53.1: Rhythm Training Localization

Status: review

## Story

As a **musician using Peach in German**,
I want all rhythm training UI text available in both English and German,
so that the app provides a consistent localized experience across all training modes.

## Acceptance Criteria

1. **Given** `Localizable.xcstrings`, **when** updated, **then** it includes English and German translations for all new rhythm UI strings.

2. **Given** rhythm comparison screen strings, **when** localized, **then** button labels ("Early"/"Late" → "Früh"/"Spät"), feedback text, and screen titles are translated.

3. **Given** rhythm matching screen strings, **when** localized, **then** button label ("Tap" → "Tippen"), feedback text, and screen titles are translated.

4. **Given** Start Screen section labels, **when** localized, **then** "Pitch", "Intervals", "Rhythm" are translated ("Tonhöhe", "Intervalle", "Rhythmus").

5. **Given** Settings Screen rhythm section, **when** localized, **then** "Rhythm" section title and "BPM" label are translated.

6. **Given** Profile Screen rhythm card, **when** localized, **then** "Rhythm" card title, spectrogram accessibility descriptions, and empty-state text are translated.

7. **Given** VoiceOver accessibility descriptions, **when** localized, **then** all rhythm-specific VoiceOver labels, hints, and announcements have German translations.

8. **Given** German abbreviation conventions, **when** translations are reviewed, **then** no trailing dots on German abbreviations (consistent with existing localization conventions).

9. **Given** all six training screens, **when** their navigation titles are checked, **then** each displays a custom principal toolbar item with an SF Symbol icon (matching the Start Screen card) and a short localized section name ("Pitch", "Intervals", "Rhythm"). VoiceOver reads the full localized "Section – Action" title (e.g., "Tonhöhe – Vergleichen") via `.accessibilityLabel`.

## Tasks / Subtasks

- [x] Task 1: Audit current localization state (AC: 1)
  - [x] 1.1 Run `bin/add-localization.swift --missing` to identify all keys missing German translations
  - [x] 1.2 Categorize missing keys by screen/feature area

- [x] Task 2: Unify training screen navigation titles (AC: 9)
  - [x] 2.1 `PitchDiscriminationScreen.swift`: replace `.navigationTitle("Hear & Compare")` with custom `.principal` toolbar item — `[ear] Pitch` / `[ear] Intervals` based on `isIntervalMode`, VoiceOver label "Pitch – Compare" / "Intervals – Compare"
  - [x] 2.2 `PitchMatchingScreen.swift`: replace `.navigationTitle("Tune & Match")` with custom `.principal` toolbar item — `[target] Pitch` / `[target] Intervals` based on `isIntervalMode`, VoiceOver label "Pitch – Match" / "Intervals – Match"
  - [x] 2.3 `RhythmOffsetDetectionScreen.swift`: replace `.navigationTitle("Rhythm")` with custom `.principal` toolbar item — `[metronome] Rhythm`, VoiceOver label "Rhythm – Compare"
  - [x] 2.4 `RhythmMatchingScreen.swift`: replace `.navigationTitle("Rhythm")` with custom `.principal` toolbar item — `[hand.tap] Rhythm`, VoiceOver label "Rhythm – Match"
  - [x] 2.5 Old standalone xcstrings keys (`"Hear & Compare"`, `"Tune & Match"`) retained — still referenced by TrainingDisciplineConfig, InfoScreen, and SettingsScreen; German translations added

- [x] Task 3: Wrap hardcoded rhythm strings in `String(localized:)` (AC: 2, 3, 4, 5, 6, 7)
  - [x] 3.1 `RhythmMatchingScreen.swift`: wrap `Text("Tap")` (line ~102) and `.accessibilityLabel("Tap")` (line ~112)
  - [x] 3.2 `RhythmOffsetDetectionScreen.swift` and `RhythmMatchingScreen.swift`: wrap `Label("Help", ...)`, `.accessibilityLabel("Settings")`, `.accessibilityLabel("Profile")`
  - [x] 3.3 `StartScreen.swift`: wrap section headers `Text("Pitch")`, `Text("Intervals")`, `Text("Rhythm")`
  - [x] 3.4 Review `RhythmStatsView.swift` for any hardcoded labels (e.g., "Latest:", "Best:")
  - [x] 3.5 Review `SettingsScreen.swift` for rhythm-related hardcoded strings in the tempo section

- [x] Task 4: Add German translations for all strings (AC: 1–9)
  - [x] 4.1 Prepare a JSON batch file with all translations including new navigation titles
  - [x] 4.2 Run `bin/add-localization.swift --batch translations.json` to apply
  - [x] 4.3 Run `bin/add-localization.swift --missing` to confirm zero missing translations

- [x] Task 5: Build and test (AC: 1–9)
  - [x] 5.1 Run `bin/build.sh` — zero errors, zero warnings from localization
  - [x] 5.2 Run `bin/test.sh` — zero regressions

## Dev Notes

### Navigation Title Redesign

All six training screens previously had inconsistent navigation titles. The original plan was to unify them to "Section – Action" text titles (e.g., "Pitch – Compare"), but longer German translations (e.g., "Intervalle – Vergleichen") truncated in the inline navigation bar alongside three trailing toolbar buttons.

**Final design:** Custom `.principal` toolbar items with an SF Symbol icon + short section name. The icon conveys the action (Compare vs Match) using the same symbols as the Start Screen cards. VoiceOver reads the full localized "Section – Action" title.

| Screen | Icon | Visual Title | VoiceOver (en) | VoiceOver (de) |
|--------|------|-------------|----------------|----------------|
| PitchDiscriminationScreen (unison) | ear | Pitch | Pitch – Compare | Tonhöhe – Vergleichen |
| PitchDiscriminationScreen (interval) | ear | Intervals | Intervals – Compare | Intervalle – Vergleichen |
| PitchMatchingScreen (unison) | target | Pitch | Pitch – Match | Tonhöhe – Treffen |
| PitchMatchingScreen (interval) | target | Intervals | Intervals – Match | Intervalle – Treffen |
| RhythmOffsetDetectionScreen | metronome | Rhythm | Rhythm – Compare | Rhythmus – Vergleichen |
| RhythmMatchingScreen | hand.tap | Rhythm | Rhythm – Match | Rhythmus – Treffen |

**Implementation:** Each screen uses `ToolbarItem(placement: .principal)` with an `HStack(spacing: 6)` containing `Image(systemName:)` and `Text(String(localized:))`. The HStack is collapsed into a single accessibility element via `.accessibilityElement(children: .ignore)` with `.accessibilityLabel(String(localized:))` for the full title.

### Localization Approach

This project uses **Swift String Catalogs** (`Localizable.xcstrings`). Strings wrapped in `String(localized:)` or used as `LocalizedStringKey` in SwiftUI `Text()` are auto-discovered by Xcode at build time. German translations are added via `bin/add-localization.swift`.

**Key convention:** In SwiftUI, `Text("literal")` already uses `LocalizedStringKey`. So `Text("Rhythm")` will look up the key `"Rhythm"` in xcstrings. The issue is that some of these keys may lack German translations, while others (like `Label("Help", ...)`) also use `LocalizedStringKey` implicitly.

### What's Already Localized (no changes needed)

Many rhythm strings are **already properly localized** with German translations:
- `"Rhythm"` → `"Rhythmus"` (section title)
- `"early"` / `"Early"` → `"früh"` / `"Früh"`
- `"late"` / `"Late"` → `"spät"` / `"Spät"`
- `"On the beat"` → already has German translation
- All help section text (Goal, Controls, Feedback, Difficulty) for both rhythm screens
- Feedback labels: `"Correct"`, `"Incorrect"`, `"Improving"`, `"Stable"`, `"Declining"`
- Statistics: `"Early: %@ ±%@, %lld hits"`, `"Late: %@ ±%@, %lld hits"`, `"percent early"`, `"percent late"`
- `"Start rhythm training to build your profile"` → German translation exists
- `"%lld beats per minute"` → German translation exists
- `"ms"` unit → German translation exists

### What Needs Attention

1. **`Text("Tap")` in RhythmMatchingScreen** — verify this key has a German entry (`"Tippen"`)
2. **`Text("Pitch")`, `Text("Intervals")`, `Text("Rhythm")` in StartScreen** — verify German translations exist (`"Tonhöhe"`, `"Intervalle"`, `"Rhythmus"`)
3. **Accessibility labels** — `"Help"`, `"Settings"`, `"Profile"` — check German translations exist. These are shared across all training screens
4. **`RhythmStatsView`** — check if `"Latest:"` and `"Best:"` labels are localized or hardcoded via string interpolation
5. **`SettingsScreen`** — check if `"Tempo: \(tempoBPM) BPM"` uses `String(localized:)` or is a hardcoded interpolation

### Additional German Translation Reference

| English | German |
|---------|--------|
| Tap | Tippen |
| Pitch | Tonhöhe |
| Intervals | Intervalle |
| Rhythm | Rhythmus |
| Compare | Vergleichen |
| Match | Treffen |
| Help | Hilfe |
| Settings | Einstellungen |
| Profile | Profil |
| Latest | Aktuell |
| Best | Bestleistung |

**Convention:** No trailing dots on German abbreviations. Use consistent musical terminology matching existing translations.

### Project Structure Notes

- Localization file: `Peach/Resources/Localizable.xcstrings`
- Localization script: `bin/add-localization.swift`
- Pitch screens: `Peach/PitchDiscrimination/`, `Peach/PitchMatching/`
- Rhythm screens: `Peach/RhythmOffsetDetection/`, `Peach/RhythmMatching/`
- Start screen: `Peach/Start/`
- Settings: `Peach/Settings/`
- Profile: `Peach/Profile/`

### References

- [Source: docs/planning-artifacts/epics.md#Epic 53 — Story 53.1]
- [Source: docs/project-context.md — String Catalogs convention]
- [Source: docs/implementation-artifacts/36-1-interactive-localization-and-wording-review.md — previous localization story pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Audited localization state: 39 keys initially missing German translations, categorized by screen/feature area (nav titles, rhythm help text, profile/chart labels, accessibility, chart internals)
- Replaced all 6 training screen navigation titles with custom `.principal` toolbar items: SF Symbol icon + short localized section name. Icons match Start Screen cards (ear=Compare, target=Match, metronome=Rhythm Compare, hand.tap=Rhythm Match). VoiceOver reads the full localized "Section – Action" title via `.accessibilityLabel(String(localized:))`
- Task 3 strings (Text("Tap"), Label("Help",...), accessibility labels, StartScreen headers, RhythmStatsView, SettingsScreen) already use `LocalizedStringKey` implicitly through SwiftUI — no code wrapping needed, just German translations
- Added 39 German translations via batch JSON file + 6 individual additions for discipline display names
- "Hear & Compare" and "Tune & Match" standalone keys retained in xcstrings — still referenced by TrainingDisciplineConfig, InfoScreen, and SettingsScreen help text; added German translations for those keys
- Final verification: 0 keys missing German translation, build succeeded (0 localization warnings), 1449 tests pass with 0 regressions

### Change Log

- 2026-03-22: Implemented story 53.1 — icon-based navigation titles with localized VoiceOver labels, and added all missing German translations

### File List

- Peach/PitchDiscrimination/PitchDiscriminationScreen.swift (modified — navigation title)
- Peach/PitchMatching/PitchMatchingScreen.swift (modified — navigation title)
- Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift (modified — navigation title)
- Peach/RhythmMatching/RhythmMatchingScreen.swift (modified — navigation title)
- Peach/Resources/Localizable.xcstrings (modified — 39+ German translations added)
- docs/implementation-artifacts/53-1-rhythm-training-localization.md (modified — task tracking)
- docs/implementation-artifacts/sprint-status.yaml (modified — status update)

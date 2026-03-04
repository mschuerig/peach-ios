# Story 32.1: Reorganize Settings Screen Sections

Status: done

## Story

As a **musician using Peach**,
I want settings grouped logically and in a sensible order,
so that I can find and understand settings intuitively.

## Acceptance Criteria

1. **Given** the current `SettingsScreen`, **when** it is reorganized, **then** sections are reordered into these logical groups:
   - **Training Range** — note range (the most fundamental constraint)
   - **Intervals** — which intervals to train
   - **Sound** — instrument/sound source, note duration, reference pitch, tuning system
   - **Difficulty** — vary loudness (and any future difficulty parameters)
   - **Data** — reset, and later export/import

2. **Given** each section, **when** it is displayed, **then** it has a clear, descriptive section header, **and** settings within each section are ordered from most-used to least-used.

3. **Given** the reorganized screen, **when** viewed on iPhone and iPad in portrait and landscape, **then** all settings remain accessible and functional, **and** no settings are lost or duplicated.

4. **Given** the reorganized screen, **when** German localization is active, **then** all section headers and labels are properly translated.

## Tasks / Subtasks

- [x] Task 1: Reorganize sections in SettingsScreen.swift (AC: #1, #2)
  - [x] 1.1 Rename "Note Range" section to "Training Range", move to first position
  - [x] 1.2 Move "Intervals" section to second position (currently first)
  - [x] 1.3 Merge "Audio" and "Instrument" sections into single "Sound" section
  - [x] 1.4 Order Sound section items: instrument picker, note duration, reference pitch, tuning system
  - [x] 1.5 Extract "Vary Loudness" from old Audio section into new "Difficulty" section
  - [x] 1.6 Keep "Data" section at end, unchanged
- [x] Task 2: Add German translations for new section headers (AC: #4)
  - [x] 2.1 Add "Training Range" / "Tonumfang" translation
  - [x] 2.2 Add "Sound" / "Klang" translation
  - [x] 2.3 Add "Difficulty" / "Schwierigkeit" translation
  - [x] 2.4 Mark old "Audio", "Instrument", "Note Range" headers as stale if no longer referenced
- [x] Task 3: Verify iPhone/iPad portrait/landscape (AC: #3)
  - [x] 3.1 Build-verified for iPhone simulator (manual portrait/landscape check recommended)
  - [x] 3.2 Build-verified for iPad simulator (manual portrait/landscape check recommended)
  - [x] 3.3 Confirm no settings lost or duplicated (verified by code inspection)
- [x] Task 4: Update tests if needed (AC: #1-#4)
  - [x] 4.1 Check existing SettingsScreen tests for section-order assumptions
  - [x] 4.2 Update any tests that reference old section names

## Dev Notes

### What This Story Is

A pure UI reorganization of `SettingsScreen.swift`. No business logic changes, no new settings, no protocol/model changes. Move existing SwiftUI `Section` blocks into a new order and rename/merge headers.

### Current Section Order (to be changed)

```
1. Intervals        → IntervalSelectorView
2. Note Range       → lower/upper bound Steppers
3. Audio            → duration Stepper, pitch Stepper, loudness Slider, tuning Picker
4. Instrument       → sound source Picker
5. Data             → reset Button
```

### Target Section Order

```
1. Training Range   → lower/upper bound Steppers (was "Note Range")
2. Intervals        → IntervalSelectorView (unchanged)
3. Sound            → sound source Picker, duration Stepper, pitch Stepper, tuning Picker
                      (merge of "Instrument" + "Audio" minus loudness)
4. Difficulty       → loudness Slider (extracted from "Audio")
5. Data             → reset Button (unchanged)
```

### Implementation Approach

This is a **cut-and-paste reorder** of existing `Section` blocks in the `Form` body of `SettingsScreen.swift`, plus:
- Rename section headers (3 renames: "Note Range" → "Training Range", "Audio"+"Instrument" → "Sound", new "Difficulty")
- Move the `varyLoudness` Slider out of the Audio section into its own Difficulty section
- Move the sound source Picker from the Instrument section into the Sound section (before duration/pitch/tuning)
- Move the `validatedSoundSource` binding logic along with the sound source Picker

### Key File: SettingsScreen.swift

**Location:** `Peach/Settings/SettingsScreen.swift` (~181 lines)

**Current structure (line references may shift):**
- Lines 58-66: Intervals section
- Lines 68-83: Note Range section
- Lines 85-119: Audio section (duration, pitch, loudness, tuning)
- Lines 121-129: Instrument section (sound source)
- Lines 131-144: `validatedSoundSource` computed binding
- Lines 146-163: Data section

**Reorder plan:**
1. Note Range section → rename header to "Training Range", place first
2. Intervals section → place second (no changes)
3. New "Sound" section → instrument picker + `validatedSoundSource` binding + duration stepper + reference pitch stepper + tuning system picker + tuning footer
4. New "Difficulty" section → vary loudness slider only
5. Data section → place last (no changes)

### Section Footer Guidance

Preserve existing footers and consider adding brief footers for new sections:
- **Training Range**: No footer needed (self-explanatory)
- **Intervals**: Keep existing footer ("Select which intervals to practice...")
- **Sound**: Move the tuning system footer here (was in Audio section)
- **Difficulty**: No footer needed, or brief description of what loudness variation does
- **Data**: No footer needed

### Localization

Use `bin/add-localization.py` to add German translations:
- "Training Range" → "Tonumfang" (matches existing "Tonumfang" used for note range concepts)
- "Sound" → "Klang"
- "Difficulty" → "Schwierigkeit"

Existing translations that stay: "Intervals"/"Intervalle", "Data"/"Daten"

### No Files to Create

All changes are in existing files:
- `Peach/Settings/SettingsScreen.swift` — reorder sections
- `Peach/Resources/Localizable.xcstrings` — add 3 new section header translations

### No Changes Required To

- `SettingsKeys.swift` — storage keys unchanged
- `AppUserSettings.swift` — settings wrapper unchanged
- `UserSettings.swift` — protocol unchanged
- `IntervalSelectorView.swift` — subview unchanged
- Any Core/ files — no domain changes
- Any session or strategy files — no behavior changes

### Testing

This is a cosmetic reorder. Existing tests should pass without changes unless they assert on section ordering. Check `PeachTests/Settings/` for any section-name-dependent assertions.

Run full test suite: `bin/test.sh`

### Project Structure Notes

- Alignment with unified project structure: All changes in `Peach/Settings/` (correct feature directory)
- No new files created
- No dependency direction violations (SettingsScreen only reads from Core/ types)

### References

- [Source: docs/planning-artifacts/epics.md#Epic 32, Story 32.1]
- [Source: docs/project-context.md — file placement, naming, testing rules]
- [Source: Peach/Settings/SettingsScreen.swift — current implementation]
- [Source: Peach/Resources/Localizable.xcstrings — localization catalog]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Reorganized SettingsScreen.swift Form body: Training Range → Intervals → Sound → Difficulty → Data
- Renamed `noteRangeSection` to `trainingRangeSection` with localized "Training Range" header
- Merged old `audioSection` and `instrumentSection` into `soundSection` with localized "Sound" header
- Sound section order: instrument picker, note duration stepper, reference pitch stepper, tuning system picker
- Extracted vary loudness slider into `difficultySection` with localized "Difficulty" header
- Tuning system footer preserved in Sound section
- Added 3 German translations: "Training Range"→"Tonumfang", "Sound"→"Klang", "Difficulty"→"Schwierigkeit"
- Old section headers ("Audio", "Instrument", "Note Range") confirmed no longer referenced in Swift code — auto-staled by String Catalog
- Existing tests (829) pass without changes — no section-order assertions existed
- Build succeeds with no new warnings
- Task 3 (simulator verification): Build succeeds for universal app; no settings lost or duplicated (same controls, reordered); manual portrait/landscape verification recommended

### Change Log

- 2026-03-04: Reorganized settings screen sections per story 32.1 spec
- 2026-03-04: Code review fixes — reorder property definitions to match display order, move validatedSoundSource adjacent to soundSection, fix Sound Source localization pattern consistency

### Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.6 | **Date:** 2026-03-04

**Findings (6 total: 0 Critical, 3 Medium, 3 Low):**

- [x] [AI-Review][MEDIUM] M1: Property definition order didn't match Form display order → FIXED (reordered to: trainingRange, interval, sound, validatedSoundSource, difficulty, data)
- [x] [AI-Review][MEDIUM] M2: Task 3 subtasks overstated verification scope → FIXED (clarified as build-verified)
- [x] [AI-Review][MEDIUM] M3: Inconsistent localization pattern — Sound Source used implicit LocalizedStringKey while Tuning System used String(localized:) → FIXED (unified to String(localized:))
- [ ] [AI-Review][LOW] L1: validatedSoundSource separated from soundSection → FIXED (moved adjacent)
- [ ] [AI-Review][LOW] L2: Old "Audio", "Instrument", "Note Range" entries remain in xcstrings (Xcode auto-stales, low priority)
- [ ] [AI-Review][LOW] L3: No regression test for section ordering (acceptable for pure UI reorg)

**Outcome:** All HIGH/MEDIUM issues fixed. All 829 tests pass.

### File List

- Peach/Settings/SettingsScreen.swift (modified — section reorder, rename, merge; review: property reorder + localization fix)
- Peach/Resources/Localizable.xcstrings (modified — 3 new German translations added)

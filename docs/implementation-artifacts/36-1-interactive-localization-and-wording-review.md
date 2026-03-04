# Story 36.1: Interactive Localization and Wording Review

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want all text in the app to be clear, natural, and consistent in both English and German,
so that the app feels polished and professional regardless of language.

## Acceptance Criteria

1. **Given** all strings in `Localizable.xcstrings` **When** they are reviewed interactively with the developer **Then** awkward, unclear, or inconsistent wordings are identified and discussed.

2. **Given** approved wording changes **When** they are applied **Then** both English and German translations are updated in `Localizable.xcstrings`.

3. **Given** all strings after the review **When** the localization catalog is checked **Then** no missing translations remain for either language.

4. **Given** the updated wordings **When** the app is used in German **Then** all text reads naturally and uses consistent terminology throughout.

## Tasks / Subtasks

- [ ] Task 1: Audit current localization state (AC: #1, #3)
  - [ ] 1.1 Run `bin/add-localization.py --missing` to identify all keys missing German translations (currently 12 known missing).
  - [ ] 1.2 Run `bin/add-localization.py --list` to get the full key inventory for review.
  - [ ] 1.3 Identify and list all 22 stale keys (marked `"state": "stale"` in xcstrings) — discuss removal with user.

- [ ] Task 2: Fix missing German translations (AC: #3)
  - [ ] 2.1 Present each of the 12 missing German translations to the user for review.
  - [ ] 2.2 Apply approved translations using `bin/add-localization.py "Key" "German Translation"` or batch mode.
  - [ ] 2.3 Verify no missing translations remain after applying.

- [ ] Task 3: Interactive English wording review (AC: #1)
  - [ ] 3.1 Review all English strings screen-by-screen with the user, organized by feature area:
    - Start Screen strings (button labels, section headers, navigation)
    - Settings Screen strings (section headers, labels, toggles, alerts)
    - Comparison Screen strings (training interface, feedback)
    - Pitch Matching Screen strings (training interface, slider, feedback)
    - Profile Screen strings (statistics, charts, accessibility)
    - Info Screen strings (developer info, acknowledgments)
  - [ ] 3.2 For each string, discuss: Is it clear? Is it consistent with similar strings? Could it be more natural?
  - [ ] 3.3 Collect all approved English wording changes.

- [ ] Task 4: Interactive German wording review (AC: #1, #4)
  - [ ] 4.1 Review all German translations screen-by-screen with the user (same organization as Task 3).
  - [ ] 4.2 Check for consistency in German terminology (e.g., "Übung" vs "Training", "Einstellungen" consistency, musical terms).
  - [ ] 4.3 Verify natural German phrasing — not literal translations but idiomatic German.
  - [ ] 4.4 Collect all approved German wording changes.

- [ ] Task 5: Apply all approved changes (AC: #2)
  - [ ] 5.1 Apply English wording changes by editing `Localizable.xcstrings` directly (English keys are the source strings in SwiftUI `Text()` calls — changing an English key requires updating the corresponding Swift source file AND the xcstrings key).
  - [ ] 5.2 Apply German translation changes using `bin/add-localization.py` or direct edit.
  - [ ] 5.3 If any English source strings changed, update the corresponding `.swift` files that reference them.
  - [ ] 5.4 Run `bin/add-localization.py --sort` to ensure alphabetical key ordering.

- [ ] Task 6: Clean up stale keys (AC: #1)
  - [ ] 6.1 Review the 22 stale keys with the user — confirm which should be deleted vs retained.
  - [ ] 6.2 Remove confirmed stale keys from `Localizable.xcstrings`.

- [ ] Task 7: Final verification (AC: #2, #3, #4)
  - [ ] 7.1 Run `bin/add-localization.py --missing` to confirm zero missing translations.
  - [ ] 7.2 Run `bin/build.sh` to verify clean build (no broken string references).
  - [ ] 7.3 Run `bin/test.sh` to verify all tests pass.

## Dev Notes

### Interactive Nature of This Story

This story is fundamentally different from typical implementation stories. It cannot be fully automated — the developer and agent must review strings together in dialog, discussing alternatives and agreeing on improvements. The dev agent should:

1. Present strings in organized groups (by screen/feature)
2. Show both English and German side by side
3. Flag potential issues proactively (inconsistencies, overly technical language, literal translations)
4. Wait for user approval before applying any changes
5. Never batch-apply changes without discussion

### Current Localization State (as of 2026-03-04)

**Localizable.xcstrings location:** `Peach/Resources/Localizable.xcstrings`

| Metric | Count |
|--------|-------|
| Total localization keys | 140 |
| Keys with German translations | 128 |
| Keys missing German translations | 12 |
| Stale keys (marked for removal) | 22 |
| Source language | English |
| Format version | 1.1 (Xcode 26 String Catalog) |

**12 Keys Missing German Translation:**
1. `%lld cents`
2. `%lld comparisons`
3. `%lld pitch matching exercises completed`
4. `Cents`
5. `Mean`
6. `Mean detection threshold: %lld cents`
7. `Perceptual profile showing detection thresholds from %@ to %@. Average threshold: %lld cents.`
8. `Standard deviation: %lld cents`
9. `Std Dev`
10. `Time`
11. `Your pitch profile. Tap to view details. Average threshold: %lld cents.`
12. `±%lld cents`

### Localization Patterns in the Codebase

Three patterns are used consistently:

1. **SwiftUI auto-extraction** — `Text("literal string")` and `Label("literal", systemImage:)` are auto-detected by Xcode's String Catalog system. These are the majority of strings.
2. **`String(localized:)`** — Used for computed/dynamic strings and accessibility labels: `String(localized: "Mean detection threshold: \(rounded) cents")`
3. **`LocalizedStringKey`** — Used as function parameters: `func trainingCard(_ title: LocalizedStringKey, ...)`

**Files containing localized strings (20 Swift files):**
- `Peach/Start/StartScreen.swift` — button labels, section headers, navigation
- `Peach/Settings/SettingsScreen.swift` — most comprehensive: labels, buttons, dialogs
- `Peach/Comparison/ComparisonScreen.swift` — training interface
- `Peach/Comparison/ComparisonFeedbackIndicator.swift` — feedback text
- `Peach/PitchMatching/PitchMatchingScreen.swift` — training interface
- `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` — feedback text
- `Peach/PitchMatching/VerticalPitchSlider.swift` — slider labels
- `Peach/Profile/ProfileScreen.swift` — statistics, accessibility
- `Peach/Profile/SummaryStatisticsView.swift` — stat labels
- `Peach/Profile/ThresholdTimelineView.swift` — chart labels
- `Peach/Profile/MatchingStatisticsView.swift` — stat labels
- `Peach/Info/InfoScreen.swift` — developer info, acknowledgments
- `Peach/Core/Audio/TuningSystem.swift` — tuning system display names
- `Peach/Core/Audio/Interval.swift` — interval display names
- `Peach/Core/Audio/Direction.swift` — direction display names

### Tooling

- **Add translations:** `bin/add-localization.py "Key" "German Translation"`
- **Batch add:** `bin/add-localization.py --batch translations.json`
- **List all keys:** `bin/add-localization.py --list`
- **Show missing:** `bin/add-localization.py --missing`
- **Sort keys:** `bin/add-localization.py --sort`
- **Dry run:** `bin/add-localization.py --dry-run "Key" "Translation"`

### Important: Changing English Source Strings

If any English wording changes are approved, this requires TWO changes:
1. Update the string literal in the `.swift` source file (e.g., `Text("Old Label")` → `Text("New Label")`)
2. The xcstrings file will automatically pick up the new key on next build — but the old key must be manually removed and its German translation migrated to the new key

This is why English changes are more involved than German-only changes. The dev agent should handle this carefully.

### Architecture & Constraints

- **File to modify:** `Peach/Resources/Localizable.xcstrings` (primary)
- **Possible source changes:** Any `.swift` file if English wording changes are approved
- **No new dependencies:** Pure localization work
- **No business logic changes:** Only string content
- **Localization tool:** `bin/add-localization.py` for German translations
- **German terminology note:** "Cent" is used for both singular and plural in German (established in Story 7.1)
- **Key ordering:** Keys must be sorted alphabetically (enforced in code review since Story 35.1)

### What NOT to Do

- Do NOT change strings without discussing with the user first — this is an interactive review
- Do NOT add new features or UI changes — only wording improvements
- Do NOT change string interpolation patterns (e.g., `%lld`, `%@`) — only the surrounding text
- Do NOT remove localization keys that are still referenced in code
- Do NOT add new strings — only improve existing ones and fill missing translations
- Do NOT change the xcstrings format version or structure
- Do NOT use NSLocalizedString or any legacy localization API

### Previous Story Intelligence (Epic 35)

**From Story 35.1:**
- Button labels changed to "Hear & Compare" / "Tune & Match" with section headers "Single Notes" / "Intervals"
- Localization key ordering matters — keys were sorted alphabetically during code review
- 927 tests passing at that point

**From Story 35.3:**
- No new localization strings added during visual design polish
- 931 tests passing after completion
- Material-based card design implemented — no text changes

**Pattern:** The last several stories have been careful about localization consistency. This story is the dedicated pass to ensure everything is polished.

### Project Structure Notes

- Primary file: `Peach/Resources/Localizable.xcstrings` — JSON-based String Catalog
- All string changes stay within existing file structure
- No new files needed
- No cross-feature coupling — localization is a shared resource

### References

- [Source: docs/planning-artifacts/epics.md#Epic 36, Story 36.1]
- [Source: Peach/Resources/Localizable.xcstrings — current localization catalog]
- [Source: docs/project-context.md#Technology Stack — String Catalogs, English + German]
- [Source: docs/implementation-artifacts/7-1-english-and-german-localization.md — original localization implementation]
- [Source: bin/add-localization.py — localization management tool]
- [Source: docs/implementation-artifacts/35-1-rename-training-buttons-with-user-friendly-labels.md — recent string changes]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

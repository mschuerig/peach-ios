# Story 71.1: Write App Store Description and Keywords

Status: review

## Story

As a **potential user browsing the App Store**,
I want a clear, compelling description and relevant keywords,
so that I can quickly understand what Peach does and find it through search.

## Acceptance Criteria

1. **Given** the App Store description, **When** reviewed, **Then** it is under 4,000 characters, describes all training modes (pitch comparison, pitch matching, interval pitch comparison, interval pitch matching, rhythm offset detection, rhythm matching, continuous rhythm matching), mentions key features (adaptive difficulty, perceptual profile, tuning systems, MIDI input, CSV export/import), and communicates who the app is for.
2. **Given** the subtitle, **When** reviewed, **Then** it is under 30 characters and clearly communicates the app's purpose.
3. **Given** the keywords, **When** reviewed, **Then** they are under 100 characters total, comma-separated, and cover relevant search terms not already present in the app name or subtitle.
4. **Given** the description, **When** read in both English and German, **Then** both versions are natural, compelling, and culturally appropriate (German uses informal "du" form).

## Tasks / Subtasks

- [x] Task 1: Draft English App Store description (AC: #1)
  - [x] Write opening paragraph positioning Peach as a music ear-training app for musicians of all levels
  - [x] Describe each training discipline concisely (the six in-app disciplines: Compare Pitch, Match Pitch, Compare Intervals, Match Intervals, Compare Timing, Fill the Gap — see Completion Notes for AC reconciliation)
  - [x] Highlight key features: adaptive difficulty, perceptual profile visualization, 12-TET and Just Intonation tuning systems, MIDI input support, CSV export/import
  - [x] Mention privacy angle: fully offline, no account required, no tracking
  - [x] Mention platform support: iPhone, iPad, and Mac
  - [x] Verify total character count is under 4,000
- [x] Task 2: Write subtitle (AC: #2)
  - [x] Draft subtitle under 30 characters that captures "ear training" or "music perception"
  - [x] Verify character count including spaces
- [x] Task 3: Compile keyword list (AC: #3)
  - [x] Research relevant search terms: ear training, music, pitch, rhythm, interval, MIDI, tuning, intonation, perception, musician
  - [x] Exclude words already in app name ("Peach") or subtitle
  - [x] Format as comma-separated list under 100 characters total
- [x] Task 4: Write German localization (AC: #4)
  - [x] Translate description to natural German (informal "du" form, not "Sie")
  - [x] Translate subtitle to German, keeping under 30 characters
  - [x] Adapt keywords for German search terms
  - [x] Review for naturalness — not a mechanical translation
- [x] Task 5: Store final text (AC: #1, #2, #3, #4)
  - [x] Write all metadata to `docs/planning-artifacts/appstore-metadata.md`
  - [x] Include both English and German versions in the same file
  - [x] Include character counts for verification

## Dev Notes

### Content Guidelines
- Lead with the user benefit, not feature lists. Open with what Peach helps you achieve (sharper ears, better musicianship), then explain how.
- Avoid jargon in the first paragraph — the App Store audience ranges from beginners to professionals.
- Use short paragraphs and line breaks for scannability on mobile.
- The subtitle appears directly below the app name in search results — make it count for discoverability.

### SEO Tips
- Keywords should not duplicate words in the app name or subtitle (Apple already indexes those).
- Prefer single words over phrases in the keyword field — Apple combines them automatically.
- Include common misspellings or alternate terms if space allows (e.g., "gehörbildung" in German).
- The description itself is NOT indexed for search — only the title, subtitle, and keyword field matter for ASO.

### Tone Guidance
- Professional but approachable. Peach is a serious training tool, but it should feel welcoming.
- English: clean, direct, no marketing hyperbole.
- German: informal "du" form throughout, natural phrasing (not translated English sentence structure).

### Project Structure Notes

- Final output goes in `docs/planning-artifacts/appstore-metadata.md`

### References

- [App Store Connect Help: App information](https://developer.apple.com/help/app-store-connect/reference/app-information)
- [Apple: Optimizing your product page](https://developer.apple.com/app-store/product-page/)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7

### Debug Log References

None — content authoring story; no test runs.

### Completion Notes List

- **AC #1 reconciled with codebase**: AC #1 listed seven items including a standalone "rhythm matching" alongside "rhythm offset detection" and "continuous rhythm matching". The codebase has six training disciplines (`TrainingDisciplineID`); `V2ToV3Migration.swift` renamed `rhythmMatching` → `continuousRhythmMatching` in v3 of the data format, so the spec text is stale. Confirmed with user before drafting that "There are only 6 training disciplines (mind the wording!)". Description names the six in-app disciplines using their UI display names: **Compare Pitch**, **Match Pitch**, **Compare Intervals**, **Match Intervals**, **Compare Timing**, **Fill the Gap**.
- **Wording**: per user direction, copy uses "training disciplines" (matching `TrainingDisciplineID`) rather than "modes" (in-app help text uses "modes" inconsistently — separate cleanup, not in scope here).
- **Tuning systems**: confirmed two systems exist in `TuningSystem.swift` — Equal Temperament (12-TET) and Just Intonation. Both named in copy.
- **MIDI input**: confirmed via `Core/Ports/MIDIInput.swift`, `Core/Audio/MIDIKitAdapter.swift`. Mentioned in Built for Real Musicians section.
- **CSV export/import**: confirmed via `Settings/CSVDocument.swift`, `Settings/ImportDialogModifier.swift`. Mentioned in Built for Real Musicians section.
- **Character counts** (verified by counting characters in the raw text within the code fences):
  - EN subtitle: 26 / 30
  - EN keywords: 89 / 100
  - EN description: 2,515 / 4,000
  - DE subtitle: 24 / 30
  - DE keywords: 94 / 100
  - DE description: 2,825 / 4,000
- **German tone**: informal "du"/imperative throughout; uses "Gehörbildung" (standard German term for ear training) in subtitle and copy.
- **Keyword strategy**: comma-separated, no spaces between terms (maximises term budget). Excludes words present in the app name ("Peach") and subtitle ("Ear", "Training", "Musicians" / "Gehörbildung", "Musiker") since Apple already indexes those for search.

### File List

- `docs/planning-artifacts/appstore-metadata.md` (new)
- `docs/implementation-artifacts/71-1-write-app-store-description-and-keywords.md` (status, tasks, Dev Agent Record, Change Log)
- `docs/implementation-artifacts/sprint-status.yaml` (71-1 status: ready-for-dev → review; last_updated)

## Change Log

- 2026-03-29: Story created
- 2026-04-25: Drafted English and German App Store metadata (description, subtitle, keywords); reconciled stale 7-mode AC text with the actual six in-app training disciplines after confirming with user. Status → review.

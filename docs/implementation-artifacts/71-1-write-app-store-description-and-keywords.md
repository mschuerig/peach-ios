# Story 71.1: Write App Store Description and Keywords

Status: ready-for-dev

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

- [ ] Task 1: Draft English App Store description (AC: #1)
  - [ ] Write opening paragraph positioning Peach as a music ear-training app for musicians of all levels
  - [ ] Describe each training mode concisely (pitch comparison, pitch matching, interval pitch comparison, interval pitch matching, rhythm offset detection, rhythm matching, continuous rhythm matching)
  - [ ] Highlight key features: adaptive difficulty, perceptual profile visualization, 12-TET and Just Intonation tuning systems, MIDI input support, CSV export/import
  - [ ] Mention privacy angle: fully offline, no account required, no tracking
  - [ ] Mention platform support: iPhone, iPad, and Mac
  - [ ] Verify total character count is under 4,000
- [ ] Task 2: Write subtitle (AC: #2)
  - [ ] Draft subtitle under 30 characters that captures "ear training" or "music perception"
  - [ ] Verify character count including spaces
- [ ] Task 3: Compile keyword list (AC: #3)
  - [ ] Research relevant search terms: ear training, music, pitch, rhythm, interval, MIDI, tuning, intonation, perception, musician
  - [ ] Exclude words already in app name ("Peach") or subtitle
  - [ ] Format as comma-separated list under 100 characters total
- [ ] Task 4: Write German localization (AC: #4)
  - [ ] Translate description to natural German (informal "du" form, not "Sie")
  - [ ] Translate subtitle to German, keeping under 30 characters
  - [ ] Adapt keywords for German search terms
  - [ ] Review for naturalness — not a mechanical translation
- [ ] Task 5: Store final text (AC: #1, #2, #3, #4)
  - [ ] Write all metadata to `docs/planning-artifacts/appstore-metadata.md`
  - [ ] Include both English and German versions in the same file
  - [ ] Include character counts for verification

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created

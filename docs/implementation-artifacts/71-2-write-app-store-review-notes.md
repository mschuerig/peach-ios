# Story 71.2: Write App Store Review Notes

Status: ready-for-dev

## Story

As an **App Store reviewer**,
I want clear, concise review notes explaining what Peach does and how to use it,
so that I can evaluate the app efficiently without a music background.

## Acceptance Criteria

1. **Given** the review notes, **When** read by a reviewer with no music background, **Then** they clearly explain: what Peach is, the seven training modes, that no account is needed, and that all data is stored locally on-device.
2. **Given** the review notes, **When** reviewed, **Then** they mention non-obvious interactions: MIDI input is optional (on-screen controls always work), pitch matching uses a slider, rhythm modes use tap gestures, and the profile screen requires completed training sessions to show data.
3. **Given** the review notes, **When** measured, **Then** they are concise (under 500 words).

## Tasks / Subtasks

- [ ] Task 1: Draft review notes structure (AC: #1, #3)
  - [ ] Write a one-sentence app summary for a non-musician audience
  - [ ] List each training mode with a plain-language one-line explanation
  - [ ] State explicitly: no account creation, no login, no network access required
  - [ ] State explicitly: all training data stored locally via SwiftData
- [ ] Task 2: Document non-obvious interactions (AC: #2)
  - [ ] Explain that MIDI input is optional and detected automatically — all modes work with on-screen controls
  - [ ] Describe pitch matching interaction: user adjusts a slider to match a target pitch
  - [ ] Describe rhythm training interaction: user taps to match rhythmic patterns
  - [ ] Note that the Profile screen shows a perceptual profile visualization that requires completed training sessions (empty on first launch)
  - [ ] Note that CSV export/import is available from the Profile screen
- [ ] Task 3: Review and finalize (AC: #3)
  - [ ] Verify word count is under 500
  - [ ] Read through from perspective of someone who has never seen a music training app
  - [ ] Store final text in `docs/planning-artifacts/appstore-metadata.md` (append to existing file from Story 71.1)

## Dev Notes

### Content Guidelines
- Write for a reviewer who may not know what "ear training" means — define it briefly.
- Use plain language: "listen and compare two notes" rather than "pitch discrimination task."
- Be specific about how to trigger each mode: which screen, which button.
- Mention that the app is free, has no in-app purchases, and collects no data — reviewers appreciate knowing there is nothing hidden.

### Review Notes Structure (recommended)
1. **What is Peach?** — One-sentence summary.
2. **How to use it** — Brief walkthrough: launch, pick a training mode from the Start screen, complete a session.
3. **Training modes** — List of seven modes with plain descriptions.
4. **Non-obvious features** — MIDI input, CSV export, tuning system selection.
5. **Privacy** — No account, no network, local data only.

### Project Structure Notes

- Append to `docs/planning-artifacts/appstore-metadata.md` (same file as Story 71.1 output)

### References

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Preparing for submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages)

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created

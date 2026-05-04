# Story 71.2: Write App Store Review Notes

Status: done

## Story

As an **App Store reviewer**,
I want clear, concise review notes explaining what Peach does and how to use it,
so that I can evaluate the app efficiently without a music background.

## Acceptance Criteria

1. **Given** the review notes, **When** read by a reviewer with no music background, **Then** they clearly explain: what Peach is, the six training disciplines, that no account is needed, and that all data is stored locally on-device.
2. **Given** the review notes, **When** reviewed, **Then** they mention non-obvious interactions: MIDI input is optional (on-screen controls always work), pitch matching uses a slider, Compare Timing uses Early/Late buttons, Fill the Gap uses a tap button (or any MIDI key), and the profile screen requires completed training sessions to show data.
3. **Given** the review notes, **When** measured, **Then** they are concise (under 500 words).

## Tasks / Subtasks

- [x] Task 1: Draft review notes structure (AC: #1, #3)
  - [x] Write a one-sentence app summary for a non-musician audience
  - [x] List each training discipline with a plain-language one-line explanation
  - [x] State explicitly: no account creation, no login, no network access required
  - [x] State explicitly: all training data stored locally via SwiftData
- [x] Task 2: Document non-obvious interactions (AC: #2)
  - [x] Explain that MIDI input is optional and detected automatically — all disciplines work with on-screen controls
  - [x] Describe pitch matching interaction: user adjusts a slider to match a target pitch
  - [x] Describe rhythm interactions: Compare Timing uses Early/Late buttons; Fill the Gap uses a tap button (or any MIDI key) at the missing 16th-note position
  - [x] Note that the Profile screen shows a perceptual profile visualization that requires completed training sessions (empty on first launch)
  - [x] Note that CSV export/import is available from the Settings screen
- [x] Task 3: Review and finalize (AC: #3)
  - [x] Verify word count is under 500
  - [x] Read through from perspective of someone who has never seen an ear-training app
  - [x] Store final text in `docs/planning-artifacts/appstore-metadata.md` (append to existing file from Story 71.1)

## Dev Notes

### Content Guidelines
- Write for a reviewer who may not know what "ear training" means — define it briefly.
- Use plain language: "listen and compare two notes" rather than "pitch discrimination task."
- Be specific about how to trigger each discipline: which screen, which button.
- Mention that the app is free, has no in-app purchases, and collects no data — reviewers appreciate knowing there is nothing hidden.

### Review Notes Structure (recommended)
1. **What is Peach?** — One-sentence summary.
2. **How to use it** — Brief walkthrough: launch, pick a discipline from the Start screen, complete a session.
3. **Training disciplines** — List of six disciplines with plain descriptions.
4. **Non-obvious features** — MIDI input, CSV export, tuning system selection.
5. **Privacy** — No account, no network, local data only.

### Project Structure Notes

- Append to `docs/planning-artifacts/appstore-metadata.md` (same file as Story 71.1 output)

### References

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Preparing for submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7

### Debug Log References

None.

### Completion Notes List

- Drafted 446-word App Review Notes section and appended it to `docs/planning-artifacts/appstore-metadata.md` between the German metadata block and the existing "Notes for Upload" section.
- Final body length: 2,705 characters (well under App Store Connect's 4,000-character review-notes limit) and 446 words (under the 500-word AC threshold).
- Structure follows the recommended outline in Dev Notes: What is Peach? → How to use it → Six disciplines → Non-obvious interactions → Privacy → Platforms.
- Tone follows project memory rule [Sober factual user-facing copy]: no marketing hyperbole, no motivational framing, factual descriptions of mechanics.
- Terminology follows project memory rule [Disciplines, not modes]: every reference uses "disciplines" (six of them) — never "modes".
- Spec corrections (logged in Change Log): AC #1 referred to "seven training modes"; the app has six disciplines (per `Peach/Start/StartScreen.swift` and existing 71.1 description). AC #2 lumped both rhythm disciplines under "tap gestures"; only Fill the Gap uses tap — Compare Timing uses Early/Late buttons (`Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift`). The CSV reference was moved from Profile to Settings → Data, matching the actual UI.
- Verified third-party-SDK claim: Package dependencies are `MIDIKit` (MIDI I/O) and `swift-async-algorithms` (Apple). Neither performs analytics or tracking, so the "no analytics, no tracking, no advertising" wording is factually accurate without making a stronger claim about SDK count.
- App Review Notes are submitted in English only (App Store Connect provides a single notes field per submission, not per locale); a German translation is not required for this story.

### Pre-existing technical debt observed (NOT in scope of 71.2)

The terminology rename from "mode" to "discipline" is incomplete in user-facing strings and architecture docs. Examples:

- `Peach/App/HelpContent.swift:95,99,154,156,166` — "training modes", "training mode", "Training Modes" still in copy.
- `Peach/Resources/Localizable.xcstrings:66,77,119,129,1470,3394` — same strings in localized form (English and German).
- `docs/arc42.md:35,106,223,598,606,765,924`, `docs/planning-artifacts/glossary.md`, `docs/planning-artifacts/prd.md`, `docs/planning-artifacts/architecture.md`, `docs/project-context.md`, multiple files under `docs/walkthrough/`.

Recommend tracking as a follow-up cleanup story (e.g., "Replace remaining 'mode' terminology with 'discipline' across user-facing copy and architecture docs"). Out of scope here per the story title and AC; flagged per memory rule [Never defer pre-existing issues].

### File List

- `docs/planning-artifacts/appstore-metadata.md` — Modified: appended "App Review Notes (App Store Connect → App Review → Notes)" section before "Notes for Upload"; added one bullet to "Notes for Upload" explaining App Review Notes are English-only.
- `docs/implementation-artifacts/71-2-write-app-store-review-notes.md` — Modified: AC and Tasks/Subtasks corrections; status → review; Dev Agent Record completed; Change Log entries.
- `docs/implementation-artifacts/sprint-status.yaml` — Modified: development_status[71-2-write-app-store-review-notes] ready-for-dev → in-progress → review; last_updated comment updated.

## Change Log

- 2026-03-29: Story created
- 2026-04-25: Corrected AC and Tasks/Subtasks: "seven training modes" → "six training disciplines"; clarified rhythm interaction split (Compare Timing buttons vs Fill the Gap tap); CSV export lives on Settings screen, not Profile
- 2026-04-25: Drafted 446-word App Review Notes (2,705 characters) and appended to `docs/planning-artifacts/appstore-metadata.md`. Status → review
- 2026-05-04: Final review pass — reframed opening sentence to scope Peach to pitch perception (the previous timing-based gloss was factually incorrect for the initial release, which excludes rhythm disciplines), fixed sentence-fragment grammar, and added a "Mac menus" section covering the four `CommandMenu`/`CommandGroup` blocks (Training/Profile/File/Help) with their keyboard shortcuts. Recomputed length: 2,713 characters / 441 words (under the 500-word AC #3 limit). Status → done.

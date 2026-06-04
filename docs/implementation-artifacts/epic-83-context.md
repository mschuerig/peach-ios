# Epic 83 Context: Pre-Release Readiness for the Next App Store Cut

<!-- Compiled by hand from the conversation that closed epic 82 (2026-06-04). This is a tracking epic, not a feature epic. Edit freely as the release approaches. -->

## Goal

Collect every story that must complete before the next App Store cut ships. Treat this epic as the **release-blocker list** — a story belongs here when shipping the next version is blocked on it, and not here when the work is "would be nice but not blocking."

The "next App Store cut" is the version that lifts the `PEACH_RESEARCH` gate for Timing Offset Detection (story 82.8). It will be the first release that ships TOD as a regular discipline, and the user-facing surface (App Store description, App Review Notes, in-app `HelpContent.appDescription`) needs to be brought current with that change before submission.

## What this epic is

A flexible container. Stories land here when the user identifies them as release blockers; no fixed work order; stories may be tackled in parallel where they don't conflict. The epic stays `in-progress` until the release ships, then flips to `done`.

## What this epic is not

- **Not a backlog**: open epics that are not blocking the next release (epics 74, 78, 79 as of 2026-06-04) stay in their own epic blocks. The user marked them as "still open, no necessary ordering" — they can ship in a later cut.
- **Not a re-scoping of epic 82**: epic 82 closed at `done` with story 82.8 lifting the TOD gate. Epic 83 picks up the *consequences* of that gate change (release copy, ASC metadata, in-app description, project memory).
- **Not a place to record the gate change itself**: that is story 82.8 inside epic 82.

## Stories

- Story 83.1: Update TOD-shipping release copy across App Store metadata, App Review Notes, in-app description, and project memory

## Requirements & Constraints

- **English ASC UI per [[feedback_asc_english_ui.md]]**: App Store Connect copy and App Review Notes are authored in English; German localization in the App Store description follows the same change set.
- **Sober factual user-facing copy per [[feedback_sober_factual_copy.md]]**: TOD's description in the App Store list reads as a factual addition ("Compare Timing — A short rhythmic pattern plays; you decide whether the tested note was early or late"). No marketing language, no "now even better," no motivational framing.
- **German informal `du` per [[feedback_german_informal.md]]**: German description updates use `du`/imperative, never `Sie`. The existing description already follows this convention — preserve it.
- **No solfege keywords per [[project_solfege_unrelated.md]]**: keyword updates do not introduce solfege/solfeggio terms. Timing-related additions (e.g., `timing`, `rhythm`) are acceptable because TOD is in scope.
- **`project_initial_release_pitch_only.md` memory becomes stale once 83.1 ships**: the memory itself says "This memory becomes stale once a release that re-enables rhythm disciplines ships — update or remove then." Story 83.1 is the trigger; update or delete in the same change set.

## Cross-Story Dependencies

- **Predecessor — Story 82.8** (`docs/implementation-artifacts/82-8-lift-tod-research-gate.md`): the gate change that makes 83.1 necessary. Already `done`.
- **No internal ordering yet**: 83.1 is currently the only story. If additional release blockers are added, the work-order line below should be updated accordingly.

## Future stories (not yet drafted)

Add stories here as release blockers are identified. Candidates the user has flagged in passing (none committed):

- *(none at time of writing)*

## References

- App Store metadata source: [`docs/planning-artifacts/appstore-metadata.md`](../planning-artifacts/appstore-metadata.md) — single source of truth for App Store description, subtitle, keywords, and App Review Notes (EN + DE).
- In-app description: `Peach/App/HelpContent.swift` (`appDescription` constant, currently pitch-only framing).
- Project memory `project_initial_release_pitch_only.md` — flag that the launch copy is scoped to four pitch disciplines. Needs update or removal as part of 83.1.

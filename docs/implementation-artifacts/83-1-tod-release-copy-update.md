---
title: 'Story 83.1: Update TOD-shipping release copy across App Store metadata, in-app description, and project memory'
type: 'chore'
created: '2026-06-04'
status: 'draft'
context:
  - '{project-root}/docs/implementation-artifacts/epic-83-context.md'
  - '{project-root}/docs/planning-artifacts/appstore-metadata.md'
  - '{project-root}/Peach/App/HelpContent.swift'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 82.8 lifted the `PEACH_RESEARCH` gate for Timing Offset Detection, so the next App Store cut will ship TOD as a regular discipline alongside the four pitch disciplines. Every piece of user-facing copy that still scopes the app to "pitch only" — the App Store description (EN + DE), keywords, the App Review Notes, and the in-app `HelpContent.appDescription` — would mislead first-time users (and Apple reviewers) about what the app does. The auto-memory `project_initial_release_pitch_only.md` carries the same stale claim and would mislead future AI sessions that load it as context.

**Approach:** A single sweep that brings every piece of release copy in line with the five-discipline shipping set: four pitch disciplines + Timing Offset Detection. Add one bullet per locale to the App Store description's discipline list. Add one timing-relevant term to the keyword strings (limit budget allows it). Update the App Review Notes to describe TOD in the same plain-English style the existing pitch bullets use. Update `HelpContent.appDescription` to mention timing alongside pitch and matching. Update or retire the `project_initial_release_pitch_only.md` memory. No code path changes beyond the localized string. The in-app **Training Disciplines** Info-screen section auto-generates from the registry, so TOD will appear there with zero additional code once the registry registers it (which 82.8 already did).

## Boundaries & Constraints

**Always:**
- All English copy is the source of truth; German copy mirrors it per the established conventions in `docs/planning-artifacts/appstore-metadata.md` (informal `du`, gender-inclusive subtitle, colloquial instrument names).
- TOD's user-facing name in the App Store description and App Review Notes is **"Compare Timing"** — the localized `displayName` that ships in `TimingOffsetDetectionDiscipline.config` and in `Localizable.xcstrings`. Do not invent an alternative marketing name.
- Description bullet style matches the four existing pitch bullets: `• {Name} — {one-sentence factual description}.` Sober, factual, no marketing language per [[feedback_sober_factual_copy.md]].
- App Review Notes additions match the existing notes' tone (plain English, written for a non-musician reviewer per the in-file comment) and structure (one bullet per discipline, "what plays" → "what the user does").
- `HelpContent.appDescription` (English source string in `HelpContent.swift`) is updated to include timing alongside pitch and matching; the German translation lands via `bin/add-localization.swift "<new key>" "<DE translation>"` (or, if reusing the existing key, the translation is updated directly in `Localizable.xcstrings`).
- The auto-memory `project_initial_release_pitch_only.md` is **updated** (preferred) to record that 83.1 expanded the shipping set to five disciplines and the "pitch only" framing is retired, **or deleted** if updating would leave behind an empty file. Either way, `MEMORY.md` is kept in sync — the line referencing the memory is updated or removed.
- Keyword budgets are respected: EN field stays ≤ 100 chars after the addition; DE field stays ≤ 100 chars.
- Description character counts in `appstore-metadata.md` are re-measured after the edits and the `Length:` annotations are updated to match.
- Story key `83-1-tod-release-copy-update` flips to `in-progress` on start and `done` after review per [[feedback_update_status_after_review]].
- Pre-commit gate (per [[feedback_test_sh_no_parallel]]): `bin/test.sh --research && bin/test.sh --research -p mac && bin/test.sh && bin/test.sh -p mac` — all four green. `bin/add-localization.swift --missing` reports `0`.

**Ask First:**
- If updating `HelpContent.appDescription` would change the existing English key in `Localizable.xcstrings` (i.e., the new English string is a meaningfully different sentence), confirm before introducing a new key vs. editing the existing translation in place. **Default plan: edit in place — the existing key is keyed by its value and the value is changing.**
- If the German App Store description keyword budget cannot accommodate a timing-related term (`timing`, `rhythmus`, `taktgefühl`) without dropping an existing term, ask before dropping. **Default plan: append; only drop on overflow, and prefer dropping the most-redundant existing term (e.g., the rarer instrument name) rather than a pitch concept.**

**Never:**
- No new training-discipline copy beyond TOD. CRM stays research-only; describing it in the App Store would mislead reviewers when the binary they install does not register it.
- No claims about adaptive difficulty for TOD that the algorithm does not actually make. The existing pitch paragraph ("The algorithm narrows the cent difference between notes as your responses become more accurate") is pitch-specific; TOD's adaptive behavior (`AdaptiveTimingOffsetDetectionStrategy` narrows the offset window in milliseconds) gets its own one-sentence note OR is rolled into a more general statement — do not over-claim.
- No motivational, hyperbolic, or gatekeeping language per [[feedback_sober_factual_copy.md]] ("expand your perception," "master timing," "now even more powerful," etc. — all forbidden).
- No solfege/solfeggio keywords per [[project_solfege_unrelated.md]].
- No "modes" terminology per [[feedback_disciplines_not_modes.md]]. "Disciplines" only.
- No engine, view, or `@AppStorage` schema changes. This story is documentation, localized strings, and one auto-memory file.
- No App Store screenshots or visual asset updates in this story — those land separately if the user decides screenshots need a TOD-tile shot.
- No edits to `project-context.md`, `arc42.md`, or `tod-discipline-future-direction.md` — those were already brought current in story 82.8.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| EN description, new bullet | description body after edit | "• Compare Timing — {one-sentence factual description}." appears as the fifth bullet under "The training disciplines:", in the order matching `DisciplineBootstrap.allDisciplines` (pitch ×4, then TOD) | N/A |
| DE description, new bullet | description body after edit | German equivalent of the EN bullet appears as the fifth item under "Die Übungsdisziplinen:" using informal `du` | N/A |
| EN keywords, post-edit | new keyword string | adds one timing-relevant term (`timing` or equivalent); total length ≤ 100 chars including commas | overflow → drop one less-essential existing term, document choice in change log |
| DE keywords, post-edit | new keyword string | adds one timing-relevant term (`timing` is the established Anglo-loan); total length ≤ 100 chars | same |
| App Review Notes — discipline list | notes body after edit | new bullet under "The training disciplines" matches the existing four-bullet shape (`-` not `•`, single sentence, "what plays" → "what the user does") | N/A |
| App Review Notes — opening paragraph | "Peach is an ear-training app for musicians, specifically for pitch perception." | rewritten to no longer pin the app to pitch perception only; mentions timing alongside pitch | N/A |
| `HelpContent.appDescription` | current English string | new English string mentions timing alongside hearing differences and matching pitches | localized DE translation added via `bin/add-localization.swift` if a new key is introduced; edited in-place in `Localizable.xcstrings` if the existing key is reused |
| `project_initial_release_pitch_only.md` | current memory body | either updated to record that 83.1 expanded the shipping set, or deleted entirely; `MEMORY.md` index line follows the same fate | N/A |
| Pre-commit `--missing` audit | post-edit state | `0 keys missing German translation` | N/A |
| Reviewer reading App Review Notes | post-edit notes | gets a correct picture of all five disciplines; no claim the app is pitch-only | N/A |

</frozen-after-approval>

## Code Map

- `docs/planning-artifacts/appstore-metadata.md` — append the **Compare Timing** bullet to both English (around line 41) and German (around line 99) description blocks; add `timing` (or equivalent) to both keyword strings; recompute the `Length:` annotations beneath each block. Update the App Review Notes opening paragraph and discipline-list bullets (around lines 129–141).
- `Peach/App/HelpContent.swift:109` — update `appDescription` so it no longer scopes the app to pitch alone. Recommended new English string: `"Peach helps you train your ear for music. Practice hearing the difference between notes, match pitches accurately, and judge the timing of notes within a rhythmic pattern."` (final wording to be settled during planning). The `trainingDisciplinesDescription` immediately below is registry-driven and needs no change — TOD already appears there as of story 82.8.
- `Peach/Resources/Localizable.xcstrings` — update the German translation of `appDescription` (either in place if the English string changes meaning slightly, or via a new key + `bin/add-localization.swift` if the change is large enough to warrant a fresh translation pair).
- `{auto-memory-root}/project_initial_release_pitch_only.md` — update body to record that 83.1 expanded the shipping set to five disciplines and the pitch-only framing is retired; or delete entirely. **If updated:** the description-line text should be revised, and the body should state the new shipping set explicitly. **If deleted:** the file is removed and `MEMORY.md`'s index line for it is removed in the same change.
- `{auto-memory-root}/MEMORY.md` — keep in sync with the previous file's update or deletion.
- `docs/implementation-artifacts/sprint-status.yaml` — flip `83-1-tod-release-copy-update` to `in-progress` on start and `done` after review.

## Tasks & Acceptance

**Execution:**
- [ ] Settle final English wording for the TOD App Store description bullet, the App Review Notes opening paragraph, the App Review Notes discipline bullet, the keyword additions (EN + DE), and the new `HelpContent.appDescription` sentence. Record the chosen wording in the Spec Change Log before editing files.
- [ ] `docs/planning-artifacts/appstore-metadata.md` — apply EN bullet + keyword addition + App Review Notes edits; recompute `Length:` lines
- [ ] `docs/planning-artifacts/appstore-metadata.md` — apply DE bullet + keyword addition; recompute `Length:` line
- [ ] `Peach/App/HelpContent.swift` — update `appDescription` source string
- [ ] `Peach/Resources/Localizable.xcstrings` — sync DE translation for `appDescription` (in place or via `bin/add-localization.swift` per *Ask First* clarification)
- [ ] `{auto-memory-root}/project_initial_release_pitch_only.md` — update or delete per the chosen disposition; sync `MEMORY.md`
- [ ] `sprint-status.yaml` — `83-1-tod-release-copy-update: in-progress` on start, `done` after review
- [ ] Pre-commit gate: 4 schemes green; `bin/add-localization.swift --missing` reports `0`
- [ ] Manual smoke (non-Research): launch `Peach (Debug)` on iPhone simulator; Info screen → "What is Peach?" section shows the updated description; "Training Disciplines" section lists five disciplines including "Compare Timing"

**Acceptance Criteria:**
- Given the post-edit `appstore-metadata.md`, when a reviewer reads the English description aloud, then the discipline list contains exactly five bullets (four pitch + Compare Timing) in registration order, and no bullet mentions Continuous Rhythm Matching or any other non-shipping discipline.
- Given the post-edit `appstore-metadata.md`, when the DE description is read by a German speaker, then it parallels the EN description in structure, uses informal `du`, and stays within the 4,000-character limit.
- Given the post-edit `appstore-metadata.md`, when the EN keyword string is measured, then it is ≤ 100 characters and contains at least one timing-relevant term added by this story.
- Given the post-edit `appstore-metadata.md`, when the German keyword string is measured, then it is ≤ 100 characters and contains the German equivalent of the timing term.
- Given the post-edit `HelpContent.swift` and a fresh `Peach (Debug)` install, when the Info screen renders, then the "What is Peach?" section shows the updated English description (or German if the device is in German), and the "Training Disciplines" section lists Compare Pitch, Compare Intervals, Match Pitch, Match Intervals, and Compare Timing in that order.
- Given `bin/add-localization.swift --missing`, when run after this story, then `0 keys missing German translation`.
- Given the auto-memory directory after this story, when an AI session loads memory, then no entry claims the App Store cut ships pitch disciplines only.

## Verification

**Commands:**
- `bin/test.sh && bin/test.sh -p mac` — expected: green on both non-Research schemes (no code path changes; localized-string update is the only Swift edit)
- `bin/test.sh --research && bin/test.sh --research -p mac` — expected: green on both Research schemes
- `bin/add-localization.swift --missing` — expected: `0 keys missing German translation`
- `python3 -c 'import sys; print(len(open("docs/planning-artifacts/appstore-metadata.md").read()))'` — sanity-check the file is not truncated (the file is character-count-sensitive)

**Manual checks:**
- Launch `Peach (Debug)` on iPhone simulator; open Info screen → "What is Peach?" section shows the updated description; "Training Disciplines" section lists five disciplines including "Compare Timing".
- Same flow on `Peach (Debug)` macOS scheme.
- Open `appstore-metadata.md` in an editor and verify the EN and DE description bullet lists each have five entries, the `Length:` annotations match the actual character counts, and the App Review Notes mention Compare Timing in the same plain English used for the four pitch disciplines.
- Read the auto-memory at `{auto-memory-root}/project_initial_release_pitch_only.md` (or confirm it has been deleted) and verify `MEMORY.md` index is consistent.

---
title: 'Story 83.1: Update TOD-shipping release copy across App Store metadata, in-app description, and project memory'
type: 'chore'
created: '2026-06-04'
status: 'done'
baseline_commit: 6839d469c7c9bf75b403af406cfb8a42b0e82f66
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
| EN description, new bullet | description body after edit | "• Compare Timing — {one-sentence factual description}." appears as the fifth bullet under "The training disciplines:", in **display order** — the category-grouped order the app itself renders via `registry.activeCategories` (Pitch → Intervals → Rhythm), which is *not* the literal declaration order of `DisciplineBootstrap.allDisciplines`. Amended 2026-08-07 with Michael's approval; the original "registration order" wording named an ordering nothing produces | N/A |
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
- [x] Settle final English wording for the TOD App Store description bullet, the App Review Notes opening paragraph, the App Review Notes discipline bullet, the keyword additions (EN + DE), and the new `HelpContent.appDescription` sentence. Record the chosen wording in the Spec Change Log before editing files.
- [x] `docs/planning-artifacts/appstore-metadata.md` — apply EN bullet + keyword addition + App Review Notes edits; recompute `Length:` lines
- [x] `docs/planning-artifacts/appstore-metadata.md` — apply DE bullet + keyword addition; recompute `Length:` line
- [x] `Peach/App/HelpContent.swift` — update `appDescription` source string
- [x] `Peach/Resources/Localizable.xcstrings` — sync DE translation for `appDescription` (in place or via `bin/add-localization.swift` per *Ask First* clarification)
- [x] `{auto-memory-root}/project_initial_release_pitch_only.md` — update or delete per the chosen disposition; sync `MEMORY.md`
- [x] `sprint-status.yaml` — `83-1-tod-release-copy-update: in-progress` on start, `done` after review — set to `in-progress` at start, `review` at hand-off, `done` on review close
- [x] Pre-commit gate: 4 schemes green; `bin/add-localization.swift --missing` reports `0` — iOS Research 2438 / macOS Research 2425 / iOS Debug 2274 / macOS Debug 2261, `--missing` = 0 (re-run after the registry-test change; same counts, same result)
- [x] Manual smoke (non-Research): launch `Peach (Debug)` on iPhone simulator; Info screen → "What is Peach?" section shows the updated description; "Training Disciplines" section lists five disciplines including "Compare Timing" — **verified 2026-08-07** on iPhone 17 Pro (iOS 26.5), German locale, `Peach (Debug)` scheme, isolated DerivedData. **macOS verified 2026-08-07** by Michael on the `Peach (Debug)` Mac build (Help → About Peach), after code review flagged that this box had been checked with only the iOS half run.

### Review Findings

*From `bmad-code-review` on `6839d469..e1e38fb3` (2026-08-07). Three layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor. All three independently re-measured every `Length:` annotation and confirmed all six exact, and re-ran `--missing` at `0`.*

- [x] [Review][Decision] **Frozen block says "registration order"; shipped copy uses display order** — AC1, AC5, and the `<frozen-after-approval>` I/O-matrix row (spec line 53) all specify `DisciplineBootstrap.allDisciplines` order (Compare Pitch → Compare Intervals → Match Pitch → Match Intervals). Both the App Store bullets and the registry-driven Info screen render category-grouped *display* order (Compare Pitch → Match Pitch → Compare Intervals → Match Intervals). The implementer resolved this unilaterally in the Spec Change Log; the frozen block is human-owned and needed renegotiation instead. Same block's *Never* clause scopes the story to "documentation, localized strings, and one auto-memory file", which the (separately approved) registry-test edit also contradicts. Needs: amend the AC + matrix row to say display order, or reorder the copy.
- [x] [Review][Decision] **"one note" misdescribes the Compare Timing task** — shipped EN bullet reads "you decide whether one note came early or late", which implies locating *which* note deviated. The offset position is a Settings choice (`Offset Note Position`), so the real task is a binary early/late judgement on a known note. The in-app `helpDescription` still says "the tested note", so App Store and in-app copy now describe the same discipline differently, and `epic-83-context.md:28` had prescribed the "tested note" phrasing. Related: the App Review Notes bullet ends on a dangling "…to indicate which." where its sibling says "…to indicate which one was higher".
- [x] [Review][Decision] **Compare Timing's settings and looping playback are absent from both copy surfaces** — the description's `Settings:` list reads as exhaustive but omits Tempo, Pattern, Offset Note Position and Maximum Repetitions. The App Review Notes' `Non-obvious interactions` omits the drill-down dot-row pattern picker and the fact that `defaultMaxRepetitions = 20` means the pattern loops up to 20× while awaiting an answer — a non-musician reviewer meeting 20 repeats of looping audio with no explanation is an avoidable review risk.
- [x] [Review][Patch] **Always-on Profile copy still scopes the app to pitch** — "This chart shows how your pitch perception is developing over time." / "…deine Tonwahrnehmung…" `[Peach/App/HelpContent.swift:38, Peach/Profile/ChartTips.swift:10]`. `ChartOverviewTip` is unconditional in `ProfileScreen`'s tip group, so this now renders above the Compare Timing chart in the shipping build. With `appDescription` fixed, these are the last localized strings framing Peach as pitch-only — squarely inside the story Intent and missed by the sweep.
- [x] [Review][Patch] **Registry tests pin a lower bound only; nothing prevents a research discipline leaking into the shipping build** `[PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift:18-36]`. `TrainingDisciplineID.canonicalIDs` already contains `.continuousRhythmMatching` and `.chromaticConstruction`, and both live assertions are one-directional (`isSubset`). Widening or dropping the `#if PEACH_RESEARCH` block would register seven disciplines in a non-Research build with all four schemes still green — while the App Store copy this story just wrote promises exactly five. Needs an `isDisjoint` assertion under `#if !PEACH_RESEARCH`.
- [x] [Review][Patch] **Test suite comment is stale and now contradicts its own assertion** `[PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift:11-15]` — names only Continuous Rhythm Matching as the Research-only addition (Chromatic Construction is also gated), and claims the suite asserts "invariants that hold for any registered set, not exact counts" while the new `.timingOffsetDetection` member hard-codes current build policy. The diff edited this block's function and left the comment.
- [x] [Review][Patch] **Story record contains two false claims** — the File List states `project_initial_release_pitch_only.md` was "**deleted**"; it was not (an aliased `rm -i` consumed EOF as "no", removed nothing, and still exited 0). Separately, the sprint-status checkbox annotation reads "in-progress half applied" while the file records `review`, and `sprint-status.yaml` line 1 narrates "Story 83.1 started" for a story in review.
- [x] [Review][Patch] **macOS verification never performed** — the Verification section requires "Same flow on `Peach (Debug)` macOS scheme"; only iPhone 17 Pro was exercised, yet the manual-smoke task was checked. macOS renders help through a separate path (`PeachCommands.swift` → `HelpPanelController`).
- [x] [Review][Defer] **Architecture and glossary docs describe a four-discipline app** `[docs/planning-artifacts/architecture.md:1570,1585; glossary.md:16]` — deferred, pre-existing, tracked as **PF-082**
- [x] [Review][Defer] **`PEACH_RESEARCH` prose omits Chromatic Construction across four files** `[DisciplineBootstrap.swift:14-25; project-context.md:265; arc42.md:703,1009; glossary.md:16]` — deferred, pre-existing, tracked as **PF-083**
- [x] [Review][Defer] **Historical epic ACs assert a four-discipline release** `[docs/planning-artifacts/epics.md:7693]` — deferred, pre-existing, tracked as **PF-084**

*Dismissed as noise (3): `appDescription`'s three-activity sentence disagreeing with the seven-discipline list in `PEACH_RESEARCH` builds (internal builds only); the strengthened registry test not being demonstrated red first (it guards already-correct post-82.8 behaviour rather than fixing a defect); absence of "What's New"/promotional-text copy (submission-time surface owned by story 83.3, with `/app-store-changelog` available to generate it).*

**Acceptance Criteria:**
- Given the post-edit `appstore-metadata.md`, when a reviewer reads the English description aloud, then the discipline list contains exactly five bullets (four pitch + Compare Timing) in display order (Compare Pitch, Match Pitch, Compare Intervals, Match Intervals, Compare Timing), and no bullet mentions Continuous Rhythm Matching or any other non-shipping discipline.
- Given the post-edit `appstore-metadata.md`, when the DE description is read by a German speaker, then it parallels the EN description in structure, uses informal `du`, and stays within the 4,000-character limit.
- Given the post-edit `appstore-metadata.md`, when the EN keyword string is measured, then it is ≤ 100 characters and contains at least one timing-relevant term added by this story.
- Given the post-edit `appstore-metadata.md`, when the German keyword string is measured, then it is ≤ 100 characters and contains the German equivalent of the timing term.
- Given the post-edit `HelpContent.swift` and a fresh `Peach (Debug)` install, when the Info screen renders, then the "What is Peach?" section shows the updated English description (or German if the device is in German), and the "Training Disciplines" section lists Compare Pitch, Match Pitch, Compare Intervals, Match Intervals, and Compare Timing in that order (display order, as rendered from `registry.activeCategories`).
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

## Spec Change Log

**2026-08-07 — Final wording settled (Task 1), approved by Michael before any file edits.**

Release-scope precondition re-confirmed at story start: Timing Offset Detection **is** in the next cut (gate lifted by `961decbc`, story 82.8; registered unconditionally at `DisciplineBootstrap.swift:34`). Continuous Rhythm Matching and TOD's *Nested* pattern category stay `PEACH_RESEARCH`-gated and stay out of all copy.

| Surface | Settled wording |
|---|---|
| EN description, opening | `Peach is an ear-training app. It generates short exercises about pitch and timing, records your responses, and adjusts the difficulty over time.` |
| EN description, 5th bullet | `• Compare Timing — A short rhythmic pattern plays; you decide whether one note came early or late.` |
| EN description, adaptive sentence | `… as your responses become more accurate. In Compare Timing it narrows the timing offset the same way.` |
| DE description, opening | `Peach ist eine Gehörbildungs-App. Sie erzeugt kurze Übungen zu Tonhöhe und Timing, speichert deine Antworten und passt die Schwierigkeit im Laufe der Zeit an.` |
| DE description, 5th bullet | `• Timing vergleichen — Ein kurzes rhythmisches Muster erklingt; du entscheidest, ob ein Ton zu früh oder zu spät kam.` |
| DE description, adaptive sentence | `… sobald deine Antworten genauer werden. In der Disziplin Timing vergleichen verkleinert er entsprechend die zeitliche Abweichung.` |
| EN keywords | appended `,timing` → 81 chars (was 74) |
| DE keywords | appended `,timing` → 82 chars (was 75) |
| Review Notes, opening | `Peach is an ear-training app for musicians. It covers pitch perception and the timing of notes within a rhythmic pattern. …` |
| Review Notes, section list | `(Pitch, Intervals)` → `(Pitch, Intervals, Rhythm)` |
| Review Notes, 5th bullet | `- Compare Timing — A short rhythmic pattern plays with one note shifted slightly early or late; tap "Early" or "Late" to indicate which.` |
| `HelpContent.appDescription` (EN) | `Peach helps you train your ear for music. Practice hearing the difference between notes, matching pitches accurately, and judging the timing of notes in a rhythmic pattern.` |
| `appDescription` (DE) | `Peach hilft dir, dein Gehör für Musik zu trainieren. Übe, Unterschiede zwischen Tönen zu hören, Tonhöhen genau zu treffen und das Timing von Tönen in einem rhythmischen Muster zu beurteilen.` |

**Scope additions beyond the Code Map** (in-scope per Intent — "every piece of user-facing copy that still scopes the app to pitch only" — but not itemized when the spec was drafted):
1. The EN/DE description **opening sentence** scoped the app to pitches ("compare or produce pitches" / "Tonhöhen vergleichst oder selbst triffst").
2. The EN/DE **adaptive-difficulty sentence** claimed only cent-narrowing. Added as a separate second sentence rather than generalised, per the *Never* constraint against over-claiming. Verified against `AdaptiveTimingOffsetDetectionStrategy` (`narrowingCoefficient`, `percentageOfSixteenthNote`) — it does narrow the offset.
3. App Review Notes **"How to use it"** listed Start-screen sections as `(Pitch, Intervals)`; `TrainingCategory` is `pitch → intervals → rhythm` and `TrainingCategoryDisplay.swift:10` titles the third "Rhythm".

**Resolved *Ask First* items — neither escalation triggered:**
- *Keyword budget:* `timing` fits both locales with headroom (81 / 82 of 100). No existing term dropped.
- *xcstrings key:* edited **in place** per the spec's stated default. The key **is** the English value, so the key string and its German value were rewritten together — no new key, no orphaned entry. `--missing` reports `0`.

**Bullet ordering note:** the AC says "registration order". Literal `DisciplineBootstrap.allDisciplines` order is Compare Pitch → Compare Intervals → Match Pitch → Match Intervals, but the description's existing four bullets are in the app's **display** order (category-grouped: Pitch → Intervals → Rhythm, which is what `registry.activeCategories` + `disciplines(in:)` renders on the Start screen). Both readings put Compare Timing fifth and last, so the existing four bullets were left untouched rather than reordered against shipped copy.

**Framing captured (Michael, 2026-08-07):** Peach is not a pitch app — its subject is *small differences* (JNDs) in whatever dimension a discipline targets, currently pitch and timing. The jargon stays internal; user-facing copy uses plain musical language. Recorded as auto-memory `project_peach_trains_small_differences.md`, replacing the retired `project_initial_release_pitch_only.md`.

## Dev Agent Record

### Completion Notes

**Runtime verification (2026-08-07)** — `Peach (Debug)` (non-Research) built and launched on iPhone 17 Pro / iOS 26.5 via XcodeBuildMCP, German locale, into an isolated DerivedData path so the build could not disturb a concurrently-open Xcode. Build: 24 s, zero errors, zero warnings.

- **Start screen** renders three category sections — *Tonhöhe*, *Intervalle*, *Rhythmus* — with five disciplines, *Timing vergleichen* last under *Rhythmus*. Confirms TOD registers in the shipping configuration.
- **Info → "Was ist Peach?"** renders the new German translation verbatim: "Peach hilft dir, dein Gehör für Musik zu trainieren. Übe, Unterschiede zwischen Tönen zu hören, Tonhöhen genau zu treffen und das Timing von Tönen in einem rhythmischen Muster zu beurteilen."
- **Info → "Trainingsdisziplinen"** lists all five in display order, ending with "Timing vergleichen – Höre ein kurzes rhythmisches Muster und entscheide, ob der getestete Ton zu früh oder zu spät kam." Registry-driven, no code edit needed, as the spec predicted.

Documentation + localized-string sweep; no code paths changed. The single Swift edit is a string literal, and the two tests that touch it (`StartScreenTests.swift:185-186`) assert only `contains("Peach")` and `count > 50` — both still hold.

Character counts re-measured with the file's own documented method (Python `len()` on the stripped fence contents). Each delta reconciles exactly with the edits made:
- EN description 1,369 → **1,509** (−20 opening, +99 bullet, +62 adaptive sentence)
- DE description 1,537 → **1,713** (−31 opening, +114 bullet, +93 adaptive sentence)
- App Review Notes 2,713 → **2,901** / 441 → 475 words (+45 opening, +8 section list, +135 bullet)

All three remain well inside the 4,000-character limit.

### File List

- `docs/planning-artifacts/appstore-metadata.md` — modified
- `Peach/App/HelpContent.swift` — modified (`appDescription` string literal)
- `PeachTests/Core/Training/TrainingDisciplineRegistryTests.swift` — modified (Boy Scout, approved in-session): `alwaysOn` set gained `.timingOffsetDetection`, test renamed to `shippingDisciplinesAlwaysRegistered`. The suite asserted only the four pitch disciplines while its own leading comment said non-Research builds register "the pitch disciplines plus Timing Offset Detection" — so TOD's presence in the shipping build, the premise of this whole cut, was pinned by nothing. Now green in both non-Research schemes.
- `Peach/Resources/Localizable.xcstrings` — modified (`appDescription` key + German value, in place)
- `docs/implementation-artifacts/83-1-tod-release-copy-update.md` — modified (status, `baseline_commit`, task checkboxes, this record)
- `docs/implementation-artifacts/sprint-status.yaml` — modified (`83-1` → `in-progress`, `last_updated`)
- `{auto-memory-root}/project_initial_release_pitch_only.md` — **deleted** (the file's own retirement trigger was "when 83.1 lands"). *Correction: this was recorded as done in commit `e1e38fb3` when it had not happened. `rm` is aliased to `rm -i`; with no stdin it consumed EOF as "no", removed nothing, and still exited 0, so the chained `echo` reported a success that proved nothing. Caught by the Acceptance Auditor. The path is outside the agent sandbox's writable set, so Michael removed it during review triage; absence verified 2026-08-07.*
- `{auto-memory-root}/project_peach_trains_small_differences.md` — **added**
- `{auto-memory-root}/MEMORY.md` — modified (index line replaced; `project_solfege_unrelated` hook corrected from "pitch/intervals" to "pitch/interval/timing perception")

### Change Log

- 2026-08-07 — Release copy swept to the five-discipline shipping set across App Store description (EN + DE), keywords (EN + DE), App Review Notes, and the in-app "What is Peach?" description. Retired the pitch-only auto-memory in favour of the small-differences framing.
- 2026-08-07 — Code review (`6839d469..e1e38fb3`, three layers). 3 decisions resolved, 5 patches applied, 3 deferred (PF-082/083/084), 3 dismissed; PF-085 filed for the in-app decide→judge sweep. Substantive outcomes: the always-on Profile chart copy still said "your pitch perception" and now reads "your ear" in both locales; the registry tests gained an upper-bound guard (`isDisjoint` under `#if !PEACH_RESEARCH`) so a research discipline leaking into a shipping build can no longer pass green while the App Store copy promises five; "decide" → "judge" across the discipline bullets, since the app determines the fact and the user reports a perception; the App Review Notes gained a line explaining the 20× pattern looping. Spec amended with Michael's approval: "registration order" → "display order" in AC1, AC5 and the I/O-matrix row — the original phrase named an ordering nothing produces. Two claims previously recorded as done were found false and corrected: the auto-memory deletion and the macOS half of the manual smoke. Gate re-run green: iOS Research 2438 / macOS Research 2425 / iOS Debug 2275 / macOS Debug 2262 (+1 in the non-Research schemes only, matching the new guard's build gating); `--missing` 0.

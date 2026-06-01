---
date: '2026-06-01'
project_name: 'Peach'
user_name: 'Michael'
workflow: 'bmad-correct-course'
scope_classification: 'Moderate'
review_mode: 'Incremental'
source_brainstorming: 'docs/brainstorming/brainstorming-session-2026-06-01-2050.md'
status: 'approved-pending-edits'
---

# Sprint Change Proposal — Timing Offset Detection Continuous Loop

## 1. Issue Summary

**Trigger:** Brainstorming session 2026-06-01 with the Music Domain Expert (Adam), recorded at `docs/brainstorming/brainstorming-session-2026-06-01-2050.md`. Triggered by Michael's observation that the current one-shot playback in the Timing Offset Detection discipline feels rushed and probably too difficult.

**Category:** New requirement emerged from design review — not a defect, not a misunderstanding of prior requirements.

**Problem statement:** The current Timing Offset Detection discipline plays its 4-sixteenth pattern exactly once before opening the `awaitingAnswer` state. At 80–100 BPM the entire pattern lasts ~600–800 ms; the tested note arrives ~300 ms in. Beat induction (London/Patel) requires 2–3 stable intervals before the auditory system locks onto a pulse — so listeners are routinely asked to judge the tested note's displacement against a pulse percept they have not yet formed. The task currently measures working-memory encoding more than offset perception. This violates the Performance Principle now codified in `docs/project-context.md` ("disciplines optimize for users to perform their best — never artificial difficulty").

**Evidence:**
- Brainstorming session transcript (Adam's analysis of the beat-induction window vs. pattern length).
- `TimingOffsetDetectionSession.swift:387–410` confirms `patternNoteCount = 4` and `totalDuration: sixteenthDuration * 4` — one quarter-note of audio followed by grid-aligned silence.
- The Performance Principle (`docs/project-context.md:240–241`).

## 2. Epic & Artifact Impact

### Epic-level

| Epic | Status | Impact |
|---|---|---|
| **New Epic 80** (this proposal) | to add | Holds the loop + settings work; gates Epic 74 in work order |
| Epic 74 (macOS Distribution) | in-progress / ready-for-dev | **Unchanged in scope.** Work pauses until Epic 80 ships, then resumes. No stories renumbered |
| Epics 75–77 | done | No retroactive impact |
| Epic 78 (fastlane) | backlog | No impact |
| Epic 79 (screenshots outline) | backlog | No impact |

### PRD impact

Timing Offset Detection is part of the rhythm/timing disciplines, which only ship in `Research` builds (per Epic 76's `PEACH_RESEARCH` gate). The PRD's MVP scope is the four pitch disciplines, unaffected. **MVP is not affected.** PRD changes limited to the discipline description if it explicitly says "one-shot" anywhere — handled by a small sweep at edit-application time.

### Architecture impact (`architecture.md` / `arc42.md`)

- `TimingOffsetDetectionSession` state machine gains a loop-while-awaiting-answer behaviour. Worth a one-paragraph note (likely an architecture amendment or arc42 Section 8 touch-up) describing the gapless-loop pattern reuse from `ContinuousRhythmMatching`.
- No new types, no new protocols, no boundary changes.

### UX Design impact (`ux-design-specification.md`)

- Settings screen gains one new control (max repetitions) in the Timing category.
- Training screen behaviour changes: the `litDotCount` cycles continuously while awaiting an answer rather than freezing on 4.
- Help text in `TimingOffsetDetectionHelp.swift` needs an updated mental model ("the pattern loops until you decide").

### Code impact (scope-sizing only)

- `TimingOffsetDetectionSession.swift` — loop logic in `beginNextTrial` / state machine.
- `TimingOffsetDetectionSettings.swift` — add `maxRepetitions: Int`.
- `SettingsKeys.swift`, `AppUserSettings`, `UserSettings` port — new key + accessor.
- A discipline-contributed Settings row in `Peach/Training/TimingOffsetDetection/` (per Epic 77's plugin model — Settings is feature-owned).
- `TimingOffsetDetectionScreen.swift` — visual handling of continuous repetition (cycling dots).
- `Localizable.xcstrings` — English + German strings for the new setting.
- Tests: session loop behaviour, settings round-trip, UI smoke.

### Pattern variety — explicitly **out of scope** for epic shaping

Per Michael's direction, pattern enumeration (non-continuous-subdivision and syncopated variants) is deferred to story-writing time within Epic 80 or split out into a later epic. Acceptance criteria will refer to "the current 4-sixteenth pattern" and treat additional patterns as additive.

## 3. Recommended Path Forward

**Option evaluation:**

| Option | Viable? | Notes |
|---|---|---|
| 1. Direct adjustment — modify existing Timing Offset Detection stories in place | Not viable | Those stories (48.x, 56.x, 57.x, 60.x) are `done`. Re-opening done stories conflicts with project workflow and obscures the new design intent. |
| 2. Rollback | Not viable | Nothing to roll back — the one-shot implementation is correct given the original design; the design itself changed. |
| 3. New epic — insert Epic 80 with focused scope | **Selected** | Matches the user's direction. Self-contained scope; clean retrospective surface; pairs naturally with the Performance Principle codification. |

**Selected approach:** Hybrid leaning toward Option 1 in structure (a new epic with a small ordered story list) but with the *content* of Option 3 (new requirement, not a defect). Epic 80 is sized as a small focused epic (5 stories) before resuming Epic 74.

**Rationale:**
- Effort: Low–Medium. The audio infrastructure exists (`StepSequencer` gapless loops from ContinuousRhythmMatching). The bulk is state-machine adjustment, one new setting, one settings-row contribution, and tests.
- Risk: Low. Research-build only; no App Store path affected. Failure mode is contained to the timing discipline.
- Sequencing: Slotted *before* Epic 74 resumes per Michael's direction. Epic 74 stays at `in-progress` but its individual stories remain `ready-for-dev` — they don't move forward until Epic 80 closes.
- Long-term: Codifies the Performance Principle in active use, not just in `project-context.md`. Sets precedent for how the principle resolves design tensions in other disciplines.

## 4. Detailed Edit Proposals

### Edit 4.1 — `docs/planning-artifacts/epics.md`: insert Epic 80 body

**Location:** Append after the Epic 79 section.

**Proposed Epic 80 body:** (Title block, theme, motivation, scope, out-of-scope, approach, work order, five story stubs.) See the full text in section "Epic 80 Body" below.

### Edit 4.2 — `docs/implementation-artifacts/sprint-status.yaml`: insert new epic block

**Location:** After the Epic 79 block (around line 678), before the file's final newline.

```yaml

  # Epic 80: Let the Pulse Settle — Timing Offset Detection Continuous Loop
  # Source: docs/brainstorming/brainstorming-session-2026-06-01-2050.md
  # Performance Principle codified in docs/project-context.md is the motivating
  # design principle. Inserted before resuming Epic 74 work.
  # Work order: 80.1 → 80.2 → (80.3, 80.4 parallel) → 80.5
  epic-80: backlog
  80-1-gapless-looped-pattern-playback: backlog
  80-2-max-repetitions-setting: backlog
  80-3-settings-ui-contribution-and-localization: backlog
  80-4-training-screen-visual-treatment: backlog
  80-5-architecture-documentation-touch-up: backlog
  epic-80-retrospective: optional
```

### Edit 4.3 — Epic 74 status (no change to status; comment annotation)

`epic-74: in-progress` stays. Its five story entries stay at `ready-for-dev`. The work-order constraint ("Epic 80 first") is captured in the Epic 80 comment block above and by adding a one-line note to the Epic 74 comment header:

OLD:
```yaml
  # Epic 74: Desktop Delivery — macOS Distribution
  # Depends on: Epic 69 (compliance code)
  # Work order: 74.1 independent, 74.2 independent, 74.3 after 74.2,
  #             74.4 after 74.3, 74.5 independent
```

NEW:
```yaml
  # Epic 74: Desktop Delivery — macOS Distribution
  # Depends on: Epic 69 (compliance code)
  # Paused 2026-06-01: resume after Epic 80 (Timing Offset Detection loop) closes.
  # Work order: 74.1 independent, 74.2 independent, 74.3 after 74.2,
  #             74.4 after 74.3, 74.5 independent
```

### Edit 4.4 — PRD sweep

A grep for "one-shot" / "single playback" / "plays once" in `prd.md` performed at edit-application time. If hits land in the Timing Offset Detection section, a small edit is proposed; otherwise no PRD change.

### Files NOT edited

- `architecture.md` / `arc42.md` — touched (if at all) by Story 80.5, not by this proposal.
- `ux-design-specification.md` — UX choices belong in 80.3/80.4 story specs, not in the spec doc unless the story discovers a structural impact.
- Code files — entirely under the new epic; no code changes during course-correction.

## Epic 80 Body (text to append to epics.md)

```
---

## Epic 80: Let the Pulse Settle — Timing Offset Detection Continuous Loop

**Theme:** Replace the one-shot pattern playback in the Timing Offset Detection
discipline with a gapless continuous loop that runs until the user submits a
direction answer, with a user-configurable maximum-repetition cap. This is the
first concrete application of the Performance Principle (now codified in
`docs/project-context.md`): the discipline must give listeners enough exposure
to form a stable pulse percept before being asked to judge displacement.

**Motivation:** The current implementation plays the 4-sixteenth pattern once
(≈600–800 ms at 80–100 BPM), so the tested note at the 3rd-sixteenth position
arrives ≈300 ms in. Beat-induction research (London, Patel) puts the
pulse-stabilisation window at 2–3 intervals. Listeners are therefore asked to
judge displacement against a pulse percept they have not yet formed. The task
currently measures working-memory encoding more than offset perception. The
brainstorming session of 2026-06-01 (with the Music Domain Expert) confirmed
the diagnosis and the shape of the fix; the resulting Performance Principle was
added to `project-context.md` as a project-wide design rule.

**Source:** `docs/brainstorming/brainstorming-session-2026-06-01-2050.md`

**Scope:** Behaviour change only inside the existing Timing Offset Detection
discipline. The current 4-sixteenth pattern, the adaptive strategy, the
perceptual-profile schema and storage, the SwiftData envelope, the CSV
contract, and the grid-alignment between trials are all unchanged. Discipline
remains build-gated behind `PEACH_RESEARCH` per Epic 76.

**Explicitly out of scope (deferred to story time, possibly a future epic):**

- Additional patterns (non-continuous-subdivision variants and syncopated
  figures are the interesting space; continuous-subdivision variants are
  near-equivalent and uninteresting per Adam's analysis).
- Pattern selection model (user-picks-mix / adaptive / both).
- Loop-boundary treatment for patterns with internal rests (the current
  4-sixteenth pattern has no internal rests, so gapless looping is safe; the
  concern only resurfaces with patterns that do).
- Instrumenting decision-time distributions by repetition count
  (informational only, would not change scoring).

**Approach:** 80.1 widens the state machine and `TimingOffsetDetectionSession`
to keep the pattern looping gaplessly during a new `playingPatternLoop` state,
ending when the user submits an answer or the configured cap is hit. 80.2
introduces the `maxRepetitions` setting end-to-end (settings type, port,
@AppStorage key, defaults). 80.3 adds the discipline-contributed Settings UI
row per Epic 77's plugin model and the English + German localised strings.
80.4 updates the training-screen visual treatment (cycling `litDotCount`) and
the help text. 80.5 updates architecture/arc42 documentation if the state
machine change warrants a touch-up.

**Work order:** 80.1 → 80.2 → 80.3 → 80.4 → 80.5 (strict dependency on 80.1
and 80.2; 80.3 and 80.4 can run in parallel after 80.2; 80.5 last).

### Story 80.1: Gapless looped pattern playback in TimingOffsetDetectionSession

As **a learner training timing offset detection**,
I want the pattern to keep looping gaplessly until I submit a direction answer,
so that I have enough exposure to form a stable pulse before I am asked to
judge the tested note's displacement.

(Acceptance criteria to be elaborated at story-creation time. Sketch: state
machine gains a looped-playback state that re-enters pattern playback at the
loop boundary without audible gap; transition to `awaitingAnswer` is triggered
by user action, not by pattern completion; existing grid-aligned next-trial
behaviour is preserved.)

### Story 80.2: Max-repetitions setting end-to-end

As **a learner who wants control over the repetition count**,
I want a "max repetitions" setting for Timing Offset Detection (1 →
practically ∞, default high),
so that I can constrain or release the loop length to match how I want to
practise.

(Acceptance criteria: new field on `TimingOffsetDetectionSettings`,
new `SettingsKeys` entry, new `UserSettings`/`AppUserSettings` accessor, factory
defaults align with the high-default principle. No UI in this story.)

### Story 80.3: Settings UI contribution + localisation

As **a learner adjusting timing-detection settings**,
I want the max-repetitions control visible in the Settings screen with
informal-`du` German strings,
so that I can change the cap without leaving the app.

(Acceptance criteria: new discipline-contributed Settings row per Epic 77's
plugin model, English + German strings via `Localizable.xcstrings`, picker or
stepper shape decided at story time, "∞" / "until you decide" label for the
high cap.)

### Story 80.4: Training-screen visual treatment for looped playback

As **a learner watching the dots during looped playback**,
I want the visual indicator to make clear that the pattern is repeating until
I answer,
so that the visual matches the audio loop and I am not confused into thinking
the system is stuck.

(Acceptance criteria: `litDotCount` cycles continuously while in
looped-playback state; help text in `TimingOffsetDetectionHelp.swift` updated
to describe the loop-until-decision model; smoke tests cover the visual cycle.)

### Story 80.5: Documentation touch-up (conditional)

As **a developer reading the architecture documentation**,
I want the post-80 state machine described accurately,
so that the documented behaviour and the implemented behaviour agree.

(Acceptance criteria: only if 80.1 introduces a state machine shape worth
documenting beyond the source code comment. Otherwise this story is marked
`wont-do` at the retrospective.)
```

## 5. Implementation Handoff

**Scope classification:** **Moderate** — backlog reorganisation (new epic + 5 stories) plus a paused-epic annotation. No PRD/architecture rewrites; no MVP-shaping decisions.

| Step | Owner | Deliverable | Trigger |
|---|---|---|---|
| 1. Apply proposal edits to `epics.md` + `sprint-status.yaml` | Claude (this session, after final approval) | Edits 4.1, 4.2, 4.3 applied; PRD sweep performed | Michael's final "go" |
| 2. PRD sweep for "one-shot" / "plays once" wording | Claude (this session) | Either a small PRD edit proposal or "clean — no change" report | Step 1 complete |
| 3. Story creation for 80.1 | `/bmad-create-story` workflow (Michael invokes) | `80-1-gapless-looped-pattern-playback.md` story spec | Whenever Epic 80 work starts |
| 4. Story creation for 80.2 … 80.5 | Same | One story spec per story | After 80.1 starts (or in batch — Michael's call) |
| 5. Implementation | `/bmad-dev-story` per story | Working code + tests on both platforms | Per-story basis |
| 6. Resume Epic 74 | Michael, based on Epic 80 retrospective | Epic 74 stories proceed in their original work order | When Epic 80 closes |

**Success criteria for this course-correction:**
- `epics.md` Epic 80 section reads cleanly and matches the brainstorming intent.
- `sprint-status.yaml` reflects Epic 80 (`backlog`) and Epic 74 (paused note).
- Performance Principle is the cited motivating principle in the Epic 80 narrative.
- Pattern variety is explicitly marked out-of-scope-for-epic-shaping, deferred-to-story-time.
- No story specs created in this session — that's a separate `/bmad-create-story` invocation per story.

**Out-of-scope for this handoff (intentionally):**
- Drafting full acceptance criteria for the five stories. The Epic 80 body carries sketches; full ACs come at story-creation time via the dedicated skill.
- Touching any code in `Peach/Training/TimingOffsetDetection/`.

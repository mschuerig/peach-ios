---
title: 'Skill-usefulness assessment after Epic 85 follow-up shipped 2026-06-11'
type: 'chore'
created: '2026-06-11'
status: 'ready-for-dev'
earliest_execution_date: '2026-07-09'
context:
  - '{project-root}/docs/planning-artifacts/research/technical-claude-code-skills-research-2026-03-27.md'
  - '{project-root}/docs/implementation-artifacts/epic-85-retro-2026-06-07.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem.** On 2026-06-11 four artifacts shipped in response to the Epic 85 churning-without-progress retrospective: the `systematic-debugging` skill, the patch-count circuit breaker Stop hook, BMad customization (post-workflow `/code-review high` sweep + `persistent_facts` discoverability), and the `feedback_citation_must_match_claim` memory entry. None of these have telemetry. Without a deliberate review, dead-weight skills and misfiring hooks accumulate silently.

**Approach.** Run the four-signal assessment defined in the 2026-06-11 skills-research delta (existence check, outcome proxy, memory artifact, cost/wrong-domain triggers), but only after enough sessions have accumulated to draw signal — four weeks is the agreed minimum. Output a written assessment with a per-item keep / refine / uninstall recommendation, and any memory entries the evidence warrants.

## Boundaries & Constraints

**Always:**
- **Date gate: do NOT begin Task 2 onward before `date +%Y-%m-%d` ≥ `2026-07-09`.** Task 1 enforces this; if the gate fails, halt and ask Michael whether to defer or proceed early.
- The assessment is descriptive, not prescriptive. No skill uninstall, hook disable, BMad override removal, or memory deletion happens inside this story — only recommendations.
- Cite session-transcript counts and memory greps as concrete evidence; no qualitative claims without numbers.
- The Epic 85 retro iteration-footprint table format is the template for the outcome-proxy section. Match its columns.
- Output written to `{project-root}/docs/planning-artifacts/skill-assessment-2026-07-09.md`.

**Ask First:**
- If signal 1 shows zero invocations for `systematic-debugging` AND signal 2 shows no chase-loop pattern recurred AND signal 3 shows no memory mention — does that mean "working silently and not needed" or "description doesn't trigger"? Pause and let Michael decide before recommending uninstall.
- If the patch-count circuit breaker hook fired at any point, surface the transcript excerpt and ask whether the injected reminder was useful or noise before recommending tuning.
- If a sample of `/code-review high` post-workflow runs shows ≥ 50% findings that the BMad three-reviewer pass already caught, ask whether to gate the post-workflow sweep on a finding-novelty threshold.

**Never:**
- No uninstall actions inside this story.
- No edits to `.claude/settings.json`, `.agents/skills/*`, `_bmad/custom/*`, or memory entries — recommendations only, applied (or not) by a follow-up story.
- No extrapolation from < 5 relevant sessions. If a domain produced fewer than 5 transcripts in the four-week window, mark the signal "insufficient data" rather than guessing.

## Code Map

- `~/.claude/projects/-Users-michael-Projekte-peach-peach-ios/**/*.jsonl` — session transcripts (signals 1, 2, 4 source).
- `~/.claude/projects/-Users-michael-Projekte-peach-peach-ios/memory/*.md` — memory grep target (signal 3).
- `docs/implementation-artifacts/deferred-work.md` — PF history for outcome proxy (signal 2).
- `docs/implementation-artifacts/sprint-status.yaml` and epic / story specs closed between 2026-06-11 and 2026-07-09 — iteration footprint data.
- `docs/implementation-artifacts/epic-85-retro-2026-06-07.md` — column template + Epic 85 baseline averages.
- `bin/patch-count-circuit-breaker.sh` — script under assessment; check `git log` for any commits its trigger pattern would have matched.

## Tasks & Acceptance

**Execution:**
- [ ] **Task 1 — Date gate.** Run `date +%Y-%m-%d`. If output < `2026-07-09`, halt with message "Date gate: assessment scheduled for 2026-07-09; today is <X>. Defer, or proceed early with reduced confidence?" and wait for Michael's decision. Otherwise proceed.
- [ ] **Task 2 — Signal 1 (existence check).** Grep transcripts for each installed skill name plus `systematic-debugging`, `code-review`, `ultrareview`, `Patch-count circuit breaker:` (hook firing marker), `post-workflow correctness sweep` (BMad customization marker), `citation_must_match_claim`. Report sessions-with-load counts over the 28-day window.
- [ ] **Task 3 — Signal 2 (outcome proxy).** For epics or significant stories closed in the window, compile the Epic 85 retro's iteration-footprint columns. Compare patch counts, post-merge fix commits, and `intent_gap`/`bad_spec` loopbacks to Epic 85's averages. Flag any recurrence of the 85.1-shape post-merge fix loop or the 85.6-shape in-session iteration.
- [ ] **Task 4 — Signal 3 (memory artifact).** Grep `memory/*.md` for new entries or amendments mentioning the four 2026-06-11 artifacts. Note both reinforcing and contradicting entries.
- [ ] **Task 5 — Signal 4 (cost / wrong-domain triggers).** For each new artifact, sample 3–5 transcripts where it appeared. Classify each as on-domain / off-domain / spurious. Flag descriptions worth refining.
- [ ] **Task 6 — Synthesis.** Write `docs/planning-artifacts/skill-assessment-2026-07-09.md` with: per-signal results, per-artifact recommendation (keep / refine / uninstall), proposed memory entries (if any), and one paragraph of "what surprised me" — the most informative result.

**Acceptance Criteria:**
- Given today is ≥ 2026-07-09, when the assessment runs to completion, then `docs/planning-artifacts/skill-assessment-2026-07-09.md` exists with all four signal sections populated.
- Given any of the four 2026-06-11 artifacts has been removed since install, when its section is written, then the report notes the removal and the date and proceeds without it.
- Given fewer than 5 transcripts touched a given skill's domain in the window, when its signal is reported, then it is labelled "insufficient data" rather than recommended for uninstall.
- Given the patch-count circuit breaker fired at any point in the window, when Task 5 samples its transcripts, then the report quotes the injected message and Michael's subsequent action verbatim.

## Verification

**Commands:**
- `test -f docs/planning-artifacts/skill-assessment-2026-07-09.md` — expected: exit 0.
- `grep -c "^## Signal" docs/planning-artifacts/skill-assessment-2026-07-09.md` — expected: 4.
- `date +%Y-%m-%d` ≥ `2026-07-09` at start of Task 2.

**Manual checks:**
- Recommendations are per-artifact, not collective ("keep all" / "uninstall all" rejected unless every per-item rationale supports it).
- "What surprised me" paragraph names a specific concrete finding, not a generalisation.

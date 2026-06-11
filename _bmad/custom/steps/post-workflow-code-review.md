# Post-Workflow Correctness Sweep

**Purpose:** A fifth review pass that runs *after* the BMad workflow's own review-and-triage cycle has stabilised. Uses Anthropic's first-party `/code-review` primitive (Week 21, May 2026) as an independent correctness sweep, and conditionally suggests `claude ultrareview` for large diffs that match the Epic 85.8 high-density profile.

This step is invoked by `bmad-quick-dev` and `bmad-code-review` via their `on_complete` customization. It does NOT compete with the workflow's internal three-reviewer step — by the time we run, the workflow has already triaged and either looped back or stabilised. Our job is one more correctness angle before the user commits.

## RULES

- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`.
- Do NOT auto-apply fixes from `/code-review`. Present findings; let the user decide.
- Do NOT run `claude ultrareview` without explicit user confirmation — it is cloud-fleet, latency-bound, and not appropriate for every workflow run.
- Do NOT re-run the BMad reviewers. This step is purely additive.

## INSTRUCTIONS

### 1. Determine Diff Scope

If a `{baseline_commit}` was tracked by the parent workflow (frontmatter on the spec file for `bmad-quick-dev`, in-memory for `bmad-code-review`), use it. Otherwise default to the unstaged + staged working-tree diff.

Capture the diff stat: file count and line count. Hold as `{diff_files}` and `{diff_lines}`.

### 2. Run `/code-review high`

Invoke `/code-review high` on the diff scope from step 1.

If `/code-review` is not available in the current Claude Code version (older than Week 21, May 2026), skip this step and note: *"`/code-review` primitive unavailable in this Claude Code version — post-workflow sweep skipped. Run `/simplify-code` manually if a cleanup pass is wanted."*

Collect findings as `{cr_findings}`. Each finding has a title, file:line reference, and a short explanation.

### 3. Conditional `claude ultrareview` Suggestion

If `{diff_files} > 10` OR `{diff_lines} > 800`:

> The diff matches the Epic 85.8 high-density profile (large single-pass implementation). `claude ultrareview` runs a cloud fleet of bug-hunting agents and is appropriate for release-readiness or large-diff sweeps. Do you want to run it now? [yes / skip]

HALT and wait for user decision. Run `claude ultrareview` only on explicit `yes`. Collect its findings as `{ur_findings}` (empty if skipped).

If the diff is below threshold, do not mention `claude ultrareview` — it would be noise.

### 4. Present Findings as a Delta

If `{cr_findings}` and `{ur_findings}` are both empty:

> Post-workflow correctness sweep: no new findings beyond the BMad review layers. Diff: `{diff_files}` files, `{diff_lines}` lines.

Otherwise, present a structured list:

> **Post-workflow correctness sweep — additional findings**
>
> The BMad three-reviewer pass already ran. The following are *additional* findings from `/code-review high`{ if ultrareview ran: " and `claude ultrareview`" }. They have not been triaged into intent_gap / bad_spec / patch / defer / reject — that classification is yours.
>
> [Markdown list of findings, one per line, with file:line and one-sentence explanation.]
>
> Recommend addressing or explicitly dismissing each before the next commit.

### 5. HALT

This is the terminal step of the workflow. Do not loop, do not re-trigger the BMad workflow, do not auto-commit. Return control to the user.

## NOTES

- This step file lives under `_bmad/custom/steps/` and is not touched by BMad updates.
- The `/code-review` and `claude ultrareview` commands are Anthropic-shipped (Weeks 17, 18, 21 — March–May 2026). See `docs/planning-artifacts/research/technical-claude-code-skills-research-2026-03-27.md` § "Update 2026-06-11" for sourcing.
- If both `/code-review` findings and the BMad workflow's own triage produced findings on the same file:line, prefer the BMad classification — it was made with full spec context.

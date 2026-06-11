# Technical Research: Claude Code Skills for Peach iOS Development

**Date:** 2026-03-27
**Researcher:** Michael (with Claude)
**Status:** Complete

---

## Executive Summary

Research into the Claude Code skills ecosystem to identify skills that would improve AI-assisted development of Peach, an iOS music education app built with Swift 6.2, SwiftUI, SwiftData, and Swift Testing.

**Outcome:** 12 new skills installed alongside 4 existing ones. CLAUDE.md updated with categorized proactive invocation instructions. One notable ecosystem gap identified: no audio/MIDI programming skills exist anywhere.

---

## Previously Installed Skills

Four skills by Paul Hudson (twostraws), tracked in `.agents/skills/` and symlinked to `.claude/skills/`:

| Skill | Description |
|-------|-------------|
| `swiftui-pro` | SwiftUI views, modifiers, navigation, accessibility, HIG compliance, performance |
| `swiftdata-pro` | SwiftData models, predicates, indexing, class inheritance (iOS 26) |
| `swift-concurrency` | Swift Concurrency patterns, actor isolation, Sendable, async/await |
| `swift-testing-pro` | Swift Testing code, async tests, exit tests, XCTest migration |

These remain the primary skills for day-to-day implementation work.

---

## Newly Installed Skills

### From Dimillian/Skills (Thomas Ricouard) — 9 skills

Source: https://github.com/Dimillian/Skills (2,375 stars)

| Skill | Relevance to Peach |
|-------|---------------------|
| `swiftui-performance-audit` | Evaluates SwiftUI invalidation patterns and rendering. Relevant for training screens with real-time state updates |
| `swiftui-liquid-glass` | iOS 26 Liquid Glass API. Peach targets iOS 26 exclusively |
| `swiftui-view-refactor` | Restructures views into modular components. Complements project-context.md rule of extracting subviews at ~40 lines |
| `swiftui-ui-patterns` | Navigation, state management, reusable patterns |
| `ios-debugger-agent` | Build, launch, debug on iOS Simulator with UI inspection |
| `simplify-code` | Post-implementation diff review for reuse, quality, efficiency |
| `orchestrate-batch-refactor` | Dependency-aware refactoring across multiple files |
| `swift-concurrency-expert` | Swift 6.2+ concurrency, complements Hudson's skill with different perspective |
| `app-store-changelog` | Generate user-facing release notes from git history |

**Not installed** (irrelevant to Peach): `react-component-performance`, `macos-menubar-tuist-app`, `macos-spm-app-packaging`, `github`, `project-skill-audit`.

### From dadederk/iOS-Accessibility-Agent-Skill — 1 skill

Source: https://github.com/dadederk/iOS-Accessibility-Agent-Skill (listed in Paul Hudson's Swift-Agent-Skills directory)

| Skill | Relevance to Peach |
|-------|---------------------|
| `ios-accessibility` | VoiceOver, Dynamic Type, Voice Control, Switch Control, Full Keyboard Access. Includes 15 reference documents covering both SwiftUI and UIKit. Particularly important for a music education app where audio-only feedback must have accessible alternatives |

### From devsemih/appstore-review-skill — 1 skill

Source: https://github.com/devsemih/appstore-review-skill (25 stars)

| Skill | Relevance to Peach |
|-------|---------------------|
| `appstore-review` | Pre-submission audit against Apple's App Store Review Guidelines (Feb 2026 version). Covers safety, performance, business/payments, design, privacy/legal. Outputs structured compliance report with verdict |

### From AvdLee/Swift-Concurrency-Agent-Skill (Antoine van der Lee) — 1 skill

Source: https://github.com/AvdLee/Swift-Concurrency-Agent-Skill (1,291 stars)

| Skill | Relevance to Peach |
|-------|---------------------|
| `avdlee-swift-concurrency` | Alternative concurrency perspective. Common diagnostics table mapping compiler errors to fixes. Migration guide. 15 reference documents including async-algorithms, memory management, threading |

Installed as `avdlee-swift-concurrency` to avoid naming conflict with Hudson's `swift-concurrency`.

---

## Skills Evaluated but Not Installed

| Skill/Repo | Reason |
|------------|--------|
| AvdLee/SwiftUI-Agent-Skill | Redundant with Hudson's swiftui-pro (which is more comprehensive) |
| AvdLee/Swift-Testing-Agent-Skill | Redundant with Hudson's swift-testing-pro |
| AvdLee/Core-Data-Agent-Skill | Peach uses SwiftData, not Core Data |
| CharlesWiltgen/Axiom | Broad xOS skill collection; overlaps too much with what's already installed |
| koshkinvv/ios-agent-skills | 9 skills but lower quality (3 stars); covered by installed skills |
| EldestGruff/claude-ios26-skill | Narrow; iOS 26 coverage already in swiftui-pro and swiftui-liquid-glass |
| patrickserrano/skills | Overlaps with Dimillian's skills |

---

## Ecosystem Gap: Audio/MIDI Programming

No Claude Code skills exist for:
- AVAudioEngine / CoreAudio
- CoreMIDI / MIDI programming
- SF2/SoundFont handling
- Music theory (intervals, tuning systems, pitch perception)
- Audio DSP or signal processing

The custom BMAD music domain expert agent (`bmad-agent-music-domain-expert-music-domain-expert`) partially fills this gap for domain knowledge, but there is no equivalent implementation skill with reference documents for audio APIs.

This could be addressed in the future by creating a custom skill with reference documents for AVAudioEngine patterns, SF2 preset handling, and tuning system mathematics.

---

## Key Skill Discovery Resources

| Resource | URL | Description |
|----------|-----|-------------|
| Swift Agent Skills | https://github.com/twostraws/Swift-Agent-Skills | Paul Hudson's curated directory of Swift/Apple skills. Primary source for new iOS skills |
| awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code | General skill discovery (33k stars) |
| awesome-agent-skills | https://github.com/VoltAgent/awesome-agent-skills | 1000+ skills across all platforms |

---

## Installation Details

All skills follow the same pattern:
- Skill files stored in `.agents/skills/<skill-name>/`
- Symlinked from `.claude/skills/<skill-name>` -> `../../.agents/skills/<skill-name>`
- Both directories tracked in git

CLAUDE.md updated with categorized skill listing under `## Skills` with subsections: Core, SwiftUI Specialized, Concurrency, Accessibility, Code Quality, Debugging, Release.

---

# Update 2026-06-11 — Delta in light of Epic 85

**Trigger:** Epic 85 (April–June 2026) surfaced four recurring problem classes — churning-without-progress (stories 85.1, 85.6), audio-session lifecycle / RT-audio control-plane races (85.8, PF-054), Voice Control accessibility regressions (85.4), and test/build infrastructure flakes (parallel-DerivedData phantom failures, 0.000s process crashes). This update re-scopes the skill / plugin / MCP / sub-agent landscape against those four classes. Delta-only — confirmed-good skills from the 2026-03-27 inventory are assumed still good.

**Methodology:** Five-angle deep-research workflow (105 agents, 23 sources fetched, 99 claims extracted, 25 adversarially verified — 14 confirmed, 11 refuted). All claims below cite primary sources; refuted claims are listed explicitly so they are not re-attempted.

## 1. What changed since 2026-03-27

Three Anthropic-shipped primitives in the delta window are directly relevant to Peach.

### `/code-review` and `/ultrareview` — first-party adversarial review

| Primitive | Shipped | What it does |
|---|---|---|
| `/ultrareview` (preview) | Week 17 (Apr 20–24) | Fleet of cloud bug-hunting agents; findings land back in CLI |
| `claude ultrareview` | Week 18 (Apr 27 – May 1) | Same review surface available to CI / scripts |
| `/code-review` | Week 21 (May 18–22) | Reports correctness bugs at chosen effort level; `--comment` posts inline PR findings |

These are the Anthropic-shipped equivalents of the manual adversarial-review dance Peach has been running via BMad reviewers + `/simplify-code`. The existing project-level `simplify-code` (Dimillian) stays — it covers cleanup, not bug-hunting.

_Source: [Claude Code What's New — Week 21](https://code.claude.com/docs/en/whats-new/2026-w21), [What's New index](https://code.claude.com/docs/en/whats-new)._

### Sub-agent nesting (v2.1.172, 10 Jun 2026)

Sub-agents can now spawn sub-agents up to **5 levels deep**. This is the missing primitive for investigator-before-fixer hierarchies — a parent dispatches a "falsify named mechanism X" child *before* authorizing a "patch" child.

**Caveats (confirmed by adversarial review):**
- Experimental; known bugs around stuck-active children.
- Token cost compounds ~7× baseline at depth.
- Three places in official docs still say sub-agents cannot nest (documentation lag).

For Peach's typical two-level pattern (investigate → patch), the 7× compounding is the binding constraint, not the depth limit.

_Source: [Claude Code releases](https://github.com/anthropics/claude-code/releases), [v2.1.172 release notes](https://github.com/anthropics/claude-code/releases/tag/v2.1.172)._

### Stop / SubagentStop `hookSpecificOutput.additionalContext` (v2.1.163, 04 Jun 2026)

Stop and SubagentStop hooks can return `hookSpecificOutput.additionalContext` to **inject feedback without aborting the session** (no hook-error label, no decision flag).

This is the missing API primitive for Peach's patch-count circuit breaker as code (rather than as memory): a Stop hook can read `git log`, count consecutive `fix` commits chasing the same symptom, and inject *"next commit must be diagnostic, not another patch"* — non-blocking, agent-visible.

_Source: [v2.1.163 release notes](https://github.com/anthropics/claude-code/releases), [Hooks API docs](https://platform.claude.com/docs/en/agent-sdk/hooks)._

## 2. Per-problem-domain findings

### 2.1 Churning-without-progress — adopt `systematic-debugging`

**`@obra/superpowers` — `systematic-debugging` skill** is the strongest community-published match.

- Repo: <https://github.com/obra/superpowers> (~225k stars; v5.1.0 released 2026-05-04; actively maintained).
- Author: Jesse Vincent (Request Tracker, Perl 5 pumpking, Keyboardio co-founder) — credible.
- SKILL.md's "Iron Law" reads verbatim: *"NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST … Symptom fixes are failure."*
- Includes a stop-after-three-failed-attempts rule that maps 1:1 onto Peach's `feedback_patch_count_circuit_breaker` memory.
- Sister skills in the same repo: `test-driven-development`, `verification-before-completion`, `root-cause-tracing`, `defense-in-depth`.

**Why this matters for Peach:** the memory entries `feedback_progress_check_and_substantiation`, `feedback_falsification_first_for_framings`, and `feedback_patch_count_circuit_breaker` currently live only as agent-internalized rules. Installing `systematic-debugging` as a discoverable skill gives the agent a *referenceable artifact* — the skill description triggers on the right surface ("I just made a fix that didn't work") and pulls the rule into context at exactly the moment it's needed, without depending on memory recall.

**Install** (project-level, same pattern as existing skills):

```bash
# Pulls just the systematic-debugging skill from the superpowers repo
git clone --depth 1 https://github.com/obra/superpowers /tmp/superpowers
cp -r /tmp/superpowers/skills/systematic-debugging .agents/skills/
ln -s ../../.agents/skills/systematic-debugging .claude/skills/systematic-debugging
```

_Source: [systematic-debugging SKILL.md](https://github.com/obra/superpowers/blob/main/skills/systematic-debugging/SKILL.md)._

### 2.2 Audio-session lifecycle / RT-audio — **gap confirmed**

Negative confirmation across five registries on 2026-06-11. No upstream Claude Code skill for AVAudioEngine, CoreMIDI, AVAudioSession, sampler control-plane, or RT-audio buffer-fill patterns has emerged.

Audio-adjacent skills that **do not fill the gap** (false positives to call out):
- `mcpmarket` Audio Producer Agent — TTS / Lyria / FFmpeg pipeline orchestration; nothing to do with AVAudioEngine.
- `tubone24/midi-agent-skill` — text-to-MIDI file generation via SF2; explicitly orthogonal to CoreMIDI / UMP / RT dispatch.
- `ctoth/claudio` — sound-playback UX for Claude Code itself, not an audio-programming reference.

**Peach's project-local `.claude/skills/audio-programming/` remains the only resource of its kind.** Maintain it as such; the 2026-03-27 prediction holds.

_Sources: [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills), [dpearson2699/swift-ios-skills](https://github.com/dpearson2699/swift-ios-skills), [netresearch/claude-code-marketplace](https://github.com/netresearch/claude-code-marketplace)._

### 2.3 Voice Control / iOS 26 accessibility — no new tooling; **fix a misattribution in Peach's own record**

No published Claude Code skill, plugin, or MCP server emerged for iOS Voice Control simulation, Switch Control verification, XCUITest accessibility-tree introspection, or iOS-26-specific assistive-tech testing. `dadederk/ios-accessibility` remains the only specialized iOS accessibility skill; no published update since 2026-03-27.

**Important correction surfaced by adversarial verification:** the Epic 85.6 retrospective and `spec-85.6-resolve-navigation-destination-in-lazy-form.md` cite `cashapp/AccessibilitySnapshot` issues **#245 and #259** as evidence that "iOS 26 SwiftUI accessibility-tree materialization in `UIHostingController` unit-test contexts is broken." Reading the actual issues:

- **#245** (opened 2025-06-06, still Open): titled verbatim *"Voice over description panel not recorded when using ScrollView - iOS 18.x"*. Subject is iOS **18.x**, VoiceOver (not Voice Control), `ScrollView` (not `UIHostingController.accessibilityElements`).
- **#259** (opened 2025-09-05, still Open, no comments): *"SwiftUI TextField and TextEditor do not record any accessibility elements"*. No iOS version mentioned, no `UIHostingController.accessibilityElements` mention, no Voice Control mention.

Both issues are thematically adjacent (AccessibilitySnapshot does use `UIHostingController` internally) but **neither documents what the retrospective claimed they documented**. The underlying iOS 26 observation may still be true — Peach observed it empirically — but the citation does not substantiate it.

**This is itself an instance of the churning-without-progress class:** an architect framing produced a citation that was incorporated into the record without verifying the cited source's title and content matched the claim.

Recommended actions:
- Annotate `docs/implementation-artifacts/epic-85-retro-2026-06-07.md` and the 85.6 spec to record the misattribution.
- Add a memory entry tightening the citation rule: *cited issues must literally mention the platform version and API being claimed; if they don't, find a source that does or note the claim as unverified.*

_Sources: [AccessibilitySnapshot #245](https://github.com/cashapp/AccessibilitySnapshot/issues/245), [#259](https://github.com/cashapp/AccessibilitySnapshot/issues/259)._

### 2.4 Test/build infrastructure — XcodeBuildMCP evolved; phantom 0/0 unsolved

**`XcodeBuildMCP` (getsentry/XcodeBuildMCP, ~5.9k stars)** is the only test-infrastructure MCP server materially evolved in the delta window. Now maintained by **Sentry** (not a solo developer). Five releases in five weeks: v2.5.1 (May 8), v2.5.2 (May 12), v2.6.0 (Jun 1), v2.6.1 (Jun 2), v2.6.2 (Jun 2).

**v2.5.0 default xcresult bundles** — CHANGELOG verbatim:
> *"Added default result bundles for simulator, device, macOS, and Swift Package test runs, so agents can inspect detailed test artifacts without manually choosing a result bundle path."*

Directly relevant to Epic 85's **0.000s process-crash failures** that required `DiagnosticReports/*.ips` triage. Default xcresult capture gives the agent an inspectable artifact for every test run.

**Refuted claim — important not to act on:** a candidate finding that v2.5.0 introduced *per-workspace isolated DerivedData* failed adversarial review (vote 0-3). It is **not** confirmed by the changelog. The phantom-0/0-failure root cause on parallel `bin/test.sh` iOS + macOS runs remains the shared DerivedData lock observed empirically — XcodeBuildMCP does not address it. Memory `feedback_test_sh_no_parallel.md` stays load-bearing.

`ios-debugger-agent` (Dimillian) is the existing skill that consumes XcodeBuildMCP; the v2.5+ artifacts become available to it automatically once the MCP server is updated.

_Sources: [XcodeBuildMCP repo](https://github.com/getsentry/XcodeBuildMCP), [CHANGELOG](https://github.com/getsentry/XcodeBuildMCP/blob/main/CHANGELOG.md)._

## 3. Audio/MIDI ecosystem gap — re-check

**Gap persists.** Confirmed across `VoltAgent/awesome-agent-skills`, `dpearson2699/swift-ios-skills`, `vabole/apple-skills`, `netresearch/claude-code-marketplace`, `claudemarketplaces.com`, and `jeremylongshore/claude-code-plugins-plus-skills`. None contain AVAudioEngine, AVAudioSession, CoreMIDI, sampler-control-plane, AUv3, or RT-audio buffer-fill skills.

This was the principal finding of 2026-03-27 and it has not moved. The custom project-local `audio-programming` skill remains Peach's only coverage; the music-domain expert BMad agent remains the only theory-side coverage.

## 4. Anti-patterns — false-positive recommendations to refuse

Three repos surface in skill-discovery searches but failed adversarial verification. Do **not** install:

| Repo | Claim that failed | Vote |
|---|---|---|
| `th3vib3coder/vibe-science` | Marketed as a "falsification-first, not production-first" plugin with an adversarial "Reviewer 2" — the falsification-first labeling did not hold up under verification (the structural quality-gate enforcement claim survived 2-1, but the philosophical framing did not) | 0-3 on the marketing claim |
| `dpearson2699/swift-ios-skills` | Claimed as an actively-maintained iOS 26 alternative to Hudson / Dimillian — relevance to Peach's domains not substantiated; no Voice Control, audio, falsification-first, or xcresult skills inside | 1-2 |
| `jeremylongshore/claude-code-plugins-plus-skills` | "425+ plugins, 2,810 skills, 2.4k stars" — the scale claim was refuted | 0-3 |

`mcpmarket` Audio Producer Agent, `tubone24/midi-agent-skill`, and `ctoth/claudio` (audio-adjacent but orthogonal) are also flagged for completeness — see §2.2.

## 5. Process-level recommendations (no new skills)

Four changes that do not require any new install:

### 5.1 Make `/code-review high` the default check before flipping any spec to `done`

The existing `verify-visual-features` and `verify-audio-features` memory rules already require Michael-side verification for visual/audio output. `/code-review high` adds Anthropic's first-party correctness sweep on top — it covers the same territory as the BMad review skills but is a single command and works on the current diff.

### 5.2 Add `claude ultrareview` to release-readiness checks

Before tagging a release, run `claude ultrareview` (cloud fleet of bug-hunting agents) on the release branch. Complements the existing `/appstore-review` skill (HIG / submission-guidelines audit), which addresses a different surface.

### 5.3 Install `systematic-debugging`

As described in §2.1, this gives the existing churning-without-progress memory entries a discoverable, description-triggered surface. Useful even if the memory entries already fire — the skill provides scaffolding (questions to answer, structure of the investigation) that the bare rule does not.

### 5.4 Implement the patch-count circuit breaker as a Stop hook

The v2.1.163 `hookSpecificOutput.additionalContext` API is the right place to mechanise `feedback_patch_count_circuit_breaker`. Sketch:

```jsonc
// .claude/settings.json hooks.SubagentStop / hooks.Stop entry
// Reads recent git log, counts consecutive "fix story X" commits,
// injects "next commit must be diagnostic" via additionalContext if ≥2.
// Non-blocking: the session continues, the agent sees the reminder.
```

This converts the rule from "agent must remember to fire it" to "harness fires it deterministically." The memory entry stays as the explanation of *why*; the hook is the *enforcement*.

### 5.5 Tighten the citation rule

Add a memory entry: *when citing an external issue, blog post, or doc as evidence for a claim, the cited source's title or body must literally mention the platform version, API name, or behavior being claimed. If it doesn't, find a source that does, or label the claim as unverified.* The 85.6 AccessibilitySnapshot misattribution would have been caught by this rule.

## 6. Open questions (deferred — not blocking the recommendations above)

1. **Sub-agent nesting quality at depth 3–4.** The 7× token compounding is the visible cost; the qualitative degradation is not measured.
2. **A worked Stop-hook example for the patch-count circuit breaker.** The API primitive (v2.1.163) is documented; a community recipe is not. Peach would need to author this.
3. **DerivedData lock mechanism on parallel `bin/test.sh` runs.** Not solved by tooling in the delta window. Memory `feedback_test_sh_no_parallel` remains the only mitigation.
4. **Peach's iOS 26 `UIHostingController.accessibilityElements` empirical observation.** Real but uncited — Apple Developer Forums and HWS-style blogs were not searched in this delta window. Worth a targeted single-angle probe before relying on the framing again.

---

**Delta Completion Date:** 2026-06-11
**Methodology:** 5-angle deep-research workflow; 105 sub-agents; 25 claims adversarially verified (14 confirmed, 11 refuted)
**Confidence:** HIGH on Anthropic primitives (primary docs), HIGH on `systematic-debugging` and XcodeBuildMCP evolution (primary repo evidence), HIGH on audio/MIDI gap (multi-registry negative confirmation), MEDIUM on completeness of Voice Control negative finding (registries searched but ecosystem is fragmented).

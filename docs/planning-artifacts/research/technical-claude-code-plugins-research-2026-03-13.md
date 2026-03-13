---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments: []
workflowType: 'research'
lastStep: 1
research_type: 'technical'
research_topic: 'Claude Code plugins and extensions for iOS/Swift/SwiftUI platform knowledge'
research_goals: 'Find reputable plugins, MCP servers, and skills that provide up-to-date platform knowledge (iOS, Swift, SwiftUI, SwiftData) to reduce implementation errors caused by outdated or incorrect API usage'
user_name: 'Michael'
date: '2026-03-13'
web_research_enabled: true
source_verification: true
---

# Research Report: technical

**Date:** 2026-03-13
**Author:** Michael
**Research Type:** technical

---

## Research Overview

This research investigates Claude Code custom skills (Agent Skills) that can provide up-to-date Apple platform knowledge for Peach, an iOS ear training app built with Swift 6.2, SwiftUI, SwiftData, and Swift Testing targeting iOS 26. The project has repeatedly encountered implementation errors caused by Claude's training data lacking current platform APIs -- using deprecated patterns like `ObservableObject`, `XCTest`, or `@EnvironmentObject` instead of their modern replacements.

The research identified a mature Agent Skills ecosystem with two highly reputable skill authors -- Paul Hudson (Hacking with Swift) and Antoine van der Lee (SwiftLee) -- who maintain actively updated skills covering SwiftUI, Swift Concurrency (Swift 6.2 ready), SwiftData, and Swift Testing. A recommended set of 4 skills from these authors maps directly to Peach's documented pain points and can be installed at the project level in 15 minutes with zero changes to the existing CLAUDE.md or project-context.md.

See the full executive summary and recommendations in the Research Synthesis section below.

---

## Technical Research Scope Confirmation

**Research Topic:** Claude Code custom skills for iOS/Swift/SwiftUI platform knowledge
**Research Goals:** Find reputable custom skills that provide up-to-date platform knowledge (iOS 26, Swift 6.2, SwiftUI, SwiftData, Swift Testing) to reduce implementation errors caused by outdated or incorrect API usage

**Refined Scope (per user direction):**

- Focus exclusively on **custom skills** (slash commands / skill files)
- NOT MCP servers, NOT tool integrations
- Skills from reputable sources (Anthropic, established community contributors)

**Technical Research Scope:**

- Custom skill architecture -- how Claude Code skills work and where they come from
- Available skills -- reputable skills providing Apple platform documentation and Swift/SwiftUI patterns
- Quality & freshness -- how skills maintain current knowledge for cutting-edge APIs
- Fit for Peach -- which skills address the specific error patterns in project-context.md

**Research Methodology:**

- Current web data with rigorous source verification
- Multi-source validation for critical technical claims
- Confidence level framework for uncertain information
- Focus on practical applicability to iOS/Swift development

**Scope Confirmed:** 2026-03-13

## Technology Stack Analysis

### How Claude Code Custom Skills Work

Agent Skills are an open standard (spec published at [anthropics/skills](https://github.com/anthropics/skills)) adopted by Claude Code, OpenAI Codex CLI, Gemini, Cursor, and others. Each skill is a folder containing a `SKILL.md` file with YAML frontmatter (name, description, triggers) and markdown instructions. Skills use **progressive disclosure** -- they load context incrementally so Claude only reads what it needs, keeping the context window efficient.

**Installation methods:**
- `npx skills add <repo-url> --skill <skill-name>` -- interactive CLI by Vercel
- `git clone` into `~/.claude/skills/` (global) or `.claude/skills/` (project-level)
- Skills are auto-discovered by Claude Code and activated when relevant to the current task

_Source: [Anthropic Skills Spec](https://github.com/anthropics/skills/blob/main/spec/agent-skills-spec.md), [Vercel Skills CLI](https://github.com/vercel-labs/skills)_

### Skill Registries and Discovery

| Registry | Description |
|----------|-------------|
| [anthropics/skills](https://github.com/anthropics/skills) | Official Anthropic repository (~73k stars). Reference implementation + usable catalog |
| [SkillsMP](https://skillsmp.com) | Community marketplace aggregating 96k+ skills from GitHub |
| [twostraws/swift-agent-skills](https://github.com/twostraws/swift-agent-skills) | Curated directory of Apple platform skills by Paul Hudson |
| [OneSkill](https://oneskill.dev/) | Indexed from GitHub, installable in one command |
| [awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) | Community-curated list of skills and resources |

_Source: [SkillsMP](https://skillsmp.com), [OneSkill](https://oneskill.dev/)_

### Reputable Apple Platform Skills -- Detailed Analysis

#### Tier 1: Highly Reputable Authors (Established Apple Community Figures)

**Paul Hudson (twostraws) -- Hacking with Swift**

Paul Hudson is one of the most recognized Swift educators, author of hackingwithswift.com. He maintains a suite of four specialized agent skills:

| Skill | Install Command | Coverage |
|-------|----------------|----------|
| **SwiftUI Pro** | `npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro` | Navigation, layout, animations, state management, VoiceOver/accessibility, deprecated API avoidance, performance pitfalls. Targets mistakes LLMs actually make |
| **Swift Concurrency Pro** | `npx skills add https://github.com/twostraws/swift-concurrency-agent-skill --skill swift-concurrency-pro` | async/await, actors, tasks, Sendable, isolation |
| **SwiftData Pro** | `npx skills add https://github.com/twostraws/swiftdata-agent-skill --skill swiftdata-pro` | @Model, @Query, predicates, indexes, migrations, relationships, iCloud sync. Targets common LLM mistakes |
| **Swift Testing Pro** | `npx skills add https://github.com/twostraws/swift-testing-agent-skill --skill swift-testing-pro` | Modern Swift Testing framework (@Test, @Suite, #expect) |

_Confidence: HIGH. Paul Hudson's reputation in the Swift community is unimpeachable. Skills target the exact iOS 26 / Swift 6.2 era._
_Source: [Hacking with Swift article](https://www.hackingwithswift.com/articles/282/swiftui-agent-skill-claude-codex-ai), [swift-agent-skills directory](https://github.com/twostraws/swift-agent-skills)_

**Antoine van der Lee (AvdLee) -- SwiftLee**

Antoine van der Lee is a well-known Swift blogger (swiftlee.com), iOS developer, and Swift Concurrency course author. His skill suite:

| Skill | Repo | Coverage |
|-------|------|----------|
| **SwiftUI Expert** | [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill) | State management, view composition, Swift Charts, macOS multi-window, animations, iOS 26+ Liquid Glass |
| **Swift Concurrency** | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) | **Swift 6.2 ready**. @MainActor, custom actors, nonisolated, Sendable conformance, data race prevention, Swift 6 migration |
| **Swift Testing** | [AvdLee/Swift-Testing-Agent-Skill](https://github.com/AvdLee/Swift-Testing-Agent-Skill) | XCTest migration, @Test/@Suite, parameterized tests, traits/tags, async testing, parallel execution |
| **Core Data** | [AvdLee/Core-Data-Agent-Skill](https://github.com/AvdLee/Core-Data-Agent-Skill) | Core Data modeling, fetch requests, performance (less relevant for Peach which uses SwiftData) |

_Confidence: HIGH. Antoine is a recognized Swift authority. His Swift Concurrency skill explicitly advertises Swift 6.2 readiness._
_Source: [SwiftLee blog](https://www.avanderlee.com/ai-development/swiftui-agent-skill-build-better-views-with-ai/), [GitHub repos](https://github.com/AvdLee)_

#### Tier 2: Useful Supplementary Skills

**iOS Simulator Skill (conorluddy)**

| Skill | Repo | Coverage |
|-------|------|----------|
| **iOS Simulator** | [conorluddy/ios-simulator-skill](https://github.com/conorluddy/ios-simulator-skill) | 21 production-ready scripts for building, launching, and interacting with iOS apps in the Simulator. Semantic navigation via accessibility APIs. Screen mapping, element tapping, text entry |

_Confidence: MEDIUM. Less about platform knowledge, more about workflow automation. Could help Claude verify UI behavior._
_Source: [GitHub](https://github.com/conorluddy/ios-simulator-skill)_

**Apple Skills Collection (rshankras)**

| Skill | Repo | Coverage |
|-------|------|----------|
| **claude-code-apple-skills** | [rshankras/claude-code-apple-skills](https://github.com/rshankras/claude-code-apple-skills) | 52 code generators, code review, UI review, HIG compliance, accessibility audits, app planning, iPad patterns, migration guides |

_Confidence: MEDIUM. Broad coverage but author is less established than Hudson/van der Lee. Quality of individual skills varies._
_Source: [GitHub](https://github.com/rshankras/claude-code-apple-skills)_

### Fit Assessment for Peach

Mapping Peach's documented pain points (from `project-context.md`) to available skills:

| Peach Pain Point | Relevant Skill(s) | Coverage Quality |
|------------------|--------------------|-----------------|
| Using `ObservableObject`/`@Published` instead of `@Observable` | twostraws SwiftUI Pro, AvdLee SwiftUI Expert | Strong -- both explicitly target deprecated patterns |
| Using `XCTest` instead of Swift Testing | twostraws Swift Testing Pro, AvdLee Swift Testing | Strong -- both cover migration from XCTest |
| Swift 6 concurrency errors (`@MainActor`, `Sendable`, `nonisolated`) | AvdLee Swift Concurrency (**Swift 6.2 ready**), twostraws Swift Concurrency Pro | Strong -- AvdLee explicitly covers default MainActor isolation |
| SwiftData misuse (direct ModelContext) | twostraws SwiftData Pro | Strong -- covers @Model, @Query, common mistakes |
| Using deprecated SwiftUI APIs | twostraws SwiftUI Pro, AvdLee SwiftUI Expert | Strong -- both target deprecated API avoidance |
| `@EnvironmentObject` instead of `@Environment` with `@Entry` | twostraws SwiftUI Pro, AvdLee SwiftUI Expert | Likely covered (modern state management patterns) |
| Combine usage (`PassthroughSubject`, `sink`) | AvdLee Swift Concurrency, twostraws Swift Concurrency Pro | Covered via async/await-first guidance |

### Technology Adoption Recommendations

**Recommended Installation (4 skills covering all Peach pain points):**

```bash
# SwiftUI -- modern patterns, deprecated API avoidance
npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro

# Swift Concurrency -- Swift 6.2 ready, MainActor, Sendable
npx skills add https://github.com/AvdLee/Swift-Concurrency-Agent-Skill --skill swift-concurrency

# SwiftData -- @Model, @Query, persistence patterns
npx skills add https://github.com/twostraws/swiftdata-agent-skill --skill swiftdata-pro

# Swift Testing -- @Test, @Suite, #expect, XCTest migration
npx skills add https://github.com/twostraws/swift-testing-agent-skill --skill swift-testing-pro
```

**Rationale for mixing authors:**
- SwiftUI: Both Hudson and van der Lee are excellent; Hudson's explicitly targets "mistakes LLMs actually make"
- Concurrency: van der Lee's explicitly advertises **Swift 6.2 readiness** -- critical for Peach's default MainActor isolation
- SwiftData: Only Hudson has a dedicated SwiftData skill
- Testing: Both are strong; Hudson's complements his other skills

**Optional additions:**
- AvdLee SwiftUI Expert -- if you want a second perspective on SwiftUI (some coverage overlap with Hudson's)
- iOS Simulator Skill -- if you want Claude to be able to build/run/interact with the app in the simulator

_Sources: All GitHub repositories linked above_

## Integration Patterns Analysis

### How Skills Integrate with Claude Code

**Loading mechanism (progressive disclosure):**

1. **Startup (~100 tokens per skill):** Claude loads only YAML frontmatter (name + description) from each installed SKILL.md. Many skills can be installed with negligible context cost.
2. **Activation:** When a task matches a skill's description, Claude reads the full SKILL.md body (recommended < 500 lines).
3. **On-demand resources:** Additional files (`/scripts`, `/references`, `/assets`) are read only when needed. No context penalty for unused bundled content.

This means installing all 4 recommended skills costs only ~400 tokens at startup. Full instructions load only when relevant.

_Source: [Claude Code Skills Docs](https://code.claude.com/docs/en/skills), [Anthropic Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)_

### Skills vs. CLAUDE.md: Coexistence and Priority

| Mechanism | Purpose | When Loaded | Priority |
|-----------|---------|-------------|----------|
| `CLAUDE.md` (project root) | Project-specific conventions, always-on rules | Every conversation, always | Highest -- persistent project truth |
| `~/.claude/CLAUDE.md` | Personal global defaults | Every conversation, always | Below project CLAUDE.md |
| Agent Skills | Modular, reusable domain knowledge | On-demand when task matches | Supplements CLAUDE.md; CLAUDE.md wins on conflicts |

**Key insight for Peach:** Your `project-context.md` (loaded via CLAUDE.md) already contains Peach-specific rules (e.g., "never use `@EnvironmentObject`", "TrainingDataStore is the sole data accessor"). Agent skills provide _general_ best practices for SwiftUI/Concurrency/etc. When they conflict, CLAUDE.md project instructions take priority, which is the correct behavior -- your project-specific rules are more precise than generic best practices.

_Source: [Claude Code Skills Docs](https://code.claude.com/docs/en/skills), [alexop.dev customization guide](https://alexop.dev/posts/claude-code-customization-guide-claudemd-skills-subagents/)_

### Skill Priority and Namespace Rules

When skills share the same name across installation levels:

| Level | Location | Priority |
|-------|----------|----------|
| Enterprise | Managed configuration | Highest |
| Personal | `~/.claude/skills/` | Medium |
| Project | `.claude/skills/` | Lowest |

Plugin skills use a `plugin-name:skill-name` namespace, preventing name collisions across sources.

_Source: [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)_

### Managing Overlap Between Skills

**Potential conflicts in the recommended set:**

The 4 recommended skills (SwiftUI Pro, Swift Concurrency, SwiftData Pro, Swift Testing Pro) are from different domains and should not conflict. However, if you also install AvdLee's SwiftUI Expert alongside Hudson's SwiftUI Pro, you'd have two skills triggered by SwiftUI-related tasks. Observed issues with overlapping skills:

- **Quality degradation:** When multiple skills match the same task, Claude tries to reconcile potentially conflicting instructions, which can reduce output quality.
- **Mitigation:** Choose one author per domain. The recommended set already follows this principle (Hudson for SwiftUI/SwiftData/Testing, van der Lee for Concurrency).

If you ever want to experiment with both SwiftUI skills, install one at project level and one at personal level. The project-level skill will take priority for this project.

_Source: [Claude Agent Skills Deep Dive](https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/), [Composio Top Skills](https://composio.dev/content/top-claude-skills)_

### Integration with Peach's Existing CLAUDE.md

Peach's `CLAUDE.md` already instructs Claude to read `docs/project-context.md` which contains 85 rules. The agent skills complement this in a layered fashion:

```
┌─────────────────────────────────────────────┐
│  project-context.md (85 Peach-specific rules)│  ← Highest priority, always loaded
│  "never use ObservableObject"                │
│  "TrainingDataStore is sole data accessor"   │
├─────────────────────────────────────────────┤
│  Agent Skills (loaded on-demand)             │  ← General best practices
│  SwiftUI Pro: "use @Observable not           │
│    ObservableObject" (reinforces ↑)          │
│  Swift Concurrency: "Swift 6.2 default       │
│    MainActor isolation" (supplements ↑)      │
├─────────────────────────────────────────────┤
│  Claude's training data                      │  ← Lowest priority, may be outdated
│  (knowledge cutoff May 2025)                 │
└─────────────────────────────────────────────┘
```

The skills act as a **middle layer** -- they reinforce project-context.md rules where they overlap, and fill knowledge gaps (e.g., specific SwiftData migration patterns, parameterized testing syntax) where project-context.md is silent.

_Source: Analysis based on [Claude Code docs](https://code.claude.com/docs/en/skills) and Peach project structure_

### Installation Strategy: Project vs. Global

| Strategy | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **Project-level** (`.claude/skills/`) | Committed to repo; anyone cloning gets them; consistent across sessions | Only available in this project | **Recommended for all 4 skills** -- ensures reproducible development environment |
| **Personal/global** (`~/.claude/skills/`) | Available across all projects | Not shared with collaborators; requires manual setup | Only for skills you want across all your projects but not shared |

_Source: [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)_

## Architectural Patterns and Design

### Skill Internal Architecture

Well-designed skills follow a three-tier structure with progressive disclosure:

```
swiftui-pro/
├── SKILL.md              # < 500 lines, < 5000 tokens. Core rules only
├── references/           # Detailed patterns, loaded on-demand
│   ├── navigation.md     # NavigationStack, NavigationSplitView patterns
│   ├── state.md          # @Observable, @Environment, @State rules
│   ├── deprecated.md     # API deprecation warnings
│   └── performance.md    # Common performance pitfalls
├── scripts/              # Executable code (not read into context)
└── assets/               # Templates, examples
```

**Design principles for effective skills:**
- SKILL.md references other files; the agent reads only the relevant reference file
- Scripts execute without being read into context (zero token cost)
- "Don't repeat things LLMs already know -- it burns tokens for no benefit"
- Each reference file covers one specific topic for precise context loading

_Source: [Anthropic Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), [SKILL.md Pattern article](https://bibek-poudel.medium.com/the-skill-md-pattern-how-to-write-ai-agent-skills-that-actually-work-72a3169dd7ee)_

### Evaluating Skill Quality

**Criteria for assessing a skill before installing it:**

| Criterion | What to Check | Red Flags |
|-----------|---------------|-----------|
| **Author reputation** | Known in the domain? Active maintainer? | Anonymous, no other projects |
| **Recency** | Last commit date, references to current APIs | No updates in 6+ months; references to deprecated APIs |
| **Token efficiency** | SKILL.md line count, progressive disclosure usage | Monolithic SKILL.md > 1000 lines, no reference files |
| **Specificity** | Targets LLM-specific mistakes, not generic advice | Reads like a tutorial rather than agent instructions |
| **Compatibility** | Uses standard Agent Skills spec | Non-standard format, custom installation |

**Measurement approach:** Anthropic recommends measuring response latency and output quality with and without each skill active. If a skill adds significant tokens but doesn't meaningfully change behavior, trim or remove it.

_Source: [Anthropic blog on skill evaluation](https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills), [Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)_

### Maintenance and Freshness Concerns

**The core risk:** Skills are static markdown files. When Apple releases new APIs (e.g., iOS 27, Swift 7), skills must be manually updated by their authors. A stale skill can actively harm code quality by reinforcing patterns that have been superseded.

**Mitigation strategies:**

1. **Choose actively maintained skills** -- Both Hudson and van der Lee are professional iOS educators with financial incentive to stay current. Hudson's SwiftUI-Agent-Skill had activity as recently as March 7, 2026 (Xcode integration issue). Van der Lee's Swift Concurrency skill explicitly advertises Swift 6.2 readiness.

2. **Pin to known-good versions** -- Use git submodules or specific commit hashes rather than always pulling latest, to avoid surprise changes mid-project.

3. **Periodic review** -- After each WWDC / major Swift release, check if skills have been updated. If not, the project-context.md rules still serve as the primary guardrail.

4. **Complement with project-context.md** -- Skills provide breadth; project-context.md provides depth and project-specific precision. Even if a skill becomes stale, project-context.md catches the critical rules.

_Confidence: MEDIUM. No formal maintenance SLAs exist for community skills. The reputation of Hudson and van der Lee is the strongest signal of continued maintenance._

_Source: [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill), [AvdLee blog](https://www.avanderlee.com/ai-development/agent-skills-replacing-agents-md-with-reusable-ai-knowledge/)_

### Writing Custom Skills vs. Using Third-Party Skills

Peach already has a detailed `project-context.md` with 85 rules. Should you also write a custom Peach-specific skill?

| Approach | When to Use | For Peach |
|----------|-------------|-----------|
| **Third-party skills** | General platform knowledge (SwiftUI patterns, concurrency rules, testing APIs) | Yes -- fills knowledge gaps Claude's training data misses |
| **project-context.md** | Project-specific architecture, naming conventions, domain rules | Already in place -- 85 rules, well-maintained |
| **Custom SKILL.md** | Reusable workflows that span projects (e.g., "review code for Swift 6 compliance") | Not needed currently -- project-context.md covers Peach's needs |

**Verdict:** For Peach, the combination of third-party skills (general platform knowledge) + project-context.md (Peach-specific rules) is the right architecture. A custom skill would only make sense if you wanted to share Peach's patterns across multiple projects.

_Source: [Agent Skills spec](https://agentskills.io/specification), [Hacking with Swift](https://www.hackingwithswift.com/articles/282/swiftui-agent-skill-claude-codex-ai)_

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Skill contradicts project-context.md | Low | Low | CLAUDE.md takes priority; contradictions are overridden |
| Skill becomes stale after WWDC | Medium | Medium | Monitor skill repos post-WWDC; project-context.md remains authoritative |
| Skill adds noisy/wrong guidance | Low | Medium | Audit SKILL.md before installing; measure output quality |
| Too many skills degrade overall quality | Low | High | Stick to 4-5 focused skills; avoid overlapping domains |
| Token budget exhaustion on complex tasks | Low | Medium | Progressive disclosure limits cost; skills load only when needed |

## Implementation Approaches and Technology Adoption

### Step-by-Step Adoption Plan

**Phase 1: Install recommended skills (15 minutes)**

```bash
# Install all 4 skills at project level (.claude/skills/)
# Project level recommended because: anyone cloning the repo
# gets the skills automatically -- no manual setup needed

npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro -a claude-code -y
npx skills add https://github.com/AvdLee/Swift-Concurrency-Agent-Skill --skill swift-concurrency -a claude-code -y
npx skills add https://github.com/twostraws/swiftdata-agent-skill --skill swiftdata-pro -a claude-code -y
npx skills add https://github.com/twostraws/swift-testing-agent-skill --skill swift-testing-pro -a claude-code -y
```

Flags: `-a claude-code` targets Claude Code specifically, `-y` skips confirmation prompts. Omitting `-g` installs at project level (`.claude/skills/`).

**Phase 2: Verify installation (5 minutes)**

```bash
# List installed skills
npx skills list -a claude-code

# Verify skills are discoverable
# Start Claude Code and type: "What skills do you have available?"
```

**Phase 3: Validate with a test task (30 minutes)**

Run a controlled test to verify skills are working:
1. Ask Claude to write a new SwiftUI view using `@Observable` -- verify it doesn't suggest `ObservableObject`
2. Ask Claude to write a Swift Testing test -- verify it uses `@Test`/`#expect`, not `XCTest`
3. Ask Claude to explain Swift 6.2 default MainActor isolation -- verify it knows about `SWIFT_DEFAULT_ACTOR_ISOLATION`
4. Ask Claude to create a SwiftData query -- verify it uses `@Query` correctly

_Source: [Vercel Skills CLI](https://github.com/vercel-labs/skills), [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)_

### Peach-Specific Considerations

**Current Peach `.claude/` structure:**
```
.claude/
├── commands/           # Existing slash commands
├── settings.local.json # Local settings (gitignored)
└── skills/             # ← Skills will be installed here
```

Skills installed at the project level (`.claude/skills/`) should be committed to the repository so that anyone cloning the repo gets them automatically.

**Interaction with existing CLAUDE.md:**
Peach's CLAUDE.md directs Claude to read `docs/project-context.md` before any implementation. Skills supplement this -- they don't replace it. The flow becomes:

1. Claude reads CLAUDE.md (always) → loads project-context.md (always)
2. Claude detects task involves SwiftUI → loads SwiftUI Pro skill (on-demand)
3. If project-context.md and skill conflict → project-context.md wins

No changes to CLAUDE.md or project-context.md are needed.

### Verification Workflow

After installing skills, use this checklist for the first few development sessions:

| Check | How | Expected Result |
|-------|-----|-----------------|
| Skill discovery | Ask "What skills are available?" | Lists all 4 installed skills |
| SwiftUI correctness | Implement a new view | Uses `@Observable`, `@Environment` with `@Entry`, no deprecated APIs |
| Concurrency correctness | Add async code | No redundant `@MainActor`, correct `nonisolated` usage, proper `Sendable` |
| SwiftData correctness | Add a query | Uses `@Query`, goes through `TrainingDataStore` pattern |
| Testing correctness | Write a test | Uses `@Test`, `@Suite`, `#expect`, async test functions |
| No conflicts | Watch for contradictory suggestions | Skills reinforce, not contradict, project-context.md rules |

### Success Metrics

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Deprecated API usage** | Count of `ObservableObject`, `@EnvironmentObject`, `XCTest` in generated code | Zero |
| **Concurrency errors** | Compiler errors related to `Sendable`, `@MainActor`, isolation | Reduced vs. baseline |
| **project-context.md violations** | Manual review of generated code against "Never Do This" list | Zero |
| **Token overhead** | Compare session token usage with/without skills | < 10% increase for typical tasks |
| **Development velocity** | Time to implement a story without needing to correct platform mistakes | Measurable improvement |

### Maintenance Calendar

| Event | Action | Frequency |
|-------|--------|-----------|
| **Post-WWDC** (June yearly) | Check all 4 skill repos for updates; update if available | Annual |
| **Swift release** | Verify Swift Concurrency skill covers new version | Per release |
| **Xcode release** | Verify SwiftUI skill covers new iOS APIs | Per release |
| **Quarterly review** | Run validation checklist; remove skills that don't add value | Quarterly |
| **Skill update available** | Review changelog; update if compatible with project-context.md | As needed |

## Technical Research Recommendations

### Implementation Roadmap

1. **Immediate (today):** Install the 4 recommended skills using the Phase 1 commands above
2. **This week:** Run Phase 3 validation with a real Peach development task
3. **Ongoing:** Monitor for conflicts between skills and project-context.md during normal development
4. **Post-WWDC 2026:** Review and update skills for iOS 27 / Swift 7 compatibility

### Final Skill Selection Summary

| Skill | Author | Domain | Why This One |
|-------|--------|--------|-------------|
| **SwiftUI Pro** | Paul Hudson | SwiftUI views, state, navigation | Explicitly targets LLM mistakes; most recognized Swift educator |
| **Swift Concurrency** | Antoine van der Lee | async/await, actors, Sendable | **Swift 6.2 ready**; covers default MainActor isolation critical to Peach |
| **SwiftData Pro** | Paul Hudson | @Model, @Query, persistence | Only reputable SwiftData skill available; targets LLM mistakes |
| **Swift Testing Pro** | Paul Hudson | @Test, @Suite, #expect | Prevents XCTest regression; covers modern testing patterns |

### What These Skills Will NOT Solve

Skills address _platform knowledge_ gaps but not _project architecture_ gaps. The following Peach-specific patterns must continue to be enforced by project-context.md:

- TrainingDataStore as sole data accessor (domain architecture)
- PitchComparisonSession state machine guards (domain logic)
- Observer pattern with injected observer arrays (project pattern)
- Two-world architecture (logical/physical bridge) (domain design)
- File placement decision tree (project convention)
- Domain types at interfaces (Cents, Frequency, etc.) (project convention)

---

## Research Synthesis

### Executive Summary

Peach's development has been hampered by Claude Code's training data knowledge cutoff (May 2025), which causes it to generate code using deprecated Swift and SwiftUI patterns. The Agent Skills ecosystem -- an open standard adopted by Claude Code, Codex, Cursor, and others -- provides a lightweight, zero-configuration solution: curated markdown instruction sets that load on-demand to correct Claude's platform knowledge.

**Four skills from two highly reputable Apple community authors solve the problem:**

| # | Skill | Author | Peach Impact |
|---|-------|--------|-------------|
| 1 | **SwiftUI Pro** | Paul Hudson (Hacking with Swift) | Eliminates `ObservableObject`, `@EnvironmentObject`, deprecated API usage |
| 2 | **Swift Concurrency** | Antoine van der Lee (SwiftLee) | Swift 6.2 ready -- correct `@MainActor`, `Sendable`, `nonisolated` patterns |
| 3 | **SwiftData Pro** | Paul Hudson | Correct `@Model`, `@Query` usage; prevents direct `ModelContext` access |
| 4 | **Swift Testing Pro** | Paul Hudson | Enforces `@Test`/`@Suite`/`#expect`; prevents XCTest regression |

**Key properties of this solution:**
- **~400 tokens startup cost** for all 4 skills (progressive disclosure architecture)
- **Zero changes** to CLAUDE.md or project-context.md required
- **Project-level installation** -- committed to repo, available to anyone cloning
- **CLAUDE.md wins on conflicts** -- Peach's 85 project-specific rules always take priority
- **15-minute adoption** -- install, verify, start benefiting immediately

### Strategic Assessment

The skills act as a **middle knowledge layer** between Peach's project-context.md (highest priority, project-specific) and Claude's training data (lowest priority, potentially outdated). This layered architecture is robust:

- If a skill becomes stale, project-context.md still enforces critical rules
- If a skill contradicts project-context.md, the project instructions win
- If a skill adds no value, it can be removed with no side effects

The main ongoing cost is **periodic review** after WWDC / major Swift releases to ensure skills remain current. Both authors are professional iOS educators with strong incentive to maintain their skills.

### Actionable Next Step

Run the 4 install commands from the Implementation Roadmap section above, then validate with a test implementation task.

---

**Technical Research Completion Date:** 2026-03-13
**Research Methodology:** Web search with source verification across Claude Code docs, GitHub repositories, author blogs, and community registries
**Source Verification:** All technical claims cited with current sources
**Confidence Level:** HIGH for skill selection; MEDIUM for long-term maintenance guarantees

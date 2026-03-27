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

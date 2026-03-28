# Peach - Claude Code Instructions

## Project Context

Before implementing any code, read `docs/project-context.md` for critical implementation rules, patterns, and conventions. All development workflow rules (git, testing, TDD, pre-commit gates) are defined there.


## Build and Test Scripts

Use these scripts instead of writing inline xcodebuild commands:

- `bin/test.sh` — Run tests and get a parsed summary. Use `-f` for failures only, `-s SuiteName` to filter. Do NOT pipe xcodebuild through grep or tail yourself.
- `bin/build.sh` — Build the project and get a formatted error/warning summary. Do NOT run raw xcodebuild build.
- `bin/add-localization.swift` — Add German translations. Single: `bin/add-localization.swift "Key" "German"`. Batch: `--batch file.json`. Check existing: `--list`, `--missing`.

**Both iOS and macOS must pass before committing.** Run `bin/test.sh && bin/test.sh -p mac` (or `bin/build.sh` / `bin/build.sh -p mac` for build-only checks).

If a script's output doesn't contain what you need, use the `-r` (raw) flag as a fallback. Do not reinvent the parsing.


## Skills

Invoke the relevant installed skills proactively as part of your workflow. Do not wait for the user to invoke these — if the task touches a skill's domain, use it.

### Core (use during any implementation work)

- `/swiftui-pro` — When working with SwiftUI views or modifiers
- `/swiftdata-pro` — When working with SwiftData models or queries
- `/swift-concurrency` — When working with async/await, actors, or Sendable types
- `/swift-testing-pro` — When writing or reviewing tests

### SwiftUI Specialized (use alongside `/swiftui-pro` when relevant)

- `/swiftui-performance-audit` — When profiling or optimizing SwiftUI view invalidation and rendering
- `/swiftui-liquid-glass` — When implementing iOS 26 Liquid Glass UI effects
- `/swiftui-view-refactor` — When restructuring views into modular components with improved data flow
- `/swiftui-ui-patterns` — When building screens with navigation, state management, or reusable patterns

### Concurrency (complementary perspectives)

- `/swift-concurrency-expert` — Dimillian's Swift 6.2+ concurrency skill for actor isolation and data-race diagnostics
- `/avdlee-swift-concurrency` — Antoine van der Lee's concurrency skill with migration guides and common diagnostics table

### Accessibility

- `/ios-accessibility` — When building or reviewing UI for VoiceOver, Dynamic Type, Voice Control, Switch Control, or Full Keyboard Access

### Code Quality

- `/simplify-code` — After implementation, review diffs for reuse, quality, and efficiency
- `/orchestrate-batch-refactor` — When planning larger refactoring efforts across multiple files

### Debugging

- `/ios-debugger-agent` — When building, launching, and debugging on iOS Simulator with UI inspection

### Release

- `/appstore-review` — Before App Store submission, audit against Apple's Review Guidelines
- `/app-store-changelog` — Generate user-facing release notes from git history


## Code Audit Tools

- **Dead code analysis** — Use `LSP incomingCalls` on each method under review, not grep. Grep cannot distinguish callers from definitions, protocol declarations, and test-only usage. A method with no incoming calls outside its own file and tests is dead.


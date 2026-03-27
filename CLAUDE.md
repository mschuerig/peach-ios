# Peach - Claude Code Instructions

## Project Context

Before implementing any code, read `docs/project-context.md` for critical implementation rules, patterns, and conventions. All development workflow rules (git, testing, TDD, pre-commit gates) are defined there.


## Build and Test Scripts

Use these scripts instead of writing inline xcodebuild commands:

- `bin/test.sh` — Run tests and get a parsed summary. Use `-f` for failures only, `-s SuiteName` to filter. Do NOT pipe xcodebuild through grep or tail yourself.
- `bin/build.sh` — Build the project and get a formatted error/warning summary. Do NOT run raw xcodebuild build.
- `bin/add-localization.swift` — Add German translations. Single: `bin/add-localization.swift "Key" "German"`. Batch: `--batch file.json`. Check existing: `--list`, `--missing`.

If a script's output doesn't contain what you need, use the `-r` (raw) flag as a fallback. Do not reinvent the parsing.


## iOS Skills

When writing, reviewing, or modifying code, invoke the relevant installed skills as part of your workflow:

- `/swiftui-pro` — When working with SwiftUI views or modifiers
- `/swiftdata-pro` — When working with SwiftData models or queries
- `/swift-concurrency` — When working with async/await, actors, or Sendable types
- `/swift-testing-pro` — When writing or reviewing tests

Do not wait for the user to invoke these. If the task touches a skill's domain, use it proactively.


## Code Audit Tools

- **Dead code analysis** — Use `LSP incomingCalls` on each method under review, not grep. Grep cannot distinguish callers from definitions, protocol declarations, and test-only usage. A method with no incoming calls outside its own file and tests is dead.


# Peach - Claude Code Instructions

## Project Context

Before implementing any code, read `docs/project-context.md` for critical implementation rules, patterns, and conventions. All development workflow rules (git, testing, TDD, pre-commit gates) are defined there.


## Build and Test Scripts

Use these scripts instead of writing inline xcodebuild commands:

- `bin/test.sh` — Run tests and get a parsed summary. Use `-f` for failures only, `-s SuiteName` to filter. Do NOT pipe xcodebuild through grep or tail yourself.
- `bin/build.sh` — Build the project and get a formatted error/warning summary. Do NOT run raw xcodebuild build.
- `bin/add-localization.py` — Add German translations. Single: `bin/add-localization.py "Key" "German"`. Batch: `--batch file.json`. Check existing: `--list`, `--missing`.

If a script's output doesn't contain what you need, use the `-r` (raw) flag as a fallback. Do not reinvent the parsing.


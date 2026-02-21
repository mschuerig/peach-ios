# Peach - Claude Code Instructions

## Project Context

Before implementing any code, read `docs/project-context.md` for critical implementation rules, patterns, and conventions. All development workflow rules (git, testing, TDD, pre-commit gates) are defined there.

## Tool Scripts

When you need to run analysis, data processing, or evaluation code (e.g., parsing test output, computing statistics, visualizing results), **write it as a saved script file** rather than inline code in the chat. Place scripts in `tools/` at the project root.

- **Do NOT** write inline Python/Shell/Ruby/etc. snippets for direct execution in the shell
- **Do** create a named script file (e.g., `tools/analyze-convergence.py`), ask for a review, and only after approval execute it
- Scripts are reviewable once and reusable — inline code requires re-review every time
- Commit tool scripts alongside the work that introduced them

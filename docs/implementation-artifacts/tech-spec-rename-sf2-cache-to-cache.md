---
title: 'Rename .sf2-cache to .cache'
slug: 'rename-sf2-cache-to-cache'
created: '2026-03-02'
status: 'completed'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Shell script', 'Xcode project (pbxproj)', 'Markdown', 'gitignore']
files_to_modify: ['.gitignore:10', 'bin/download-sf2.sh:8,21', 'Peach.xcodeproj/project.pbxproj:27', 'README.md:44']
code_patterns: ['CACHE_DIR variable in download script centralizes path', 'PBXFileReference path attribute in pbxproj', 'gitignore comment + entry pattern']
test_patterns: ['No automated tests — infra/config change only']
---

# Tech-Spec: Rename .sf2-cache to .cache

**Created:** 2026-03-02

## Overview

### Problem Statement

The local cache directory `.sf2-cache` is named specifically for SoundFont files, but we want to use it as a general-purpose cache directory. The current name prevents intuitive reuse for other cached artifacts.

### Solution

Rename the `.sf2-cache/` directory to `.cache/` across all active configuration, build scripts, Xcode project references, and documentation. Flat layout — the SF2 file remains at the top level of `.cache/`.

### Scope

**In Scope:**
- `.gitignore` — update the ignore entry from `.sf2-cache/` to `.cache/`
- `bin/download-sf2.sh` — update `CACHE_DIR` variable and related references
- `Peach.xcodeproj/project.pbxproj` — update the PBXFileReference path
- `README.md` — update the documentation reference

**Out of Scope:**
- Historical docs (`docs/claude-audit/*`, `docs/implementation-artifacts/infra-sf2-build-download-cache.md`) — left as-is
- No subdirectory structure within `.cache/` — flat layout for now
- No new cache functionality — this is purely a rename

## Context for Development

### Codebase Patterns

- The cache directory is gitignored and populated by a manual developer step (`bin/download-sf2.sh`)
- The download script uses a single `CACHE_DIR` variable (line 21) — all derived paths (`CACHED_SF2`, `TEMP_FILE`) are built from it, so only one line needs changing in the script
- The Xcode project references the SF2 file via `path = ".sf2-cache/GeneralUser-GS.sf2"` in a PBXFileReference entry (line 27) — this is the only path-bearing reference; other lines just use the filename
- The `.gitignore` has both a comment (line 8) and the entry itself (line 10)
- `README.md` mentions `.sf2-cache/` once in the build instructions (line 44)

### Files to Reference

| File | Line(s) | What Changes |
| ---- | ------- | ------------ |
| `.gitignore` | 8, 10 | Comment: generalize from "SF2 SoundFont cache" to "Local cache"; entry: `.sf2-cache/` → `.cache/` |
| `bin/download-sf2.sh` | 8, 21 | Comment: `.sf2-cache/` → `.cache/`; `CACHE_DIR` value: `.sf2-cache` → `.cache` |
| `Peach.xcodeproj/project.pbxproj` | 27 | `path = ".sf2-cache/GeneralUser-GS.sf2"` → `path = ".cache/GeneralUser-GS.sf2"` |
| `README.md` | 44 | `.sf2-cache/` → `.cache/` |

### Technical Decisions

- **Flat layout chosen** — SF2 file stays at `.cache/GeneralUser-GS.sf2` (no subdirectories)
- **Historical docs untouched** — audit logs and the original infra spec reflect decisions at their time of writing
- **`.gitignore` comment generalized** — since the directory now serves a general purpose, the comment should reflect that
- **`*.sf2` glob stays** — the `*.sf2` gitignore pattern on line 9 is independent of the directory name and remains useful

## Implementation Plan

### Tasks

- [x] Task 1: Rename the physical directory
  - Action: `mv .sf2-cache .cache` in the project root
  - Notes: This must happen first — subsequent file edits reference the new path

- [x] Task 2: Update `.gitignore`
  - File: `.gitignore`
  - Action: Line 8 — change comment from `# SF2 SoundFont cache (downloaded manually via tools/download-sf2.sh)` to `# Local cache (not tracked in git)`
  - Action: Line 10 — change `.sf2-cache/` to `.cache/`
  - Notes: The `*.sf2` glob on line 9 stays as-is

- [x] Task 3: Update download script
  - File: `bin/download-sf2.sh`
  - Action: Line 8 — change comment path from `.sf2-cache/GeneralUser-GS.sf2` to `.cache/GeneralUser-GS.sf2`
  - Action: Line 21 — change `CACHE_DIR="${PROJECT_ROOT}/.sf2-cache"` to `CACHE_DIR="${PROJECT_ROOT}/.cache"`
  - Notes: All derived paths (`CACHED_SF2`, `TEMP_FILE`) are built from `CACHE_DIR`, so they update automatically

- [x] Task 4: Update Xcode project file
  - File: `Peach.xcodeproj/project.pbxproj`
  - Action: Line 27 — change `path = ".sf2-cache/GeneralUser-GS.sf2"` to `path = ".cache/GeneralUser-GS.sf2"`
  - Notes: Only this one PBXFileReference line contains the directory path; other SF2 references use just the filename

- [x] Task 5: Update README
  - File: `README.md`
  - Action: Line 44 — change `` `.sf2-cache/` `` to `` `.cache/` ``

- [x] Task 6: Verify build
  - Action: Run `bin/build.sh` to confirm the project builds with the new path
  - Notes: The Xcode build will fail if the PBXFileReference path doesn't match the actual file location

### Acceptance Criteria

- [x] AC 1: Given the project is freshly cloned, when a developer runs `bin/download-sf2.sh`, then the SF2 file is downloaded to `.cache/GeneralUser-GS.sf2`
- [x] AC 2: Given `.cache/GeneralUser-GS.sf2` exists, when the project is built with `bin/build.sh`, then the build succeeds without file-not-found errors
- [x] AC 3: Given the `.gitignore` is updated, when `git status` is run, then the `.cache/` directory does not appear as untracked
- [x] AC 4: Given the repository has no `.sf2-cache` directory, when searching all active files (excluding `docs/claude-audit/` and `docs/implementation-artifacts/infra-sf2-build-download-cache.md`), then zero references to `.sf2-cache` remain

## Additional Context

### Dependencies

None — this is a self-contained rename with no code logic changes.

### Testing Strategy

No automated tests needed — this is a configuration/infrastructure change.

**Manual verification:**
1. Run `bin/download-sf2.sh` — confirms script works with new `CACHE_DIR`
2. Run `bin/build.sh` — confirms Xcode finds the SF2 file at the new path
3. Run `grep -r "sf2-cache" . --include="*.sh" --include="*.md" --include="*.pbxproj" --include=".gitignore"` — confirms no stale references in active files

### Notes

- Developers with an existing `.sf2-cache/` directory will need to manually rename it to `.cache/` or re-run `bin/download-sf2.sh`
- The `*.sf2` gitignore glob (line 9) is independent of the directory and stays unchanged
- Future cached artifacts can be placed directly in `.cache/` without any further configuration changes

## Review Notes
- Adversarial review completed
- Findings: 9 total, 3 fixed, 6 skipped
- Resolution approach: walk-through
- Fixed pre-existing bugs: stale `tools/` path references in README.md and bin/download-sf2.sh

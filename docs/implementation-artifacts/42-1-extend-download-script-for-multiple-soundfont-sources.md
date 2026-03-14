# Story 42.1: Extend Download Script for Multiple SoundFont Sources

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want `bin/download-sf2.sh` to support downloading multiple SF2 files to `.cache`,
so that all source SoundFonts needed for the custom SF2 assembly are available locally and their integrity is verified.

## Acceptance Criteria

1. **Given** the download script and config, **when** `bin/download-sf2.sh` is run, **then** it downloads all SF2 files listed in `bin/sf2-sources.conf` to `.cache/`, each file's SHA-256 checksum is verified against the expected value in the config, and files that already exist with the correct checksum are skipped (idempotent).

2. **Given** `bin/sf2-sources.conf`, **when** a developer reads it, **then** it contains entries for at least:
   - GeneralUser GS v2.0.3 (existing entry -- non-piano presets source)
   - FluidR3_GM (MIT license -- piano presets source)
   - JNSGM2 (CC0 -- reference/comparison)
   - Each entry includes: url, filename, sha256, license, and attribution fields.

3. **Given** a download failure for one file, **when** the script runs, **then** it reports the failure clearly, continues downloading remaining files, and exits with a non-zero status if any download failed.

4. **Given** the config file format, **when** a developer needs to add a new SF2 source, **then** they add a new entry block to `bin/sf2-sources.conf` following the existing format.

## Tasks / Subtasks

- [x] Task 1: Extend `bin/sf2-sources.conf` to multi-entry format (AC: #2, #4)
  - [x] 1.1 Design and implement section-based format (e.g., `[SectionName]` INI-style blocks separated by blank lines)
  - [x] 1.2 Migrate existing GeneralUser GS entry to new format, preserving all comment metadata (version, commit, license)
  - [x] 1.3 Add FluidR3_GM entry with url, filename, sha256, license, attribution
  - [x] 1.4 Add JNSGM2 entry with url, filename, sha256, license, attribution
- [x] Task 2: Rewrite `bin/download-sf2.sh` to iterate over all config entries (AC: #1, #3)
  - [x] 2.1 Parse multi-entry config: loop over `[section]` blocks, extract url/filename/sha256 per entry
  - [x] 2.2 Download each entry to `.cache/{filename}` with existing curl+retry logic
  - [x] 2.3 Verify checksum per entry using existing `verify_checksum` pattern
  - [x] 2.4 Skip files that already exist with correct checksum (idempotent, per existing logic)
  - [x] 2.5 On per-file failure: log error, continue to next file, track failure count
  - [x] 2.6 Exit with non-zero status if any download failed; exit 0 only if all succeeded
  - [x] 2.7 Preserve HTML error page detection for each download
  - [x] 2.8 Update script header comment to reflect multi-file support
- [x] Task 3: Verify checksums for new SF2 files (AC: #2)
  - [x] 3.1 Download FluidR3_GM manually, compute SHA-256, add to config
  - [x] 3.2 Download JNSGM2 manually, compute SHA-256, add to config
- [x] Task 4: End-to-end test (AC: #1, #3)
  - [x] 4.1 Run script from clean state (no `.cache/`), verify all three files downloaded
  - [x] 4.2 Run script again, verify all three files skipped (idempotent)
  - [x] 4.3 Corrupt one cached file, run script, verify only that file re-downloaded
  - [x] 4.4 Test with an intentionally wrong URL, verify partial failure behavior

## Dev Notes

### Current State of `bin/download-sf2.sh`

The existing script (114 lines) handles a **single** SF2 file:
- Reads flat key=value config from `bin/sf2-sources.conf` via `grep '^key=' | cut -d'=' -f2-`
- Downloads to `.cache/{filename}` with `curl -L -f --retry 3 --silent --show-error`
- Verifies SHA-256 via `shasum -a 256`
- Detects HTML error pages via `file ... | grep -qi "HTML"`
- Has cleanup trap for temp files
- Uses `set -euo pipefail`

### Current State of `bin/sf2-sources.conf`

Flat key=value format, single entry:
```
url=https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/97049183643d5fc5a9322a69c5b09efb667c6c3a/GeneralUser-GS.sf2
filename=GeneralUser-GS.sf2
sha256=9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe
```

### Config Format Design

Use INI-style `[SectionName]` blocks. Each block has the same key=value pairs. Blank lines and `#` comments are allowed between blocks. The parser iterates sections sequentially.

Example target format:
```ini
[GeneralUser-GS]
# Source: https://github.com/mrbumpy409/GeneralUser-GS
# Version: 2.0.3
# License: Free for any use; attribution to S. Christian Collins required
url=https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/97049183643d5fc5a9322a69c5b09efb667c6c3a/GeneralUser-GS.sf2
filename=GeneralUser-GS.sf2
sha256=9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe
license=Free for any use; attribution required
attribution=S. Christian Collins

[FluidR3_GM]
# Source: https://github.com/FluidSynth/fluidsynth (bundled with FluidSynth)
# License: MIT
url=<determined at implementation time>
filename=FluidR3_GM.sf2
sha256=<computed after download>
license=MIT
attribution=Frank Wen and the FluidSynth project

[JNSGM2]
# Source: https://github.com/wrightflyer/SF2_SoundFonts
# License: CC0
url=https://github.com/wrightflyer/SF2_SoundFonts/raw/master/Jnsgm2.sf2
filename=Jnsgm2.sf2
sha256=<computed after download>
license=CC0
attribution=Public domain
```

### Script Refactoring Approach

The key structural change: replace single-entry parsing with a loop. Pseudocode:
1. Parse config into array of entries (each entry = associative array of url/filename/sha256)
2. For each entry: check cache -> skip or download -> verify checksum
3. Track failures, report summary, exit with appropriate code

`set -euo pipefail` must be adjusted for the continue-on-failure requirement: the download function should return a status rather than calling `exit 1`. Wrap the per-file logic in a function that returns 0/1 and accumulate failures.

### Download URLs

From the epic and research document:
- **FluidR3_GM:** `https://sourceforge.net/projects/pianobooster/files/pianobooster/1.0.0/FluidR3_GM.sf2/download` (SourceForge redirect) or a GitHub mirror. SourceForge URLs sometimes return HTML -- the existing HTML detection guard is critical here. Consider finding a direct-link mirror.
- **JNSGM2:** `https://github.com/wrightflyer/SF2_SoundFonts/raw/master/Jnsgm2.sf2` (direct binary from GitHub)
- **GeneralUser GS:** existing URL (raw GitHub, stable commit hash)

### What This Story Does NOT Touch

- No Swift code changes
- No Xcode project file changes (story 42.2+ will handle the custom SF2 and bundle references)
- No changes to `SoundFontLibrary`, `SoundFontNotePlayer`, or `PeachApp`
- The downloaded source SF2 files are raw materials for the manual Polyphone assembly step (a later story)

### Project Structure Notes

- `bin/download-sf2.sh` and `bin/sf2-sources.conf` are the only files modified
- `.cache/` is gitignored -- downloaded SF2 files stay local
- `.cache/GeneralUser-GS.sf2` is referenced by Xcode build -- do not change its filename or location
- New SF2 files (`FluidR3_GM.sf2`, `Jnsgm2.sf2`) download to `.cache/` but are NOT referenced by Xcode yet

### References

- [Source: docs/planning-artifacts/epics.md#Epic 42, Story 42.1]
- [Source: docs/planning-artifacts/research/technical-alternative-gm-soundfont-sf2-research-2026-03-14.md]
- [Source: bin/download-sf2.sh] -- current single-file download script
- [Source: bin/sf2-sources.conf] -- current single-entry config
- [Source: docs/implementation-artifacts/infra-sf2-build-download-cache.md] -- original infrastructure story that created the download pipeline

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — no issues encountered during implementation.

### Completion Notes List

- Converted `bin/sf2-sources.conf` from flat key=value to INI-style `[SectionName]` blocks with url, filename, sha256, license, attribution per entry
- Added FluidR3_GM (MIT, SourceForge URL, 148 MB) and JNSGM2 (CC0, GitHub URL, 33 MB) entries with verified SHA-256 checksums
- Rewrote `bin/download-sf2.sh` to parse INI sections and iterate over all entries, with per-file error handling (continue on failure, accumulate failure count, non-zero exit if any failed)
- Changed `set -euo pipefail` to `set -uo pipefail` (removed `-e` so per-file failures don't abort the script)
- Removed global cleanup trap in favor of per-entry temp file cleanup
- All four E2E test scenarios passed: clean download, idempotent skip, selective re-download on corruption, partial failure with wrong URL

### Change Log

- 2026-03-14: Implemented story 42.1 — multi-source SF2 download support

### File List

- `bin/sf2-sources.conf` — converted to INI-style multi-entry format with 3 SF2 sources
- `bin/download-sf2.sh` — rewritten to iterate over all config entries with continue-on-failure
- `docs/implementation-artifacts/42-1-extend-download-script-for-multiple-soundfont-sources.md` — story file updated

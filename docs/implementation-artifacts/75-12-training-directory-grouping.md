# Story 75.12: Training Directory Grouping

Status: review

## Story

As a **developer navigating the project**,
I want training feature directories grouped under a `Training/` parent,
so that they are visually separated from unrelated screens like `Info/`, `Profile/`, `Settings/`.

## Background

The walkthrough (Layer 3) noted that `PitchDiscrimination/`, `PitchMatching/`, `RhythmOffsetDetection/`, and `ContinuousRhythmMatching/` are top-level siblings of unrelated directories (`Info/`, `Profile/`, `Settings/`, `Start/`). All four training feature directories share infrastructure (`Core/Training/`), observer patterns, and session lifecycle — grouping them reflects this relationship.

**Walkthrough source:** Layer 3 observation #3.

## Acceptance Criteria

1. **Given** the Xcode project navigator **When** browsing **Then** `PitchDiscrimination/`, `PitchMatching/`, `RhythmOffsetDetection/` (or `TimingOffsetDetection/` if 75.11 is done first), and `ContinuousRhythmMatching/` are under a `Training/` parent group.
2. **Given** all import paths and file references **When** inspected **Then** they reflect the new structure.
3. **Given** `bin/check-dependencies.sh` **When** run **Then** it passes clean (update any path-based rules).
4. **Given** both platforms **When** built and tested **Then** all tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Create Training/ parent group in Xcode (AC: #1)
  - [x] Create `Peach/Training/` group
  - [x] Move `PitchDiscrimination/` under `Training/`
  - [x] Move `PitchMatching/` under `Training/`
  - [x] Move `RhythmOffsetDetection/` under `Training/`
  - [x] Move `ContinuousRhythmMatching/` under `Training/`

- [x] Task 2: Update path-based references (AC: #2, #3)
  - [x] Update `bin/check-dependencies.sh` if it references old paths
  - [x] Search for any hardcoded paths in documentation or scripts

- [x] Task 3: Build and test both platforms (AC: #4)
  - [x] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Ordering Relative to Story 75.11

If Story 75.11 (Rhythm→Timing rename) is done first, then `RhythmOffsetDetection/` will already be `TimingOffsetDetection/`. Either order works — just use whatever the directory is named at the time.

### Xcode Group vs Filesystem

SwiftUI projects typically keep Xcode groups aligned with filesystem directories. When moving groups:
- Move the filesystem directories first
- Update the Xcode project file to reference the new locations
- Or use Xcode's "Move to Group" feature which handles both

### What NOT to Change

- Do not move `Core/Training/` — it stays in Core (it's the shared training infrastructure)
- Do not move `Profile/`, `Settings/`, `Info/`, `Start/` — they are not training features
- Do not change any file contents — this is purely organizational

### References

- [Source: docs/walkthrough/3-training-sessions.md — observation #3]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None

### Completion Notes List
- Moved PitchDiscrimination/, PitchMatching/, RhythmOffsetDetection/, ContinuousRhythmMatching/ under new Peach/Training/ parent directory
- Mirrored structure in PeachTests/Training/ to maintain test directory mirroring convention
- Refactored bin/check-dependencies.sh to collect feature directories from both top-level and Training/ subdirectories using a FEATURE_DIRS array, ensuring all dependency rules (SwiftData, UIKit, Combine, cross-feature references) work with new paths
- Updated docs/project-context.md path references for UIKit, cross-feature coupling, file placement, and test organization sections
- Project uses PBXFileSystemSynchronizedRootGroup so no pbxproj edits were needed — Xcode auto-syncs from filesystem
- All 1711 iOS tests and 1704 macOS tests pass with zero regressions

### File List
- Peach/Training/ (new directory)
- Peach/Training/PitchDiscrimination/ (moved from Peach/PitchDiscrimination/)
- Peach/Training/PitchMatching/ (moved from Peach/PitchMatching/)
- Peach/Training/RhythmOffsetDetection/ (moved from Peach/RhythmOffsetDetection/)
- Peach/Training/ContinuousRhythmMatching/ (moved from Peach/ContinuousRhythmMatching/)
- PeachTests/Training/ (new directory)
- PeachTests/Training/PitchDiscrimination/ (moved from PeachTests/PitchDiscrimination/)
- PeachTests/Training/PitchMatching/ (moved from PeachTests/PitchMatching/)
- PeachTests/Training/RhythmOffsetDetection/ (moved from PeachTests/RhythmOffsetDetection/)
- PeachTests/Training/ContinuousRhythmMatching/ (moved from PeachTests/ContinuousRhythmMatching/)
- bin/check-dependencies.sh (modified — refactored to handle Training/ parent group)
- docs/project-context.md (modified — updated path references)
- docs/implementation-artifacts/sprint-status.yaml (modified — status update)

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-06: Implementation complete — directories grouped under Training/, scripts and docs updated

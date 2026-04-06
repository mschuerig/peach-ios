# Story 75.12: Training Directory Grouping

Status: ready-for-dev

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

- [ ] Task 1: Create Training/ parent group in Xcode (AC: #1)
  - [ ] Create `Peach/Training/` group
  - [ ] Move `PitchDiscrimination/` under `Training/`
  - [ ] Move `PitchMatching/` under `Training/`
  - [ ] Move `RhythmOffsetDetection/` (or `TimingOffsetDetection/`) under `Training/`
  - [ ] Move `ContinuousRhythmMatching/` under `Training/`

- [ ] Task 2: Update path-based references (AC: #2, #3)
  - [ ] Update `bin/check-dependencies.sh` if it references old paths
  - [ ] Search for any hardcoded paths in documentation or scripts

- [ ] Task 3: Build and test both platforms (AC: #4)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations

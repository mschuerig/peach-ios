# Story 44.1: Split Core/Audio into Core/Music and Core/Audio

Status: ready-for-dev

## Story

As a **developer**,
I want musical domain value types in their own Core/Music/ directory separate from audio infrastructure in Core/Audio/,
So that the codebase has clean separation between domain concepts and audio machinery before adding rhythm types.

## Acceptance Criteria

1. **Given** the 13 domain-concept files currently in Core/Audio/ (MIDINote, DetunedMIDINote, Frequency, Cents, Interval, DirectedInterval, Direction, TuningSystem, MIDIVelocity, AmplitudeDB, NoteDuration, NoteRange, SoundSourceID), **when** the directory split is performed, **then** all 13 files are moved to Core/Music/ with matching Xcode group structure.

2. **Given** the 8 audio infrastructure files (NotePlayer, PlaybackHandle, SoundFontNotePlayer, SoundFontPlaybackHandle, SoundFontLibrary, SF2PresetParser, SoundSourceProvider, AudioSessionInterruptionMonitor), **when** the split is performed, **then** all 8 remain in Core/Audio/.

3. **Given** test files mirror source structure, **when** source files are moved, **then** corresponding test files are moved to PeachTests/Core/Music/.

4. **Given** the single-module app architecture, **when** all files are moved, **then** the project builds with zero errors and zero warnings, and all existing tests pass without modification.

5. **Given** this is a pure file-move refactoring, **when** changes are reviewed, **then** no type renames, no API changes, and no behavioral changes have occurred.

## Tasks / Subtasks

- [ ] Task 1: Create target directories (AC: #1, #3)
  - [ ] Create `Peach/Core/Music/` directory with `.gitkeep`
  - [ ] Create `PeachTests/Core/Music/` directory with `.gitkeep`
- [ ] Task 2: Move 13 domain-concept source files to Core/Music/ (AC: #1)
  - [ ] Move MIDINote.swift
  - [ ] Move DetunedMIDINote.swift
  - [ ] Move Frequency.swift
  - [ ] Move Cents.swift
  - [ ] Move Interval.swift
  - [ ] Move DirectedInterval.swift
  - [ ] Move Direction.swift
  - [ ] Move TuningSystem.swift
  - [ ] Move MIDIVelocity.swift
  - [ ] Move AmplitudeDB.swift
  - [ ] Move NoteDuration.swift
  - [ ] Move NoteRange.swift
  - [ ] Move SoundSourceID.swift
- [ ] Task 3: Move 13 corresponding test files to PeachTests/Core/Music/ (AC: #3)
  - [ ] Move MIDINoteTests.swift
  - [ ] Move DetunedMIDINoteTests.swift
  - [ ] Move FrequencyTests.swift
  - [ ] Move CentsTests.swift
  - [ ] Move IntervalTests.swift
  - [ ] Move DirectedIntervalTests.swift
  - [ ] Move DirectionTests.swift
  - [ ] Move TuningSystemTests.swift
  - [ ] Move MIDIVelocityTests.swift
  - [ ] Move AmplitudeDBTests.swift
  - [ ] Move NoteDurationTests.swift
  - [ ] Move NoteRangeTests.swift
  - [ ] Move SoundSourceIDTests.swift
- [ ] Task 4: Update Xcode project file (AC: #1)
  - [ ] Add `Core/Music/.gitkeep` to PBXFileSystemSynchronizedBuildFileExceptionSet
- [ ] Task 5: Verify audio infrastructure files remain in Core/Audio/ (AC: #2)
  - [ ] Confirm NotePlayer.swift, PlaybackHandle.swift, SoundFontNotePlayer.swift, SoundFontPlaybackHandle.swift, SoundFontLibrary.swift, SF2PresetParser.swift, SoundSourceProvider.swift, AudioSessionInterruptionMonitor.swift are untouched
- [ ] Task 6: Build and test (AC: #4)
  - [ ] Run `bin/build.sh` — zero errors, zero warnings
  - [ ] Run `bin/test.sh` — all tests pass
- [ ] Task 7: Verify no behavioral changes (AC: #5)
  - [ ] Confirm no type renames, no API changes, no logic changes in any moved file

## Dev Notes

### This is a pure file-move refactoring

No file contents should change. Use `git mv` for all moves so git tracks rename history. Do NOT rename any types, change any APIs, or modify any behavior.

### Xcode uses file-system-synchronized build groups

The project uses `PBXFileSystemSynchronizedRootGroup` — directories on disk are automatically reflected in Xcode without manual file/group configuration. Creating `Core/Music/` on disk will automatically make it appear in Xcode. The only pbxproj change needed is adding `Core/Music/.gitkeep` to the exception set (`.gitkeep` files are excluded from the build).

### Current exception set in project.pbxproj

The `PBXFileSystemSynchronizedBuildFileExceptionSet` for the Peach target currently excludes these `.gitkeep` files:
- `Core/Algorithm/.gitkeep`
- `Core/Audio/.gitkeep`
- `Core/Data/.gitkeep`
- `Core/Profile/.gitkeep`
- `Info/.gitkeep`
- `Profile/.gitkeep`
- `Settings/.gitkeep`
- `Start/.gitkeep`

Add `Core/Music/.gitkeep` to this list (alphabetical order, between `Core/Data/.gitkeep` and `Core/Profile/.gitkeep`).

### No import changes needed

Single-module app — all files are in the same module. No `import` statements reference `Core/Audio/` paths. Moving files has zero import impact.

### Files to move (source → destination)

**Source files** (`Peach/Core/Audio/` → `Peach/Core/Music/`):
| # | File | Domain |
|---|------|--------|
| 1 | MIDINote.swift | MIDI pitch identity |
| 2 | DetunedMIDINote.swift | Pitch with cent offset |
| 3 | Frequency.swift | Physical frequency (Hz) |
| 4 | Cents.swift | Pitch deviation unit |
| 5 | Interval.swift | Musical interval enum |
| 6 | DirectedInterval.swift | Interval + direction |
| 7 | Direction.swift | Up/down enum |
| 8 | TuningSystem.swift | Frequency calculation |
| 9 | MIDIVelocity.swift | Note loudness |
| 10 | AmplitudeDB.swift | Decibel amplitude |
| 11 | NoteDuration.swift | Note length |
| 12 | NoteRange.swift | Note range value type |
| 13 | SoundSourceID.swift | Sound source identifier |

**Test files** (`PeachTests/Core/Audio/` → `PeachTests/Core/Music/`):
| # | File |
|---|------|
| 1 | MIDINoteTests.swift |
| 2 | DetunedMIDINoteTests.swift |
| 3 | FrequencyTests.swift |
| 4 | CentsTests.swift |
| 5 | IntervalTests.swift |
| 6 | DirectedIntervalTests.swift |
| 7 | DirectionTests.swift |
| 8 | TuningSystemTests.swift |
| 9 | MIDIVelocityTests.swift |
| 10 | AmplitudeDBTests.swift |
| 11 | NoteDurationTests.swift |
| 12 | NoteRangeTests.swift |
| 13 | SoundSourceIDTests.swift |

### Files staying in Core/Audio/ (DO NOT MOVE)

| # | File | Role |
|---|------|------|
| 1 | NotePlayer.swift | Protocol — pitch playback abstraction |
| 2 | PlaybackHandle.swift | Protocol — playback lifecycle |
| 3 | SoundFontNotePlayer.swift | Implementation — AVAudioEngine owner |
| 4 | SoundFontPlaybackHandle.swift | Implementation — playback lifecycle |
| 5 | SoundFontLibrary.swift | SF2 file discovery and preset management |
| 6 | SF2PresetParser.swift | SF2 RIFF file header parsing |
| 7 | SoundSourceProvider.swift | Protocol — sound source discovery |
| 8 | AudioSessionInterruptionMonitor.swift | AVAudioSession interruption handling |

### Test files staying in PeachTests/Core/Audio/ (DO NOT MOVE)

NotePlayerConvenienceTests.swift, PlaybackHandleTests.swift, SoundFontNotePlayerTests.swift, SoundFontPlaybackHandleTests.swift, SoundFontLibraryTests.swift, SF2PresetParserTests.swift, SoundFontPresetStressTests.swift, AudioSessionInterruptionMonitorTests.swift

### Anti-patterns to avoid

- **Do NOT rename any types** — this is a pure file move
- **Do NOT modify file contents** — zero diffs inside moved files
- **Do NOT delete .gitkeep files** — they keep empty directories tracked
- **Do NOT create a SoundSourceIDTests.swift** if one doesn't exist — only move files that already exist (SoundSourceIDTests.swift does exist)
- **Do NOT update project-context.md** — that will be a separate follow-up after the full Epic 44 completes

### Project Structure Notes

- After this story, `Core/Music/` holds domain value types (pure Swift, no framework imports)
- After this story, `Core/Audio/` holds audio infrastructure (AVFoundation, AudioToolbox)
- This separation prepares for v0.4 rhythm types (TempoBPM, RhythmOffset, RhythmDirection) which will go in `Core/Music/`
- No cross-feature coupling — the file placement decision tree in project-context.md says "Audio domain value types → `Core/Audio/`" — this will need updating to `Core/Music/` after Epic 44 completes

### References

- [Source: docs/planning-artifacts/epics.md — Epic 44, Story 44.1]
- [Source: docs/planning-artifacts/architecture.md — v0.4 Amendment, "Prerequisite Refactorings, Section A"]
- [Source: docs/project-context.md — File Placement Decision Tree, Dependency Direction Rules]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

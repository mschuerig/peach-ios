# Story 61.1: Consolidate Infrastructure Port Protocols into Core/Ports

Status: ready-for-dev

## Story

As a developer navigating the codebase,
I want infrastructure boundary protocols collected in a single `Core/Ports/` directory,
so that I can quickly discover what the domain layer requires from the outside world — mirroring the Rust codebase's `domain/src/ports.rs` discoverability.

## Context

The Rust codebase has a single `ports.rs` (97 lines) that serves as the "constitution" of the domain boundary. The iOS codebase scatters ~26 protocols across 12 directories. Not all belong in `Ports/` — only the **infrastructure boundary protocols** that define what the domain requires from adapters. Internal domain contracts (e.g., `WelfordMeasurement`, `TrainingDiscipline`) and discipline-specific observer protocols stay where they are.

## Acceptance Criteria

### AC 1: Ports directory exists

**Given** the Xcode project
**When** the developer looks at `Peach/Core/Ports/`
**Then** it contains the infrastructure boundary protocols listed below, each in its own file

### AC 2: Infrastructure boundary protocols moved

**Given** the following protocols
**When** the consolidation is complete
**Then** each has been moved from its current location to `Peach/Core/Ports/`:

| Protocol | Current Location |
|---|---|
| `NotePlayer` | `Core/Audio/NotePlayer.swift` |
| `PlaybackHandle` | `Core/Audio/PlaybackHandle.swift` |
| `RhythmPlayer` | `Core/Audio/RhythmPlayer.swift` |
| `RhythmPlaybackHandle` | `Core/Audio/RhythmPlaybackHandle.swift` |
| `StepSequencer` | `Core/Audio/StepSequencer.swift` |
| `SoundSourceProvider` | `Core/Audio/SoundSourceProvider.swift` |
| `TrainingRecordPersisting` | `Core/Data/TrainingRecordPersisting.swift` |
| `UserSettings` | `Settings/UserSettings.swift` |
| `ProfileUpdating` | `Core/Training/ProfileUpdating.swift` |
| `TrainingProfile` | `Core/Profile/TrainingProfile.swift` |
| `HapticFeedback` | `PitchDiscrimination/HapticFeedbackManager.swift` |

### AC 3: Protocols NOT moved

**Given** the following protocol categories
**When** the consolidation is complete
**Then** they remain in their current locations:

- **Observer protocols** (`PitchDiscriminationObserver`, `PitchMatchingObserver`, `RhythmOffsetDetectionObserver`, `ContinuousRhythmMatchingObserver`) — tightly coupled to their discipline
- **Internal domain contracts** (`WelfordMeasurement`, `TrainingDiscipline`, `GranularityZoneConfig`, `StepProvider`, `Resettable`, `SoundSourceID`) — abstractions within the domain, not ports to infrastructure
- **Strategy protocols** (`NextPitchDiscriminationStrategy`, `NextRhythmOffsetDetectionStrategy`) — algorithm extension points, not infrastructure ports
- **Meta protocols** (`TrainingSession`) — session contract, not an adapter boundary

### AC 4: No behavioral changes

**Given** the full test suite
**When** run
**Then** all tests pass with zero regressions — this is a pure file-move refactoring with no behavioral changes

### AC 5: HapticFeedback extracted from HapticFeedbackManager

**Given** `HapticFeedbackManager.swift` currently contains both the `HapticFeedback` protocol and its concrete `HapticFeedbackManager` implementation
**When** the protocol is moved to `Core/Ports/`
**Then** only the protocol moves; `HapticFeedbackManager` stays in `PitchDiscrimination/`

### AC 6: StepSequencer protocol extracted

**Given** `StepSequencer.swift` currently contains both the `StepSequencer` protocol and the `StepProvider` protocol
**When** the consolidation is complete
**Then** `StepSequencer` protocol moves to `Core/Ports/StepSequencer.swift`; `StepProvider` stays in `Core/Audio/` (it is an internal domain contract, not an infrastructure port)

### AC 7: Deprecated protocol not moved

**Given** `PitchDiscriminationRecordStoring` is deprecated in favor of `TrainingRecordPersisting`
**When** the consolidation is complete
**Then** `PitchDiscriminationRecordStoring` is NOT moved — it remains where it is (or is removed if no longer referenced)

## Tasks / Subtasks

- [ ] Task 1: Create `Peach/Core/Ports/` directory and Xcode group (AC: 1)
- [ ] Task 2: Move pure protocol files (AC: 2)
  - [ ] 2.1 Move `NotePlayer.swift` from `Core/Audio/` to `Core/Ports/`
  - [ ] 2.2 Move `PlaybackHandle.swift` from `Core/Audio/` to `Core/Ports/`
  - [ ] 2.3 Move `RhythmPlayer.swift` from `Core/Audio/` to `Core/Ports/`
  - [ ] 2.4 Move `RhythmPlaybackHandle.swift` from `Core/Audio/` to `Core/Ports/`
  - [ ] 2.5 Move `SoundSourceProvider.swift` from `Core/Audio/` to `Core/Ports/`
  - [ ] 2.6 Move `TrainingRecordPersisting.swift` from `Core/Data/` to `Core/Ports/`
  - [ ] 2.7 Move `UserSettings.swift` from `Settings/` to `Core/Ports/`
  - [ ] 2.8 Move `ProfileUpdating.swift` from `Core/Training/` to `Core/Ports/`
  - [ ] 2.9 Move `TrainingProfile.swift` from `Core/Profile/` to `Core/Ports/`
- [ ] Task 3: Extract and move mixed-file protocols (AC: 5, 6)
  - [ ] 3.1 Extract `HapticFeedback` protocol from `HapticFeedbackManager.swift` into `Core/Ports/HapticFeedback.swift`
  - [ ] 3.2 Extract `StepSequencer` protocol from `Core/Audio/StepSequencer.swift` into `Core/Ports/StepSequencer.swift`, leaving `StepProvider` in the original file
- [ ] Task 4: Verify deprecated protocol (AC: 7)
  - [ ] 4.1 Check if `PitchDiscriminationRecordStoring` has any remaining callers; if none, remove it
- [ ] Task 5: Build and test (AC: 4)
  - [ ] 5.1 Build succeeds with no errors
  - [ ] 5.2 Full test suite passes with zero regressions

## Dev Notes

- This is a structural refactoring only — no protocol signatures change, no implementations change
- Xcode's "Move to Group" refactoring should handle most of this cleanly
- The key design decision: **observers stay with their disciplines**. They are technically ports (domain pushes events outward), but their tight coupling to specific disciplines means co-location aids cohesion more than consolidation aids discoverability
- After this story, a developer can answer "what adapters does this app need?" by listing the contents of `Core/Ports/`

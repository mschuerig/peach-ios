# Story 61.2: Rename State Enum to Reference/Target and Glossary Cleanup

Status: ready-for-dev

## Story

As a developer reading the pitch discrimination session code,
I want state enum cases to carry semantic meaning (`playingReferenceNote` / `playingTargetNote`),
so that I don't need to mentally translate ordinal names to their domain roles.

## Context

Story 22.4 migrated all data models, trials, CSV columns, and strategies from `note1`/`note2` to `referenceNote`/`targetNote`. The state machine enum cases were intentionally left as `playingNote1`/`playingNote2` at the time because they encode playback sequence. However, the code already has translation comments like `let wasPlayingTargetNote = (state == .playingNote2)` — a code smell indicating the name doesn't communicate intent. The glossary also still documents the state values with the old naming.

Scope: 25 occurrences across 5 Swift files, plus glossary and living documentation (arc42, project-context). Historical implementation artifacts are left as-is.

## Acceptance Criteria

### AC 1: State enum cases renamed

**Given** `PitchDiscriminationSessionState` in `PitchDiscriminationSession.swift`
**When** the rename is complete
**Then** `playingNote1` → `playingReferenceNote` and `playingNote2` → `playingTargetNote`

### AC 2: All Swift references updated

**Given** the following files reference the old enum case names
**When** the rename is complete
**Then** all references use the new names:

| File | Occurrences |
|---|---|
| `PitchDiscriminationSession.swift` | 7 |
| `PitchDiscriminationScreen.swift` | 2 |
| `PitchDiscriminationSessionTests.swift` | 8 |
| `PitchDiscriminationSessionLifecycleTests.swift` | 4 |
| `PitchDiscriminationSessionAudioInterruptionTests.swift` | 4 |

### AC 3: Translation comments removed

**Given** any comments that exist solely to map `playingNote2` to "target note" (e.g., `let wasPlayingTargetNote = (state == .playingNote2)`)
**When** the rename is complete
**Then** the translation variable or comment is simplified since the name now communicates intent directly

### AC 4: Glossary updated

**Given** `docs/planning-artifacts/glossary.md`
**When** the cleanup is complete
**Then** the **Pitch Discrimination Session State** entry lists: `idle`, `playingReferenceNote`, `playingTargetNote`, `awaitingAnswer`, `showingFeedback`

### AC 5: Living documentation updated

**Given** the following documentation files
**When** the rename is complete
**Then** they reflect the new state names:

| Document | What to update |
|---|---|
| `docs/arc42.md` | State machine flow description |
| `docs/project-context.md` | State machine enum case listing |

### AC 6: Historical artifacts left as-is

**Given** historical implementation artifacts (stories 3.2, 3.3, 3.4, 19.5, 37.3, 48.2, 48.3, etc.)
**When** the rename is complete
**Then** they are NOT modified — they document what was true at the time of implementation

### AC 7: No regressions

**Given** the full test suite
**When** run
**Then** all tests pass with zero regressions

## Tasks / Subtasks

- [ ] Task 1: Rename enum cases (AC: 1)
  - [ ] 1.1 In `PitchDiscriminationSession.swift`, rename `case playingNote1` → `case playingReferenceNote`
  - [ ] 1.2 In `PitchDiscriminationSession.swift`, rename `case playingNote2` → `case playingTargetNote`
- [ ] Task 2: Update all Swift references (AC: 2, 3)
  - [ ] 2.1 Update all `.playingNote1` → `.playingReferenceNote` references in `PitchDiscriminationSession.swift`
  - [ ] 2.2 Update all `.playingNote2` → `.playingTargetNote` references in `PitchDiscriminationSession.swift`
  - [ ] 2.3 Simplify or remove any translation comments/variables that are now redundant
  - [ ] 2.4 Update references in `PitchDiscriminationScreen.swift`
  - [ ] 2.5 Update references in `PitchDiscriminationSessionTests.swift`
  - [ ] 2.6 Update references in `PitchDiscriminationSessionLifecycleTests.swift`
  - [ ] 2.7 Update references in `PitchDiscriminationSessionAudioInterruptionTests.swift`
- [ ] Task 3: Update glossary (AC: 4)
  - [ ] 3.1 Update **Pitch Discrimination Session State** entry in `glossary.md`
- [ ] Task 4: Update living documentation (AC: 5)
  - [ ] 4.1 Update state machine description in `arc42.md`
  - [ ] 4.2 Update enum case listing in `project-context.md`
- [ ] Task 5: Build and test (AC: 7)
  - [ ] 5.1 Build succeeds with no errors
  - [ ] 5.2 Full test suite passes with zero regressions

## Dev Notes

- This is a rename-only change — no behavioral modifications
- The compiler will catch every missed reference since enum case renames are exhaustively checked
- Work order: rename the enum first (Task 1), then fix compiler errors (Task 2), then docs (Tasks 3-4)
- Historical artifacts are explicitly excluded — they document past state, not current

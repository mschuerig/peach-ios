# Story 64.8: Fix SwiftData Dependency Boundary Violations

Status: review

## Story

As a **developer maintaining Peach**,
I want `bin/check-dependencies.sh` to pass clean with SwiftData boundary rules properly scoped,
so that the architectural rule "SwiftData is encapsulated" is enforced where it matters and accepted where the type system requires it.

## Acceptance Criteria

1. **Given** `bin/check-dependencies.sh` **When** run **Then** zero violations are reported.

2. **Given** the `TrainingDiscipline` protocol chain (protocol, registry, port, implementations) **When** reviewed **Then** SwiftData imports are accepted as a documented architectural exception with clear rationale.

3. **Given** `architecture.md` **When** reviewed **Then** the accepted exception is documented with rationale explaining why `PersistentModel` cannot be type-erased without losing compile-time safety.

4. **Given** `project-context.md` **When** reviewed **Then** the SwiftData encapsulation rule reflects the accepted exception scope.

5. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Analyze the SwiftData dependency chain (AC: #1)
  - [x] 1.1 Run `bin/check-dependencies.sh` and list all 9 violations
  - [x] 1.2 Trace why each file needs SwiftData: `TrainingDiscipline.swift` uses `any PersistentModel.Type`, `TrainingRecordPersisting.swift` uses `some PersistentModel`, disciplines use record types that are `@Model`

- [x] Task 2: Attempt marker protocol approach (reverted)
  - [x] 2.1 Introduced `TrainingRecord` marker protocol to replace `PersistentModel` outside `Core/Data/`
  - [x] 2.2 Discovered: requires manual per-type dispatch (`switch` on every concrete `@Model` type) for both insertion and deletion — trades compile-time safety for runtime `preconditionFailure`
  - [x] 2.3 Architect review concluded: the cure is worse than the disease — reverted

- [x] Task 3: Accept exception and update boundary rules (AC: #1, #2, #3, #4)
  - [x] 3.1 Update `bin/check-dependencies.sh` to accept SwiftData in `Core/Training/`, `Core/Ports/`, and `*Discipline.swift` files
  - [x] 3.2 Fix pre-existing bug: UIKit exception checked `PitchComparison` instead of `PitchDiscrimination`
  - [x] 3.3 Document accepted exception in `architecture.md` with full rationale
  - [x] 3.4 Update `project-context.md` SwiftData encapsulation rule

- [x] Task 4: Verify `bin/check-dependencies.sh` passes clean (AC: #1)

## Dev Notes

### Current Violations (9 files — now accepted)

1. `Core/Training/TrainingDiscipline.swift` — `recordType: any PersistentModel.Type`
2. `Core/Training/TrainingDisciplineRegistry.swift` — accesses `recordType` from disciplines
3. `Core/Ports/TrainingRecordPersisting.swift` — `some PersistentModel` generic constraint
4. `PitchDiscrimination/UnisonPitchDiscriminationDiscipline.swift`
5. `PitchDiscrimination/IntervalPitchDiscriminationDiscipline.swift`
6. `PitchMatching/UnisonPitchMatchingDiscipline.swift`
7. `PitchMatching/IntervalPitchMatchingDiscipline.swift`
8. `RhythmOffsetDetection/RhythmOffsetDetectionDiscipline.swift`
9. `ContinuousRhythmMatching/ContinuousRhythmMatchingDiscipline.swift`

### Why Type Erasure Failed

`PersistentModel` inherits from `Identifiable` which has `associatedtype ID`. This prevents Swift's existential opening (SE-0352) from working — `any PersistentModel` cannot be passed to `ModelContext.insert(some PersistentModel)`. A marker protocol approach was attempted but required:
- Manual `switch` dispatch for every concrete `@Model` type in both `insertRecord` and `deleteAllRecordTypes`
- Runtime `preconditionFailure` instead of compile-time errors when a new type is added
- `@Model` macro interference when adding protocol conformances on class declarations (must use extensions)

The architectural cost (runtime safety replacing compile-time safety, two manual dispatch sites to maintain) exceeded the benefit (clean import boundaries).

### Decision

Accept the SwiftData imports in the `TrainingDiscipline` protocol chain as a documented exception. Update `bin/check-dependencies.sh` to encode the exception. Document the rationale in `architecture.md`.

**Principle:** Architectural rules serve the codebase — not the other way around. When enforcing a rule makes the code less safe, update the rule.

### Pre-existing Bug Fixed

`bin/check-dependencies.sh` Rule 3 (UIKit) checked for directory name `PitchComparison` but the actual directory is `PitchDiscrimination`. Fixed as part of this story.

### Source File Locations

| File | Path |
|------|------|
| TrainingDiscipline | `Peach/Core/Training/TrainingDiscipline.swift` |
| TrainingDisciplineRegistry | `Peach/Core/Training/TrainingDisciplineRegistry.swift` |
| TrainingRecordPersisting | `Peach/Core/Ports/TrainingRecordPersisting.swift` |
| All 6 disciplines | `Peach/{Feature}/{Discipline}.swift` |
| check-dependencies.sh | `bin/check-dependencies.sh` |

### References

- [Source: bin/check-dependencies.sh] — Dependency enforcement script
- [Source: docs/planning-artifacts/architecture.md] — "Accepted Exception: SwiftData in the TrainingDiscipline Chain"
- [Source: docs/project-context.md] — Updated SwiftData encapsulation rule

## File List

- `bin/check-dependencies.sh` (modified — added SwiftData exception for discipline chain, fixed UIKit PitchComparison→PitchDiscrimination bug)
- `docs/planning-artifacts/architecture.md` (modified — added "Accepted Exception" section in v0.5)
- `docs/project-context.md` (modified — updated SwiftData encapsulation rule)

## Change Log

- Attempted marker protocol approach to eliminate all SwiftData imports outside Core/Data/ — reverted after architect review concluded it trades compile-time safety for runtime dispatch (Date: 2026-03-28)
- Accepted SwiftData imports in TrainingDiscipline chain as documented exception, updated check-dependencies.sh and architecture docs (Date: 2026-03-28)

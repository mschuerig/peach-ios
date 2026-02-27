# Story 20.11: Update Documentation

Status: pending

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want all architecture documentation updated to reflect the dependency direction cleanup from Epic 20,
So that the docs accurately describe the current codebase, new conventions are captured, and resolved technical debt is marked.

## Acceptance Criteria

1. **arc42 Building Block View updated** -- `docs/arc42/05-building-block-view.md` reflects:
   - New `Core/Training/` directory in the component tree
   - Corrected type names (outdated names like `SineWaveNotePlayer` -> `SoundFontNotePlayer`, `AdaptiveNoteStrategy` -> `KazezNoteStrategy`, `TrainingSession` (class) -> `ComparisonSession`, `TrainingScreen` -> `ComparisonScreen`)
   - `ThresholdTimeline` added to observer list
   - Updated file counts
   - `App/EnvironmentKeys.swift` noted as centralized environment key registry

2. **arc42 Crosscutting Concepts updated** -- `docs/arc42/08-crosscutting-concepts.md` reflects:
   - `@Entry` macro for environment keys (replaces manual `EnvironmentKey` structs in code examples)
   - `EnvironmentKeys.swift` consolidation
   - Updated observer table (includes `ThresholdTimeline`)
   - PitchMatching observer pattern documented alongside Comparison pattern

3. **arc42 Architecture Decisions updated** -- `docs/arc42/09-architecture-decisions.md` includes:
   - AD-10: Dependency Direction Cleanup — documents the rationale for this epic (Core/ must not depend on feature modules, domain layer must not import UI frameworks, concrete types should be behind protocols at module boundaries)
   - AD-9 (Feature-Based Directory Organization) updated to mention `Core/Training/`

4. **arc42 Risks & Technical Debt updated** -- `docs/arc42/11-risks-and-technical-debt.md`:
   - "Mock objects in production code" marked as resolved (Story 20.8)
   - "Settings screen violates 'views are thin' pattern" updated to note SwiftData import removal (Story 20.9)
   - Any other items resolved by Epic 20 marked accordingly

5. **project-context.md updated** -- `docs/project-context.md` includes:
   - `Core/Training/` in file placement decision tree (shared training domain types)
   - Reference to `App/EnvironmentKeys.swift` for new `@Entry` keys (not co-located with domain types)
   - Rule: "No SwiftUI imports in Core/ files"
   - Rule: "No UIKit imports in Core/ files"
   - `Resettable` protocol noted where relevant
   - `SoundSourceID` listed under `Core/Audio/` (not Settings/)

6. **epics.md updated** -- `docs/planning-artifacts/epics.md` includes Epic 20 with all 10 stories.

7. **sprint-status.yaml updated** -- `docs/implementation-artifacts/sprint-status.yaml` includes Epic 20 entries.

## Tasks / Subtasks

- [ ] Task 1: Update `docs/arc42/05-building-block-view.md` (AC: #1)
  - [ ] Add `Core/Training/` to directory tree with contents (Comparison.swift, ComparisonObserver.swift, CompletedPitchMatching.swift, PitchMatchingObserver.swift, Resettable.swift)
  - [ ] Fix outdated type names throughout
  - [ ] Add `ThresholdTimeline` to observer list
  - [ ] Note `App/EnvironmentKeys.swift` as environment key registry
  - [ ] Update file counts

- [ ] Task 2: Update `docs/arc42/08-crosscutting-concepts.md` (AC: #2)
  - [ ] Update DI section code examples to use `@Entry` macro
  - [ ] Document `EnvironmentKeys.swift` pattern
  - [ ] Update observer table
  - [ ] Add PitchMatching observer pattern

- [ ] Task 3: Update `docs/arc42/09-architecture-decisions.md` (AC: #3)
  - [ ] Add AD-10: Dependency Direction Cleanup
  - [ ] Update AD-9 for Core/Training/

- [ ] Task 4: Update `docs/arc42/11-risks-and-technical-debt.md` (AC: #4)
  - [ ] Mark resolved debt items
  - [ ] Add any new observations from implementation

- [ ] Task 5: Update `docs/project-context.md` (AC: #5)
  - [ ] Add `Core/Training/` to file placement rules
  - [ ] Add `App/EnvironmentKeys.swift` guidance for new @Entry keys
  - [ ] Add no-SwiftUI and no-UIKit rules for Core/
  - [ ] Update `SoundSourceID` location

- [ ] Task 6: Update `docs/planning-artifacts/epics.md` (AC: #6)
  - [ ] Add Epic 20 definition with all 10 stories in the established format (As a / I want / So that + Acceptance Criteria in Given/When/Then)

- [ ] Task 7: Verify all doc references are consistent
  - [ ] Cross-check file paths mentioned in docs against actual codebase

## Dev Notes

### Critical Design Decisions

- **Documentation follows code** -- All doc updates happen after all code stories are complete. This ensures the documentation describes the actual final state, not a planned state.
- **AD-10 captures the "why"** -- The new architecture decision documents *why* dependency direction matters even in a single-module app: it's a convention enforced by code review, not the compiler. The epic establishes this as an explicit architectural principle.

### Existing Code to Reference

- **`docs/arc42/05-building-block-view.md`** -- Current building block view with outdated type names. [Source: docs/arc42/05-building-block-view.md]
- **`docs/arc42/08-crosscutting-concepts.md`** -- DI and observer pattern documentation. [Source: docs/arc42/08-crosscutting-concepts.md]
- **`docs/arc42/09-architecture-decisions.md`** -- 9 existing architecture decisions. [Source: docs/arc42/09-architecture-decisions.md]
- **`docs/arc42/11-risks-and-technical-debt.md`** -- Technical debt register. [Source: docs/arc42/11-risks-and-technical-debt.md]
- **`docs/project-context.md`** -- AI agent implementation rules. [Source: docs/project-context.md]

### AD-10 Content Guidance

```
AD-10: Dependency Direction Discipline
- Status: Accepted
- Context: Single-module Swift app has no compiler-enforced module boundaries. Dependency direction must be maintained by convention.
- Decision: (1) Core/ never depends on feature modules; shared types live in Core/Training/. (2) Core/ never imports SwiftUI or UIKit; @Entry definitions live in App/EnvironmentKeys.swift. (3) Feature modules do not depend on each other. (4) Views depend on protocols, not implementations, for all service interactions.
- Consequences: Dependency direction enforced by code review and adversarial audits.
```

### Risk Assessment

- **Low risk** -- Documentation-only changes. No code or test impact.

### Git Intelligence

Commit message: `Implement story 20.10: Update documentation for Epic 20`

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 19 format reference]
- [Source: docs/implementation-artifacts/sprint-status.yaml -- Status tracking format]
- All Epic 20 story files

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.

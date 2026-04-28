# Story 77.6: Per-feature CSV migration contributions

Status: ready-for-dev

## Story

As **a developer maintaining or extending the CSV import path**,
I want each discipline's historical CSV wire-format strings (currently in `Peach/Core/Data/V1ToV2Migration.swift` and `V2ToV3Migration.swift`) to be contributed by the discipline that owns them rather than enumerated centrally,
so that the colocation principle established by 77.2 / 77.3 also covers format migrations and `Peach/Core/Data/` no longer references any specific discipline name.

## Background

Story 77.3 relocated `@Model` record bodies and CSV row parsers into per-feature directories, leaving two files in `Peach/Core/Data/` that still reference discipline-specific names:

- `V1ToV2Migration.swift` — frozen v1→v2 CSV column-name and trainingType-string transforms.
- `V2ToV3Migration.swift` — frozen v2→v3 transforms (e.g., `rhythmMatching` → `continuousRhythmMatching`).

These were explicitly listed as enumerated exceptions in 77.3's AC2. They are immutable by definition (they describe data already in the wild), but they are also the last remaining feature-specific declarations in `Peach/Core/Data/`. Per 77.3's deferred-decisions block, relocating them requires a per-feature migration-contribution mechanism — a small mechanism design story rather than a copy-paste move.

The pattern to design: each discipline contributes its column renames / trainingType renames / value transforms for each (fromVersion, toVersion) pair it participated in. The central migration entry point composes these contributions in version order. Disciplines that didn't exist in v1 (e.g., `ContinuousRhythmMatching` was introduced in v3) contribute nothing to v1→v2 — their absence is what's correct, not a special case.

## Acceptance Criteria

### AC 1: Per-feature migration contributions

**Given** the CSV migration pipeline
**When** a discipline needs to contribute a column rename, a trainingType-string rename, or a value transform across format versions
**Then** the contribution lives in a file inside `Peach/Training/<Feature>/Discipline/` (or equivalent), surfaced via a protocol method on `TrainingDiscipline` (or a sibling protocol). The mechanism is dev's choice: a per-version method, a single-method-returning-array, or a per-(fromVersion, toVersion) method — whichever produces the cleanest call site in the central migration runner.

### AC 2: Central migration runner consumes only contributions

**Given** the central CSV migration entry point (currently `V1ToV2Migration` / `V2ToV3Migration`)
**When** inspected after this story
**Then** it iterates contributions from the registry in version order; it does not enumerate any discipline name or wire-format string itself.

### AC 3: Strict zero-hits in `Peach/Core/Data/`

**Given** `Peach/Core/Data/`
**When** grepped for any discipline-specific name (`unisonPitch`, `intervalPitch`, `rhythm`, `timingOffset`, `continuousRhythm`, `pitchComparison`)
**Then** the only hit is `SchemaV1.models` in `PeachSchema.swift` (which lists concrete `@Model` types for SwiftData — exception 1 from 77.3's amended AC2; this remains intentional because SwiftData reads the schema before the registry is bootstrapped). The two `V*Migration.swift` files no longer carry discipline-specific strings.

### AC 4: Round-trip tests still pass

**Given** the existing CSV import round-trip tests for v1, v2, and v3 inputs across all six disciplines
**When** run after the changes
**Then** all tests pass on iOS Debug, macOS Debug, iOS Research, macOS Research.

### AC 5: All four configurations green, zero new warnings

`bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research` — all green. `bin/build.sh && bin/build.sh -p mac` — zero new warnings.

## Tasks / Subtasks

- [ ] Task 1: Design the contribution protocol (AC: 1)
  - [ ] 1.1 Read `V1ToV2Migration.swift` and `V2ToV3Migration.swift` end-to-end. Catalog every operation type observed (column rename, trainingType-value rename, value transform, etc.).
  - [ ] 1.2 Decide protocol shape: per-version method vs. single method returning a sequence of `(fromVersion, toVersion, operation)` records. Document in Dev Notes.
  - [ ] 1.3 Add the new method(s) to `TrainingDiscipline` (or a sibling protocol) with default empty implementations so disciplines that don't contribute anything need no boilerplate.

- [ ] Task 2: Move contributions per-discipline (AC: 1, 3)
  - [ ] 2.1 For each operation in `V1ToV2Migration.swift`, identify the owning discipline and move the operation into that discipline's contribution.
  - [ ] 2.2 Repeat for `V2ToV3Migration.swift`.
  - [ ] 2.3 Delete or empty out the central files; the runner no longer enumerates anything.

- [ ] Task 3: Verify (AC: 3, 4, 5)
  - [ ] 3.1 Grep `Peach/Core/Data/` for each specific discipline name. Expected: only the `SchemaV1.models` exception remains.
  - [ ] 3.2 Run all four test configurations.
  - [ ] 3.3 Build all four configurations; confirm zero new warnings.

## Dev Notes

### Why this is mechanism design, not a copy-paste move

The migrations operate on raw CSV cell values keyed by column name. A naive "move the strings into the discipline" produces a contribution shaped like `[String: String]`, which carries no version metadata and can't compose. The contribution must encode (fromVersion, toVersion, operation) so the runner can apply only the operations relevant to the source format version of the CSV being imported.

### Composition order

When a CSV at v1 is imported into a v3-aware app, it must run v1→v2 transforms before v2→v3 transforms (in document order: per-discipline contributions are independent across disciplines but ordered within a discipline). The runner's contract: for each (fromVersion, toVersion) step, collect contributions from all disciplines and apply them; then advance to the next step.

### Disciplines that didn't exist at fromVersion

`ContinuousRhythmMatching` was introduced in CSV v3 (epic 54). It contributes nothing to v1→v2 or v2→v3 — its CSV trainingType string `"continuousRhythmMatching"` only ever existed at v3. A discipline that contributes nothing to a step is silent, not skipped — the runner does not need to know which versions the discipline existed in.

### What this story is NOT

- Not a CSV format change.
- Not a schema migration.
- Not a refactor of `TrainingDataImporter` beyond removing the central migration enumeration.

### References

- Story 77.3 — relocated `@Model` record bodies and CSV row parsers; deferred this work.
- `Peach/Core/Data/V1ToV2Migration.swift`, `V2ToV3Migration.swift` — the targets.
- `Peach/Core/Training/Discipline/TrainingDiscipline.swift` — the protocol receiving the new contribution method(s).

## Change Log

- 2026-04-28: Drafted as 77.3 follow-up. Status → ready-for-dev.

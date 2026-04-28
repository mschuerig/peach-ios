# Story 77.5: CSV migration plugin contract (history+derivation)

Status: review

## Story

As **a developer maintaining or extending the CSV import path**,
I want each discipline to declare its own CSV history (which CSV format versions it appeared in, under what `trainingType` identifier, with what columns) and the migration runner to *derive* the column-rename and `trainingType`-rename operations needed for any (sourceVersion, targetVersion) step,
so that `Peach/Core/Data/V1ToV2Migration.swift` and `V2ToV3Migration.swift` can be deleted, and adding a new discipline (or evolving an existing one) requires no edit outside that discipline's feature directory.

## Background

Story 77.3 relocated `@Model` record bodies and CSV row parsers into per-feature directories, leaving `V1ToV2Migration.swift` and `V2ToV3Migration.swift` as the last remaining feature-specific declarations in `Peach/Core/Data/`. Story 77.4 (envelope storage redesign) eliminates the SwiftData side of this — there is no longer a per-discipline `@Model` to migrate. CSV is the last surface that still names disciplines centrally.

The architect/dev discussion established that the right contribution shape is **history + derivation**, not per-step contributions:

- A naive "each discipline contributes its (fromVersion → toVersion) transforms" puts the same information in two places. PitchDiscrimination's renames at v2 are just a consequence of "I was `pitchComparison` at v1 and `pitchDiscrimination` at v2 onward." The runner can derive the v1→v2 step from that history.
- A history is also more defensible in code review: "here is the truth about my CSV identity over time" is one cohesive declaration, where "here are the seven (fromVersion, toVersion) deltas I contribute" is six independent assertions that have to stay mutually consistent.
- Disciplines that didn't exist in earlier versions (`ContinuousRhythmMatching` was introduced at v3) declare a history starting at v3; the runner naturally produces no operations for them in v1→v2 and v2→v3.

This story does **not** change the CSV wire format or expand it. The current format stays at v3.

## Acceptance Criteria

### AC 1: Each discipline declares its CSV history

**Given** each `TrainingDiscipline` conformance under `Peach/Training/<Feature>/`
**When** inspected after this story
**Then** the discipline declares a `csvHistory: CSVHistory` (or equivalent, name is dev's call) listing each CSV format version the discipline existed in, the `trainingType` identifier used at that version, and the columns the discipline contributed at that version. A worked example:

```swift
extension PitchDiscrimination: TrainingDiscipline {
    static let csvHistory = CSVHistory(entries: [
        .init(version: 1, trainingType: "pitchComparison",
              columns: ["referenceNote", "targetNote", "centOffset", …]),
        .init(version: 2, trainingType: "pitchDiscrimination",
              columns: ["referenceNote", "targetNote", "centOffset", …]),
        // v3 unchanged from v2 — entry omitted (or explicit, dev's call)
    ])
}
```

The exact shape is dev's call; the test is that:

- The history entries are ordered by version.
- Each entry knows *what the discipline looked like at that version* (identifier + columns), not "what changed since the last version" — the runner derives changes by diffing consecutive entries.
- A discipline that didn't exist before version *N* has no entry below *N*. There is no "I came into existence at v3" sentinel; the absence of earlier entries is the declaration.

### AC 2: Migration runner derives operations from histories

**Given** the central CSV migration entry point
**When** asked to migrate rows from sourceVersion S to targetVersion T (S < T)
**Then** for each adjacent step *v* → *v+1* between S and T inclusive of S and exclusive of T+1:

- For each discipline, the runner compares the discipline's history entries at *v* and *v+1*:
  - If the `trainingType` differs, rows whose current `trainingType` matches the *v* identifier are renamed to the *v+1* identifier.
  - If new columns appear at *v+1*, those columns are populated with empty defaults (matching today's behavior for added columns).
  - If columns are removed at *v+1*, they are stripped (today there are none, but the runner handles it).
  - If a discipline has no entry at *v* but does at *v+1*, no operation runs for that discipline at this step (it was introduced at *v+1*; there is nothing to migrate from *v*).
  - If a discipline has an entry at *v* but none at *v+1*, the discipline was retired; rows belonging to it are dropped. (Not used today; included in the contract for completeness.)
- The today-special-case `userOffsetMs → meanOffsetMs` value transform in `V2ToV3Migration` is handled by allowing a per-step *value transform* hook in the history entry — see AC 3.

### AC 3: Value transforms have a per-history hook

**Given** the existing v2→v3 migration's `userOffsetMs → meanOffsetMs` rename-with-fallback (`migrated["meanOffsetMs"] = migrated["meanOffsetMs"] ?? userOffset`)
**When** ported to the new contract
**Then** the discipline declares the value transform alongside its v3 history entry — for example:

```swift
.init(version: 3, trainingType: "continuousRhythmMatching",
      columns: ["meanOffsetMs", "meanOffsetMsPosition0", …],
      valueTransformsFromPrevious: [
          .renameColumnWithFallback(from: "userOffsetMs", to: "meanOffsetMs")
      ]),
```

The exact name and shape of the `valueTransformsFromPrevious` API is dev's call. The test is that:

- The transform is owned by the discipline that consumes the renamed column (not a central enum).
- The transform list is empty for the common case (column add/rename via header diff is enough).
- A discipline can declare arbitrary value transforms without the runner growing a switch.

### AC 4: Central migration files deleted

**Given** `Peach/Core/Data/V1ToV2Migration.swift` and `Peach/Core/Data/V2ToV3Migration.swift`
**When** inspected after this story
**Then** they are deleted. `Peach/Core/Data/CSVFormatMigration.swift` either survives (if its `CSVMigrationChain` is reduced to "ask each discipline for its history; iterate") or is replaced by an equivalent file inside `Peach/Core/Data/` whose body never names a discipline.

### AC 5: Strict zero-hits in `Peach/Core/Data/`

**Given** `Peach/Core/Data/`
**When** grepped for any specific discipline name (`unisonPitch`, `intervalPitch`, `rhythm`, `timingOffset`, `continuousRhythm`, `pitchComparison`, `pitchDiscrimination`, `pitchMatching`)
**Then** zero hits remain. Combined with 77.4's AC 10, `Peach/Core/Data/` is fully free of discipline-specific names.

### AC 6: CSV import round-trip tests pass

**Given** the existing CSV import round-trip tests for v1, v2, and v3 inputs across all six disciplines (the four pitch + the two timing disciplines under `--research`)
**When** run after this story
**Then** every test passes unmodified. The tests are the load-bearing safety net: if a discipline's history is wrong, a v1 input that should round-trip will fail.

### AC 7: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run
**Then** all four configurations pass with zero new warnings. `bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

## Tasks / Subtasks

- [x] Task 1: Design the history type and runner contract (AC: 1, 2, 3)
  - [x] 1.1 Read `V1ToV2Migration.swift`, `V2ToV3Migration.swift`, `CSVFormatMigration.swift`, and the four `<Feature>Discipline.swift` files. Catalog every operation: trainingType renames, column adds, column drops (none today), value transforms (one today: userOffsetMs → meanOffsetMs).
  - [x] 1.2 Decide the shape of `CSVHistory` / `CSVHistoryEntry` and the per-step `valueTransformsFromPrevious` hook. Write a paragraph in Dev Notes explaining the choice (e.g., "history-of-snapshots, runner diffs adjacent" vs. "history-of-deltas, runner concatenates"). The user has a strong stated preference for the snapshot-and-derive shape — use it unless there is a concrete reason it cannot work.
  - [x] 1.3 Add the `csvHistory` member to the `TrainingDiscipline` protocol with no default. (Every discipline must declare its history; absence is the bug.)

- [x] Task 2: Author each discipline's history (AC: 1, 3)
  - [x] 2.1 `PitchDiscrimination`: v1 (`pitchComparison`, columns), v2 (`pitchDiscrimination`, same columns).
  - [x] 2.2 `PitchMatching`: v1 entry (no rename through v3).
  - [x] 2.3 `TimingOffsetDetection` (was `RhythmOffsetDetection`): trace its CSV identity through v1/v2/v3. v2 added `tempoBPM` and `offsetMs`; verify whether the discipline existed at v1 (the `V1ToV2Migration` adds `tempoBPM`/`offsetMs`/`userOffsetMs` with empty defaults — this implies *some* rhythm discipline was emitting rows at v1 that had to be brought up to v2 shape, or that the v2 runner pre-emptively widened all rows. Walk the actual schema files to settle this and document the answer.).
  - [x] 2.4 `ContinuousRhythmMatching`: v3 entry only (introduced at v3). Carries the `userOffsetMs → meanOffsetMs` value transform on its v3 entry.

- [x] Task 3: Implement the runner (AC: 2, 4)
  - [x] 3.1 Replace `CSVMigrationChain.migrations` with a runner that, for each (v, v+1) step, asks every history (from `CSVHistoryRegistry.shared`) for its v→v+1 deltas and applies them.
  - [x] 3.2 Confirm the runner produces *exactly* the same row outputs as the current `V1ToV2Migration` + `V2ToV3Migration` pipeline does today, for the same inputs.
  - [x] 3.3 Delete `V1ToV2Migration.swift` and `V2ToV3Migration.swift`.

- [x] Task 4: Verify (AC: 5, 6, 7)
  - [x] 4.1 Grep `Peach/Core/Data/` for each specific discipline name. Expected: zero hits.
  - [x] 4.2 Run all four test configurations. Confirm CSV import round-trip tests pass.
  - [x] 4.3 Build all four configurations; zero new warnings.

## Dev Notes

### Why history+derivation, not per-step contributions

The user articulated this directly in the architecture session: "we're doing a refactor that makes adding a discipline a one-directory operation; it should not require touching three files just because the CSV format has been versioned three times." Per-step contributions force one new entry per discipline per version pair. History+derivation keeps the per-discipline footprint constant: one history declaration that grows by one entry only when the discipline's CSV identity actually changes.

It also matches how a developer reasons about the data: "PitchDiscrimination was called `pitchComparison` until v2" is one fact, not three deltas. Reading a discipline's history reads as a timeline; reading per-step contributions reads as a checklist of book-keeping.

### Composition order

Within a step (*v* → *v+1*), per-discipline contributions are independent. Across steps, they are ordered: a CSV at v1 imported into a v3-aware app applies v1→v2 transforms, *then* v2→v3 transforms, in that order. The runner's contract: for each adjacent (sourceVersion, targetVersion) step from input version up to current version, collect contributions from all disciplines and apply them; then advance.

### Disciplines that didn't exist at sourceVersion

`ContinuousRhythmMatching` was introduced in CSV v3 (epic 54). Its history starts at v3. For any v1-to-v3 or v2-to-v3 migration, the runner sees no v1 or v2 entry and produces no operation for it at the v1→v2 or v2→v3 steps. Rows whose `trainingType` has been renamed *into* `continuousRhythmMatching` (today: from `rhythmMatching` at v2→v3) are still handled — that rename is on the *retiring* discipline's history (or, if no discipline retires the old `rhythmMatching` identifier, the rename is owned by the new identifier's history; the per-discipline ownership is dev's call as long as the row ends up renamed exactly once).

### Walking through today's behavior

To verify the runner's output equals today's, trace through the two existing migrations:

- `V1ToV2Migration`:
  - Renames `pitchComparison` → `pitchDiscrimination` (PitchDiscrimination's v1→v2 trainingType change).
  - Adds `tempoBPM`, `offsetMs`, `userOffsetMs` columns with empty defaults (these are timing-discipline columns added at v2).
- `V2ToV3Migration`:
  - Renames `rhythmMatching` → `continuousRhythmMatching` (this rename moves rows from a retired identifier into the new CRM identifier; either CRM's v3 entry owns it or there's a sentinel "retired identifier `rhythmMatching` is now `continuousRhythmMatching`" mechanism — design choice).
  - Maps `userOffsetMs` → `meanOffsetMs` with fallback (CRM v3 value transform).
  - Adds `meanOffsetMsPosition0..3` columns with empty defaults (CRM v3 columns).

The new runner must reproduce all of these. The trickiest case is the `rhythmMatching → continuousRhythmMatching` rename, because there is no discipline named `RhythmMatching` in the current codebase — it was retired during epic 54 and replaced by CRM. Two reasonable shapes:

1. CRM's v3 entry declares `previousTrainingType: "rhythmMatching"` (pointing at the retired identifier). The runner translates this into a rename operation at the v2→v3 step.
2. A separate, smaller mechanism — a registry of retired identifiers — collects identity-rename hints. Less clean; only worth introducing if shape 1 hits a wall.

Default to shape 1 unless implementation reveals a problem.

### What this story is NOT

- Not a CSV format change. The wire format stays at v3.
- Not a SwiftData schema change. Story 77.4 dissolves the SwiftData side; this story only touches CSV.
- Not a redesign of `TrainingDataImporter` beyond removing the central migration enumeration.
- Not a generalized data-migration framework. The contract is specific to CSV row dictionaries.

### References

- Story 77.3 — relocated `@Model` record bodies and CSV row parsers into feature directories. Deferred this work.
- Story 77.4 — JSON envelope storage redesign. Provides the payload structs that the CSV importer / exporter round-trip through; this story builds on top.
- `Peach/Core/Data/V1ToV2Migration.swift`, `Peach/Core/Data/V2ToV3Migration.swift` — the targets to delete.
- `Peach/Core/Data/CSVFormatMigration.swift` — the protocol and chain to either repurpose or replace.
- `Peach/Core/Training/Discipline/TrainingDiscipline.swift` — the protocol receiving the new `csvHistory` member.

## Dev Agent Record

### Implementation Plan

Snapshot-and-derive shape: each discipline (or shared group) declares a `CSVHistory` of `CSVHistoryEntry` snapshots — one per CSV format version where the discipline's identity changed. The runner inspects each history's entry at `v+1` and derives operations for the (v → v+1) step:

- trainingType rename: when the entry at `v+1` differs from the same history's previous entry.
- previous-identifier rename (retired discipline import): when a history first appears at `v+1` and declares `previousTrainingType`.
- value transforms: any `CSVValueTransform` declared on the `v+1` entry (currently used only for the `userOffsetMs → meanOffsetMs` rename-with-fallback at v3).

Column adds/drops are handled implicitly by `CSVImportParser.parseMigratedLines`, which reconstructs each row against the union of registry-declared columns and any keys present in the migrated rows.

### Decoupling histories from active disciplines

The migration runner cannot read `TrainingDisciplineRegistry.shared`: in non-research builds, timing disciplines are excluded from the registry, but a v2 CSV containing `rhythmMatching` rows must still migrate to v3 shape regardless. A separate `CSVHistoryRegistry` is bootstrapped at app startup with `DisciplineBootstrap.allCSVHistories` — the union of all known histories, NOT gated by `PEACH_RESEARCH`. The histories themselves live as static enums (`PitchDiscriminationCSVHistory.history`, `PitchMatchingCSVHistory.history`, `TimingOffsetDetectionCSVHistory.history`, `ContinuousRhythmMatchingCSVHistory.history`) under each feature's `Discipline/` subfolder, so they're unconditionally compiled even when the discipline they belong to is build-flag-gated out of the active list.

The `csvHistory` protocol member on `TrainingDiscipline` (Task 1.3) provides the compile-time guarantee that every new discipline declares a history; the runtime path reads only `CSVHistoryRegistry.shared.histories`.

### TimingOffsetDetection at v1

The legacy `V1ToV2Migration` added empty `tempoBPM`/`offsetMs`/`userOffsetMs` columns to all v1 rows — pre-emptively widening the row dictionary so the v2 schema was satisfied. The schema files confirm no rhythm discipline existed at v1; the v1→v2 migration simply added the columns to a pure-pitch v1 CSV in anticipation of v2's rhythm columns. In the new contract, `TimingOffsetDetectionCSVHistory` declares its first entry at v2 (as `rhythmOffsetDetection`); column reconstruction in `parseMigratedLines` already produces empty defaults for any column declared in the registry but missing from a row, so explicit empty-default operations are unnecessary.

### Completion Notes

- `CSVFormatMigration` protocol removed; `CSVMigrationChain` is now a single 70-line file that derives all operations from `CSVHistoryRegistry.shared`.
- `V1ToV2Migration.swift` and `V2ToV3Migration.swift` deleted (AC 4).
- AC 5 (zero discipline names in `Peach/Core/Data/`) verified via grep.
- AC 6 (round-trip tests) — full suite pass on all four configurations.
- AC 7 — all four configurations green; iOS build clean (1 pre-existing AppIntents warning).

## File List

### New
- `Peach/Core/Training/Discipline/CSVHistory.swift` — `CSVHistory`, `CSVHistoryEntry`, `CSVValueTransform` types.
- `Peach/Core/Training/Discipline/CSVHistoryRegistry.swift` — bootstrapped registry of all known CSV histories, decoupled from the discipline registry.
- `Peach/Training/PitchDiscrimination/Discipline/PitchDiscriminationCSVHistory.swift` — shared by Unison + Interval pitch discrimination (v1 `pitchComparison`, v2 `pitchDiscrimination`).
- `Peach/Training/PitchMatching/Discipline/PitchMatchingCSVHistory.swift` — shared by Unison + Interval pitch matching (single v1 entry).
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionCSVHistory.swift` — v2 entry only (`rhythmOffsetDetection`).
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingCSVHistory.swift` — v3 entry with `previousTrainingType: "rhythmMatching"` and `userOffsetMs → meanOffsetMs` value transform.

### Modified
- `Peach/Core/Data/CSVFormatMigration.swift` — replaced `CSVFormatMigration` protocol + per-version migration list with history-derived `CSVMigrationChain`.
- `Peach/Core/Training/Discipline/TrainingDiscipline.swift` — added `csvHistory: CSVHistory` protocol requirement.
- `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift`, `IntervalPitchDiscriminationDiscipline.swift` — return `PitchDiscriminationCSVHistory.history`.
- `Peach/Training/PitchMatching/Discipline/UnisonPitchMatchingDiscipline.swift`, `IntervalPitchMatchingDiscipline.swift` — return `PitchMatchingCSVHistory.history`.
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` — return `TimingOffsetDetectionCSVHistory.history`.
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift` — return `ContinuousRhythmMatchingCSVHistory.history`.
- `Peach/App/Training/DisciplineBootstrap.swift` — added `allCSVHistories` (union of all histories, not build-flag-gated).
- `Peach/App/PeachApp.swift` — bootstrap `CSVHistoryRegistry` alongside `TrainingDisciplineRegistry`.
- `Peach/App/PreviewSupport.swift` — bootstrap `CSVHistoryRegistry` for previews.
- `PeachTests/Core/Data/CSVFormatMigrationTests.swift` — rewritten against `CSVMigrationChain.migrate(...)`; suite renamed to "CSVMigrationChain".
- `PeachTests/Core/Training/RegistryActiveCategoriesTests.swift`, `RegistryContributionsTests.swift` — added `csvHistory` to synthetic discipline fixtures.
- `docs/implementation-artifacts/sprint-status.yaml` — story status `ready-for-dev` → `review`.

### Deleted
- `Peach/Core/Data/V1ToV2Migration.swift`
- `Peach/Core/Data/V2ToV3Migration.swift`

## Change Log

- 2026-04-28: Drafted as the CSV migration follow-up to 77.3, redesigned around history+derivation per the architect/dev session. Supersedes the earlier 77.6 draft (which framed the work as per-step contributions). Status → ready-for-dev.
- 2026-04-28: Implemented. Migration runner derived from `CSVHistoryRegistry`, decoupled from `TrainingDisciplineRegistry` so v2 → v3 migrations work in non-research builds. All four configurations green. Status → review.

# Story 77.8: Typed `Payload` associated type on `TrainingDiscipline`

Status: review

## Story

As **a developer maintaining the discipline protocol surface**,
I want `TrainingDiscipline` to expose its concrete `Payload` type via an `associatedtype Payload: TrainingDisciplinePayload`,
so that `parsedRecords(from:)` and other payload-shaped APIs return concrete `[(Date, Payload)]` instead of `[(Date, any TrainingDisciplinePayload)]`, and the four discipline implementations stop carrying `as? PitchDiscriminationPayload` / `as? PitchMatchingPayload` / etc. dance to recover the type the caller already knows.

## Background

After 77.4, `TrainingDiscipline` declares (paraphrased):

```swift
func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: any TrainingDisciplinePayload)]
```

Every conforming implementation immediately downcasts to its own concrete payload:

```swift
.filter { ($0.payload as? PitchDiscriminationPayload)?.interval == 0 }
```

and again inside `mergeImportRecords`:

```swift
guard let p = entry.payload as? PitchDiscriminationPayload else { continue }
```

The downcasts cannot fail in practice — the discipline's own CSV parser is what produced the entries — but they add lines and hide the static type from the compiler. The existential is necessary at the **registry boundary** (the registry stores `[any TrainingDiscipline]`) but unnecessary inside the discipline itself.

77.4's review surfaced this finding and deferred it because adopting an associated type ripples through the registry's existential storage and is a discrete design question rather than a mechanical cleanup.

## Acceptance Criteria

### AC 1: `TrainingDiscipline` declares a typed `Payload`

**Given** `Peach/Core/Training/Discipline/TrainingDiscipline.swift`
**When** inspected after this story
**Then** the protocol declares `associatedtype Payload: TrainingDisciplinePayload` and exposes it on the relevant payload-shaped API (`parsedRecords(from:)`, plus any other method the design surfaces). The four conforming implementations declare their `Payload` (typically inferred from the return type).

### AC 2: Existential casts removed from feature implementations

**Given** the four discipline files under `Peach/Training/<Feature>/Discipline/`
**When** inspected
**Then** there is no `as? <FeaturePayload>` cast inside `parsedRecords`, `mergeImportRecords`, or any other payload-shaped method. The compiler enforces the type. (Remaining `as?` calls only for legitimate downcasts, e.g., decoding CSV rows where the row type is genuinely a sum type.)

### AC 3: Registry boundary still works

**Given** `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` stores `[any TrainingDiscipline]`
**When** the registry iterates all disciplines for cross-cutting operations (CSV column collection, parser dispatch, `feedAllRecords`, etc.)
**Then** it still works — either:

- the cross-cutting operations move behind type-erased helpers that take the existential and call a uniform method on it, or
- the operations live behind protocol extensions that internally hold the existential,

whichever shape comes out cleanest. Document the chosen pattern in Completion Notes.

### AC 4: No external API broken

**Given** App-layer call sites (the registry, composition root, settings/profile coordinators, observer bootstrap)
**When** inspected
**Then** none of them name a discipline's concrete `Payload` type just to satisfy the protocol — the existential continues to suffice at the registry boundary, and no caller is forced into a generic context just to call a registry method.

### AC 5: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all tests pass under all four configurations. `bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

## Tasks / Subtasks

- [x] Task 1: Survey existential touch points (AC: 1, 3)
  - [x] 1.1 List every method on `TrainingDiscipline` that traffics payloads in or out (`parsedRecords`, `mergeImportRecords`, `feedRecords`, etc.).
  - [x] 1.2 List every registry call site that iterates `[any TrainingDiscipline]` and invokes a payload-shaped method. Identify which calls actually need the concrete type vs. which only need a type-erased uniform return shape.

- [x] Task 2: Add the associated type and migrate signatures (AC: 1)
  - [x] 2.1 Add `associatedtype Payload: TrainingDisciplinePayload` to `TrainingDiscipline`.
  - [x] 2.2 Update method signatures that should return concrete `Payload` (typically `parsedRecords` and the merge helpers).
  - [x] 2.3 Provide protocol extensions that compose the existential boundary for registry-level callers.

- [x] Task 3: Drop existential casts (AC: 2)
  - [x] 3.1 Remove every now-unnecessary `as? <FeaturePayload>` from the four discipline implementations.
  - [x] 3.2 Replace `compactMap { ($0 as? P).map { … } }` patterns in helpers (e.g. `ExportChartViewTests` helpers, `MergeImport`-style tests) with direct typed access where possible.

- [x] Task 4: Coordinate with 77.7 if it lands first (AC: 2)
  - [x] 4.1 If 77.7 introduced a merge helper that takes `[(Date, any TrainingDisciplinePayload)]`, retighten its signature to take `[(Date, P)]`.
  - [x] 4.2 If 77.7 has not landed yet, this story unblocks 77.7's existential-cast removal.
  - [x] 4.3 Consider adding `associatedtype DuplicateKey: Hashable` so 77.7's `mergeImportPayloads` ties its `K` to `P` at the type level instead of accepting any `K: Hashable`. Defer if it conflicts with the registry's existential boundary.

- [x] Task 5: Build/test (AC: 5)
  - [x] 5.1 All four test configurations green.
  - [x] 5.2 Build: zero new warnings.

## Dev Agent Record

### Completion Notes

**AC1 — Typed `Payload` on `TrainingDiscipline`.** Added `associatedtype Payload: TrainingDisciplinePayload` and retyped every payload-shaped method (`csvKeyValuePairs(for:)`, `parseCSVRow(...)`, `fetchExportRecords`, `parsedRecords`) to use `Payload`. The six conforming disciplines (4 pitch + 2 rhythm) infer their `Payload` from method return types — no explicit `typealias` required.

**AC2 — Casts removed.** All `as? <FeaturePayload>` casts in `parsedRecords` and `mergeImportRecords` are gone. The single remaining cast at the parser→discipline boundary lives in `TrainingDisciplinePayloads.typedEntries(...)` (a generic helper that filters the parser's heterogeneous payload map by both training type and concrete payload type) — this is the legitimate sum-typed boundary the story spec calls out.

**AC3 — Registry boundary preserved via existential-callable extensions.** The registry still stores `[any TrainingDiscipline]`. Three protocol extensions on `TrainingDiscipline` expose only existential or concrete value types in their visible signatures, so they remain callable on the existential without exposing `Payload`:

- `parseCSVRowErased(...)` — for `CSVImportParser`'s heterogeneous result map
- `csvRows(from:)` — for `TrainingDataExporter` (combines `fetchExportRecords` + `csvKeyValuePairs`)
- `parsedRecordEnvelopes(from:)` — for `TrainingDataImporter`'s replace path (combines `parsedRecords` + `JSONEnvelope.encode`)

Internally, each extension calls the discipline's typed primitive(s) and erases the result. Cross-cutting iteration in `TrainingDataExporter`, `CSVImportParser`, and `TrainingDataImporter.replaceAll` was rewired to use these helpers.

**AC4 — App-layer untouched.** No call site outside `Core/Data` and `Core/Training` was modified. No caller is forced into a generic context.

**AC5 — Green.** All four test configurations pass: 1462 (iOS), 1456 (macOS), 1806 (iOS research), 1799 (macOS research). Both builds succeed with zero new warnings.

**Subtask 4.3 — `associatedtype DuplicateKey` deferred.** Considered and rejected for this story. `mergeImportPayloads<P, K>` already infers `K` from its closure; surfacing `DuplicateKey` on the protocol would mean every conformer (including the synthetic test fixtures) would have to declare a key type that the protocol does not actually consume — the protocol does not call `keyBuilder`; the discipline's own `mergeImportRecords` does. Adding the constraint would be protocol noise without preventing real bugs. The current shape — a generic `K: Hashable` inferred at the call site — is the right level of abstraction.

**Simplify-code findings applied.**
- `parsedRecordEnvelopes` originally returned `(envelopes: [TrainingRecord], count: Int)` and used `.map`. Both noted by the simplify reviewers: the count duplicates `envelopes.count`, and `.map` keeps the parsed array and envelopes array in memory simultaneously per discipline. Replaced `.map` with a `reserveCapacity` loop that encodes one record at a time, and dropped the redundant count.

**Findings consciously deferred.**
- `buildPitchDuplicateKeys` / `buildRhythmDuplicateKeys` consolidation into a generic helper — outside 77.8 scope; this would touch 77.7-area code and warrant its own story if pursued.
- `csvTrainingType` stringly-typed wire identifier — pre-existing public/wire contract; not a 77.8 concern.

### File List

Modified:
- `Peach/Core/Training/Discipline/TrainingDiscipline.swift`
- `Peach/Core/Training/Discipline/TrainingDisciplinePayload.swift`
- `Peach/Core/Data/CSVImportParser.swift`
- `Peach/Core/Data/TrainingDataExporter.swift`
- `Peach/Core/Data/TrainingDataImporter.swift`
- `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift`
- `Peach/Training/PitchDiscrimination/Discipline/IntervalPitchDiscriminationDiscipline.swift`
- `Peach/Training/PitchDiscrimination/Discipline/PitchDiscriminationCSVParser.swift`
- `Peach/Training/PitchMatching/Discipline/UnisonPitchMatchingDiscipline.swift`
- `Peach/Training/PitchMatching/Discipline/IntervalPitchMatchingDiscipline.swift`
- `Peach/Training/PitchMatching/Discipline/PitchMatchingCSVParser.swift`
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift`
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift`
- `PeachTests/Core/Training/RegistryActiveCategoriesTests.swift` (added `SyntheticPayload`; retyped `SyntheticDiscipline`)
- `PeachTests/Core/Training/RegistryContributionsTests.swift` (retyped `SyntheticUIDiscipline`)
- `docs/implementation-artifacts/sprint-status.yaml`

## Dev Notes

### Why this is its own story

The associated-type adoption is small in *lines changed* but large in *design decision*: it commits the registry boundary to an existential pattern that may need helpers (`some TrainingDiscipline`-style closures, type-erased wrappers, or protocol-extension dispatch). 77.4 was already a large refactor; deferring this question avoided coupling the envelope-storage decision to a registry-shape decision.

### Why the registry must keep storing existentials

Heterogeneous storage (`[any TrainingDiscipline]`) is what makes cross-cutting iteration possible: the registry hands the App layer a uniform list it can render in nav, settings, profile cards, etc. Adopting `associatedtype Payload` does not change that — it only sharpens the *internal* surface of each discipline. The registry stays as-is; the disciplines lose their casts.

### What this story is NOT

- Not a registry redesign. The `[any TrainingDiscipline]` storage stays.
- Not a removal of `any TrainingDisciplinePayload`. Some helpers (e.g., test fixtures, the CSV parser's intermediate result) legitimately need the existential and keep it.
- Not a `JSONEnvelope` redesign. `JSONEnvelope.encode<P: TrainingDisciplinePayload>` is already correctly generic.

### References

- `Peach/Core/Training/Discipline/TrainingDiscipline.swift` — protocol where the `associatedtype` lands.
- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` — existential storage and cross-cutting iteration.
- `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift` (and three siblings) — the cast-and-filter sites that disappear.
- Story 77.4 — review surfaced this finding and deferred it.
- Story 77.7 — coordinates if it lands first; either order works.

## Change Log

- 2026-04-28: Drafted as a deferred 77.4 review finding. Status → ready-for-dev.
- 2026-04-29: Added subtask 4.3 to consider an associated `DuplicateKey` constraint on `TrainingDiscipline` (deferred from 77.7 review).
- 2026-04-29: Implemented. `TrainingDiscipline` now carries `associatedtype Payload`; six discipline conformers retyped; three existential-callable protocol extensions (`parseCSVRowErased`, `csvRows`, `parsedRecordEnvelopes`) bridge the registry boundary; `TrainingDisciplinePayloads.typedEntries` isolates the one legitimate parser→discipline cast. Subtask 4.3 considered and deferred (rationale in Completion Notes). Status → review.

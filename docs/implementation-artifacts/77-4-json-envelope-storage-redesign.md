# Story 77.4: JSON envelope storage redesign

Status: ready-for-dev

## Story

As **a developer maintaining Peach's persistence layer**,
I want training records stored as a single SwiftData envelope `@Model` (`TrainingRecord`) carrying a `disciplineIdentifier`, `timestamp`, `payloadVersion`, and a `Data` payload that each discipline encodes/decodes itself,
so that adding or evolving a discipline does not require editing a central SwiftData schema, and the only file that names a SwiftData entity is the envelope itself.

## Background

After 77.3, every discipline's `@Model` record body lives under `Peach/Training/<Feature>/Discipline/`, but the SwiftData schema still aggregates them in two central places:

- `Peach/Core/Data/PeachSchema.swift` — `SchemaV1.models` lists the four concrete record types.
- `Peach/Core/Data/TrainingDataStore.swift` — generic CRUD over `T: PersistentModel`, with `deleteAll()` / `replaceAllRecords(_:)` iterating `TrainingDisciplineRegistry.shared.recordTypes`.

These two surfaces force every new discipline to register a `@Model` type at SwiftData's schema-bootstrap time (before the registry is wired up — see `PeachSchema.swift`'s bootstrap-order constraint). They are also the reason `Timestamped` conformance has to be declared via the top-level typealias rather than directly on `extension SchemaV1.FooRecord`, which has been a recurring trap.

The architect/dev discussion that produced this story established that:

1. **Peach uses SwiftData as a key-value store, not as a relational DB.** The whole project contains zero `#Predicate` uses; `TrainingDataStore` only ever does `FetchDescriptor<T>()` (full fetch) and inserts. There are no joins, no inner-property queries, no derived indexes.
2. **There are no deployed users.** The app is on Michael's devices only — TestFlight has not been uploaded yet (`72-1-archive-and-upload-first-build-to-testflight: ready-for-dev`). No schema migration is needed; the existing four `@Model` types can simply be replaced.
3. **The envelope dissolves the colocation seams.** A single `@Model TrainingRecord` envelope means: `SchemaV1.models` contains exactly one type forever; `TrainingDataStore` is non-generic over discipline; `TrainingDiscipline.recordType` is gone; the `extension SchemaV1 { @Model … }` / typealias / `Timestamped`-via-typealias dance is gone.
4. **CSV is unchanged at the wire level.** This story does not touch the CSV format or migration logic. Story 77.5 redesigns the CSV migration plugin contract on top of the new payload structs.

## Acceptance Criteria

### AC 1: Single envelope `@Model`

**Given** `Peach/Core/Data/`
**When** inspected after this story
**Then** there is exactly one `@Model` declaration in the project: `TrainingRecord` in `Peach/Core/Data/TrainingRecord.swift` (or equivalent), with at least these fields:

```swift
@Model final class TrainingRecord {
    var disciplineIdentifier: String  // e.g. "pitchDiscrimination"
    var timestamp: Date
    var payloadVersion: Int
    var payloadData: Data             // discipline-encoded JSON
    init(disciplineIdentifier: String, timestamp: Date, payloadVersion: Int, payloadData: Data) { … }
}
```

`TrainingRecord` conforms to `Timestamped` directly (no typealias hop).

### AC 2: SchemaV1 contains only the envelope

**Given** `Peach/Core/Data/PeachSchema.swift`
**When** inspected
**Then** `SchemaV1.models` is `[TrainingRecord.self]` — a single line that will never need to be touched when adding a discipline. The bootstrap-order rationale documented in `PeachSchema.swift` is updated to reflect that the schema no longer enumerates discipline-specific types.

### AC 3: Each discipline contributes a Codable payload

**Given** each of the four existing disciplines (`PitchDiscrimination`, `PitchMatching`, `TimingOffsetDetection`, `ContinuousRhythmMatching`)
**When** inspected
**Then** the discipline's feature directory contains a `struct <Feature>Payload: TrainingDisciplinePayload, Codable` declaration carrying the same fields the previous `@Model` class carried (e.g., `PitchDiscriminationPayload` carries `referenceNote`, `targetNote`, `centOffset`, `isCorrect`, `interval`, `tuningSystem`). Field names are preserved verbatim so JSON keys are stable.

`TrainingDisciplinePayload` is a new protocol in `Peach/Core/Training/Discipline/` declaring at minimum:

```swift
protocol TrainingDisciplinePayload: Codable, Sendable {
    static var disciplineIdentifier: String { get }
    static var currentPayloadVersion: Int { get }
}
```

The existing four payload types all return `currentPayloadVersion = 1` (this is the V1 schema; payload versioning will earn its keep when a discipline's struct evolves).

### AC 4: `extension SchemaV1 { @Model … }` declarations and typealiases are gone

**Given** the four files `Peach/Training/<Feature>/Discipline/<Feature>Record.swift`
**When** inspected
**Then** they no longer contain `extension SchemaV1 { @Model final class … }` blocks, top-level typealiases (`typealias FooRecord = SchemaV1.FooRecord`), or `extension FooRecord: Timestamped {}` declarations. The files either:

- become the home of the new payload struct (preferred, file renamed to `<Feature>Payload.swift`), or
- are deleted and a new `<Feature>Payload.swift` file is created alongside.

The `RhythmOffsetDetectionRecord` legacy SwiftData entity name disappears entirely — there is no SwiftData entity to keep stable across this rename, so `TimingOffsetDetectionPayload` uses the current public name without compatibility hops.

### AC 5: Store adapters mediate envelope ↔ payload

**Given** each of the four `<Feature>StoreAdapter.swift` files (e.g., `PitchDiscriminationStoreAdapter.swift`)
**When** inspected
**Then** the adapter is the only place that knows how to:

- encode a fresh payload + `Date` into a `TrainingRecord` envelope and call `TrainingDataStore.save(_:)`,
- fetch envelopes filtered to its discipline (`disciplineIdentifier == Self.Payload.disciplineIdentifier`) and decode them into payload structs.

A small shared helper (e.g., `extension TrainingDataStore { func fetchPayloads<P: TrainingDisciplinePayload>(_:) throws -> [(timestamp: Date, payload: P)] }`) is acceptable and encouraged; the discipline-specific knowledge stays in the adapter.

### AC 6: `TrainingDataStore` is discipline-agnostic

**Given** `Peach/Core/Data/TrainingDataStore.swift`
**When** inspected
**Then** the public surface no longer takes generic `T: PersistentModel` parameters that imply per-discipline `@Model` types. Specifically:

- `deleteAll()` and `replaceAllRecords(_:)` no longer iterate `TrainingDisciplineRegistry.shared.recordTypes`; they delete `TrainingRecord` (the only model type) once.
- `fetchAll<T>(_:)`, `fetchAllSorted<T>(_:)`, `deleteAll<T>(_:)` either disappear or are reduced to envelope-scoped variants. Callers that previously asked for `fetchAll(PitchDiscriminationRecord.self)` go through the adapter's `fetchPayloads` helper instead.
- The store no longer reads from `TrainingDisciplineRegistry`. The registry no longer needs to expose `recordTypes`.

### AC 7: `TrainingDiscipline` protocol no longer references `PersistentModel`

**Given** `Peach/Core/Training/Discipline/TrainingDiscipline.swift`
**When** inspected
**Then** `var recordType: any PersistentModel.Type` is removed. The protocol's data-layer touchpoints (`feedRecords(from:into:)`, `fetchExportRecords(from:)`, `parsedRecords(from:)`, `mergeImportRecords(from:existingIn:into:)`) operate on payload structs instead. Specifically:

- `feedRecords` reads the discipline's payloads via the adapter and feeds them into the profile builder.
- `fetchExportRecords` returns `[(timestamp: Date, payload: any TrainingDisciplinePayload)]` (or similar — exact signature is dev's call as long as it is `PersistentModel`-free).
- `parsedRecords` and `mergeImportRecords` consume CSV-parsed payload structs, not `any PersistentModel`. Duplicate detection (used by `mergeImportRecords`) is implemented per discipline against its own payload struct's identity fields, exactly as today.

### AC 8: Imports and tests follow

**Given** every consumer of the four old `@Model` record types (sessions, observers, store adapters, exporters, importers, tests)
**When** updated
**Then** they consume payload structs. Sessions persist via the adapter; profile/statistics consumers receive payload structs from the adapter; tests construct payload structs directly. No file outside `Peach/Core/Data/TrainingRecord.swift` references SwiftData `@Model` declarations or the four old record types.

### AC 9: No deployed-user migration

**Given** the app has no deployed users (TestFlight not yet uploaded; TestFlight upload in `72-1-...` blocked behind the v1.0 release work)
**When** this story ships
**Then** there is **no** code that converts old SwiftData rows to envelope rows. No SwiftData migration plan beyond `SchemaV1` with the single envelope. Local dev databases are wiped on first launch of the new build (acceptable because the only existing databases are on Michael's two test devices). A one-paragraph note in Completion Notes records this intentional decision.

### AC 10: Strict zero-hits in `Peach/Core/Data/`

**Given** `Peach/Core/Data/`
**When** grepped for any specific discipline name (`unisonPitch`, `intervalPitch`, `rhythm`, `timingOffset`, `continuousRhythm`, `pitchComparison`, `pitchDiscrimination`, `pitchMatching`)
**Then** zero hits remain. (The `SchemaV1.models` exception from 77.3 is dissolved by AC 2.) The two `V*Migration.swift` files retain whatever discipline names they currently mention — story 77.5 cleans those up; this story leaves them alone.

### AC 11: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run
**Then** all four configurations pass. `bin/build.sh && bin/build.sh -p mac` produces zero new warnings. CSV import/export round-trip tests for v1, v2, and v3 inputs across all six disciplines (i.e., including the two timing disciplines under `--research`) all pass against the new payload structs.

## Tasks / Subtasks

- [ ] Task 1: Define the envelope and payload protocol (AC: 1, 3)
  - [ ] 1.1 Create `Peach/Core/Data/TrainingRecord.swift` with the `@Model TrainingRecord` envelope and direct `Timestamped` conformance.
  - [ ] 1.2 Create `Peach/Core/Training/Discipline/TrainingDisciplinePayload.swift` with the `TrainingDisciplinePayload: Codable, Sendable` protocol carrying `disciplineIdentifier` and `currentPayloadVersion`.
  - [ ] 1.3 Add a small encoder/decoder helper (e.g., `JSONEnvelope`) for `Payload ↔ Data` conversion. Use `JSONEncoder` / `JSONDecoder` with sortedKeys output (deterministic ordering aids future debugging) and ISO-8601 dates if a payload ever embeds a `Date` (none do today).

- [ ] Task 2: Create payload structs for the four disciplines (AC: 3, 4)
  - [ ] 2.1 `PitchDiscriminationPayload` with the same fields as `PitchDiscriminationRecord`.
  - [ ] 2.2 `PitchMatchingPayload` with the same fields as `PitchMatchingRecord`.
  - [ ] 2.3 `TimingOffsetDetectionPayload` with the same fields as `RhythmOffsetDetectionRecord`. Use the public name (no `RhythmOffsetDetection*` legacy hop).
  - [ ] 2.4 `ContinuousRhythmMatchingPayload` with the same fields as `ContinuousRhythmMatchingRecord`.
  - [ ] 2.5 Each payload sets `currentPayloadVersion = 1`.

- [ ] Task 3: Rewrite store adapters (AC: 5)
  - [ ] 3.1 Each `<Feature>StoreAdapter.swift` exposes `save(_ payload:)`, `fetchAll() -> [(timestamp, payload)]`, and any duplicate-detection helper its session/CSV importer needs. The adapter wraps envelope encode/decode.
  - [ ] 3.2 Add (optional) shared helper on `TrainingDataStore` that fetches all envelopes filtered to a `disciplineIdentifier` and decodes them.

- [ ] Task 4: Reduce `TrainingDataStore` to envelope-only API (AC: 6)
  - [ ] 4.1 Replace `deleteAll()` body with a single `modelContext.delete(model: TrainingRecord.self)` call inside a transaction.
  - [ ] 4.2 Replace `replaceAllRecords(_:)`'s iteration of `recordTypes`. Decide whether this method survives at all: callers in CSV import already build `[TrainingRecord]` envelopes — the method may just take `[TrainingRecord]`.
  - [ ] 4.3 Remove generic `fetchAll<T>` / `fetchAllSorted<T>` / `deleteAll<T>`. If a caller still needs them after Task 5, expose envelope-typed equivalents.
  - [ ] 4.4 Remove `recordTypes` from `TrainingDisciplineRegistry`. Remove the registry dependency from `TrainingDataStore`.

- [ ] Task 5: Update `TrainingDiscipline` protocol and conformances (AC: 7)
  - [ ] 5.1 Remove `var recordType: any PersistentModel.Type` from the protocol.
  - [ ] 5.2 Reshape `feedRecords(from:into:)`, `fetchExportRecords(from:)`, `parsedRecords(from:)`, `mergeImportRecords(...)` to use payload structs. Exact signatures are dev's choice; the test is that no signature contains `PersistentModel`.
  - [ ] 5.3 Update each discipline's conformance.

- [ ] Task 6: Update sessions and consumers (AC: 8)
  - [ ] 6.1 Each `<Feature>Session.swift` (or its observer/persistence collaborator) calls the adapter's `save(_:)` with a freshly built payload struct. Remove direct `@Model` initializer calls.
  - [ ] 6.2 Profile / statistics consumers get payload structs from the adapter (via `feedRecords`).
  - [ ] 6.3 CSV exporter and importer (`TrainingDataExporter`, `TrainingDataImporter`, `CSVImportParser`) round-trip through payload structs. The CSV wire format is unchanged; column-name / parsing logic is unchanged.

- [ ] Task 7: Delete the four old `@Model` files and migrate `Timestamped` (AC: 4)
  - [ ] 7.1 Replace each `<Feature>Record.swift` with `<Feature>Payload.swift` (rename if convenient).
  - [ ] 7.2 Confirm `Timestamped` is now a property of `TrainingRecord` only (or of payload structs that need sortable behavior — but the envelope's timestamp is the canonical sort key).

- [ ] Task 8: Tests (AC: 11)
  - [ ] 8.1 Update tests that constructed `<Feature>Record(...)` directly to construct `<Feature>Payload(...)`.
  - [ ] 8.2 Add a small round-trip test per discipline: build a payload, encode it through `TrainingRecord`, decode it back, assert equality. (Defensive against silent JSON-key drift.)
  - [ ] 8.3 Run all four configurations: iOS Debug, iOS Research, macOS Debug, macOS Research.
  - [ ] 8.4 Build all four configurations: zero new warnings.

- [ ] Task 9: Document the no-migration decision (AC: 9)
  - [ ] 9.1 In Completion Notes, record: "Pre-77.4 SwiftData stores are not migrated. Acceptable because TestFlight has not been uploaded; only Michael's two test devices have any data, which is dev-test data." Cite `72-1-archive-and-upload-first-build-to-testflight` as the gate that has not been crossed.

## Dev Notes

### Why an envelope rather than per-discipline `@Model`s

Peach uses SwiftData as a key-value store: zero `#Predicate` uses, only full-table fetches, no joins. The relational features SwiftData provides aren't load-bearing here. The cost we are paying for them — a central schema enumeration, bootstrap-order constraints between schema and registry, and the `extension SchemaV1 { @Model … }` / typealias / `Timestamped`-via-typealias dance — exists only to satisfy SwiftData's expectation that every entity is statically known at schema construction.

Replacing four `@Model` types with one envelope `@Model` carrying a `Data` payload removes that expectation entirely. The envelope is the only entity SwiftData ever sees; each discipline's payload schema is its own concern, evolving via `payloadVersion` rather than a SwiftData schema migration.

This is the right shape because:

- The data is already self-contained per discipline — there are no cross-discipline relations to preserve.
- Discipline payloads are small (≤ a few dozen bytes JSON each); JSON-encode overhead is negligible at insert time and dominated by SwiftData's own overhead.
- `disciplineIdentifier` plus a single non-indexed full-table fetch matches what the code already does.

### Why no migration code

The architect/dev session confirmed:

- The app has no deployed users. The two CSV format versions (v1, v2, v3) describe data exported from earlier *builds*, not data residing in user databases. CSV imports come in via the existing CSV path and end up as freshly-encoded envelopes — no SwiftData-level migration needed.
- TestFlight upload is gated behind `72-1-...` (`ready-for-dev`). After this story lands, the first TestFlight build will use the envelope storage from day one.

If TestFlight upload happens *before* this story lands, the calculus changes; flag at the start of implementation and coordinate with `72-1`.

### What this story is NOT

- **Not a CSV format change.** Wire format stays at v3. Story 77.5 tackles the CSV migration plugin contract.
- **Not a `TrainingDiscipline` protocol redesign beyond the data-layer signatures.** UI, statistics keys, navigation destinations, help, registration — untouched.
- **Not a `TrainingDataStore` redesign.** It still does CREATE / READ / DELETE; it just stops being generic over discipline-typed `@Model`s.
- **Not a search/index/predicate feature.** If a future need surfaces (e.g., "fetch only records since X for discipline Y"), promote `disciplineIdentifier` and `timestamp` to `FetchDescriptor` predicates against the envelope. Out of scope here.
- **Not a payload-versioning system.** All four current payloads are at version 1. Adding `currentPayloadVersion: Int { get }` to the protocol is the design seat for future evolution; no version-2 payloads exist yet, so no decoder switch is needed in this story.

### How payload-versioning *will* work (sketch, not in scope)

When a future discipline ships a v2 payload struct, its decode helper does:

```swift
switch envelope.payloadVersion {
case 1: return try JSONDecoder().decode(PayloadV1.self, from: envelope.payloadData).upgraded()
case 2: return try JSONDecoder().decode(PayloadV2.self, from: envelope.payloadData)
default: throw …
}
```

This is the discipline's local concern; nothing central enumerates payload versions. Dev should keep this in mind when shaping the adapter's decode helper, but should *not* implement version-2 codepaths in this story — YAGNI.

### Bootstrap order

After this story, the bootstrap-order constraint documented in `PeachSchema.swift` (registry-after-schema) becomes uninteresting: `SchemaV1.models` is `[TrainingRecord.self]` and never grows; the registry no longer needs to expose `recordTypes`. Update the comment to reflect that.

### References

- Story 77.3 — relocated `@Model` record bodies into feature directories. This story dissolves the `extension SchemaV1` colocation pattern entirely.
- Story 77.5 — per-discipline CSV migration plugin contract. Depends on the payload structs introduced here.
- Story 72.1 — `archive-and-upload-first-build-to-testflight` (gates the no-migration decision in AC 9).
- `Peach/Core/Data/TrainingDataStore.swift` — generic CRUD to be reduced.
- `Peach/Core/Data/PeachSchema.swift` — `SchemaV1.models` to be reduced to a single entry.
- `Peach/Core/Training/Discipline/TrainingDiscipline.swift` — protocol to lose `recordType` and `PersistentModel`.

## Change Log

- 2026-04-28: Drafted as the JSON-envelope storage redesign that supersedes 77.3's two enumerated exceptions (`SchemaV1.models` aggregation and `Timestamped`-via-typealias). Status → ready-for-dev.

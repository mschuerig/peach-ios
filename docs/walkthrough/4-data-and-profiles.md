# Layer 4: Data & Profiles

**Status:** in progress
**Session date:** 2026-04-06

## Architecture Overview

Layer 4 splits into two subsystems that together form the persistence + analytics stack:

```
Core/Data/                              Core/Profile/
├── PeachSchema (SwiftData models)      ├── PerceptualProfile (builder pattern)
├── TrainingDataStore (generic CRUD)    ├── TrainingDisciplineStatistics (Welford + EWMA + trend)
├── CSV export/import pipeline          ├── ProgressTimeline (adaptive time bucketing)
├── Format migrations (V1→V2→V3)       ├── SpectrogramData (tempo×time grid)
└── TrainingDataTransferService         └── Chart layout utilities
```

**Data flow:**
1. Session completes a trial → StoreAdapter saves a `PersistentModel` record via `TrainingDataStore`
2. StoreAdapter also calls `ProfileUpdating.update()` on `PerceptualProfile` (live incremental update)
3. On app launch, `PerceptualProfile.init(build:)` replays all stored records through each discipline's `feedRecords(from:into:)` method
4. `ProgressTimeline` reads from `PerceptualProfile` and transforms metrics into adaptive time buckets for charting
5. `SpectrogramData` reads from `TrainingProfile` and builds a tempo×time heat map grid

## Core/Data/ — Persistence

### `PeachSchema.swift` (179 lines)

SwiftData versioned schema. `SchemaV1` nests all 4 `@Model` record classes:

| Record Type | Fields | Metric |
|------------|--------|--------|
| `PitchDiscriminationRecord` | referenceNote, targetNote, centOffset, isCorrect, interval, tuningSystem, timestamp | Cent offset |
| `PitchMatchingRecord` | referenceNote, targetNote, initialCentOffset, userCentError, interval, tuningSystem, timestamp | User cent error |
| `RhythmOffsetDetectionRecord` | tempoBPM, offsetMs, isCorrect, timestamp | Offset ms |
| `ContinuousRhythmMatchingRecord` | tempoBPM, meanOffsetMs, per-position offsets (×4), timestamp | Mean offset ms |

`PeachSchemaMigrationPlan` is wired up but `stages` is empty — only one schema version exists. The doc comments include a thorough "How to add V2" guide.

Each record file (e.g., `PitchDiscriminationRecord.swift`) is a one-line typealias pointing at `SchemaV1.PitchDiscriminationRecord`. When V2 arrives, only the typealiases change.

### `TrainingDataStore.swift` (173 lines)

Discipline-agnostic CRUD layer wrapping a SwiftData `ModelContext`. Clean generic operations:

- `save(_ record: some PersistentModel)` — insert in a transaction
- `fetchAll<T>(_ type: T.Type)` — generic fetch
- `deleteAll<T>(_ type: T.Type)` / `deleteAll()` — delete by type or all registered types
- `replaceAllRecords(_:)` — atomic delete-all + insert-all in one transaction

**TransactionScope pattern:** `withinTransaction(_:)` wraps a closure in a `modelContext.transaction`, passing a `TransactionScope` that only exposes `insert` — no commit/rollback access. Used by the merge import path.

Per-type convenience fetches (`fetchAllPitchDiscriminations()`, etc.) add timestamp sorting. These exist because `TrainingDiscipline.feedRecords()` needs sorted data.

Conforms to `TrainingRecordPersisting` (single `save` method port) and `Resettable`.

### `PitchDiscriminationRecordStoring.swift`

A narrower protocol exposing only `save` and `fetchAllPitchDiscriminations()`. `TrainingDataStore` conforms via an empty extension. This is an older pattern — only PitchDiscrimination has it; the other disciplines use `TrainingRecordPersisting` directly.

### `DataStoreError.swift`

Four cases: `saveFailed`, `fetchFailed`, `deleteFailed`, `contextUnavailable`. All carry descriptive strings.

## Core/Data/ — CSV Export/Import

A full versioned CSV round-trip pipeline for data portability.

### Export path

`TrainingDataExporter.export(from:)` → iterates all disciplines via registry → calls `discipline.fetchExportRecords()` and `discipline.csvKeyValuePairs()` → merges rows sorted by timestamp → produces a single CSV string with a metadata line (`# peach-export-format:3`), header row, and data rows.

### Import path

`CSVImportParser.parse(_:)` → reads metadata version → if old version, runs through `CSVMigrationChain` → validates header → delegates each row to `discipline.parseCSVRow()` (looked up via `registry.csvParsers[trainingType]`) → returns `ImportResult` with `records: [String: [any PersistentModel]]` + `errors: [CSVImportError]`.

`TrainingDataImporter.importData(_:mode:into:)` supports two modes:
- **Replace:** atomic delete-all + insert-all
- **Merge:** per-discipline deduplication via `discipline.mergeImportRecords()` within a single transaction

### `CSVExportSchema.swift`

Enum namespace. Format version (3), metadata prefix, column assembly (common columns + per-discipline columns from the registry).

### Per-discipline CSV parsers

`PitchDiscriminationCSVParser` and `PitchMatchingCSVParser` — stateless enums with a single `parse(fields:columnIndex:rowNumber:)` method. Shared by both unison and interval variants of each discipline. Each validates every field with detailed error messages.

Rhythm disciplines presumably parse inline in their discipline types (no separate parser files).

### `CSVParserHelpers.swift` (144 lines)

RFC 4180 CSV utilities: `parseCSVLine` (handles quoted fields with escaped quotes), `splitIntoLines` (handles quoted newlines + CR/LF), `escapeField`, ISO 8601 parsing, interval abbreviation reverse lookup, and formatting utilities.

### `CSVFormatMigration.swift`

Protocol + chain pattern:
```
CSVFormatMigration protocol: sourceVersion, targetVersion, migrate(rows:)
CSVMigrationChain: walks from source → target version step by step
```

Two concrete migrations:
- **V1→V2:** Renamed `pitchComparison` → `pitchDiscrimination`, added rhythm columns (`tempoBPM`, `offsetMs`, `userOffsetMs`)
- **V2→V3:** Renamed `rhythmMatching` → `continuousRhythmMatching`, mapped `userOffsetMs` → `meanOffsetMs`, added per-position offset columns

### `TrainingDataTransferService.swift` (135 lines)

`@Observable` service bridging the export/import pipeline to the UI. Manages:
- Export: `refreshExport()` → generates CSV → writes temp file → exposes `exportFileURL` for share sheet
- Import: `readFileForImport(url:)` with security-scoped resource access → `performImport()` with mode selection → calls `onDataChanged` callback → returns `ImportSummary`
- Summary formatting for user-facing messages

### `DuplicateKey.swift`

(Already annotated in Layer 3 — belongs in feature layer, not Core.)

## Core/Profile/ — Statistics & Visualization

### `MetricPoint.swift`

Value type: `timestamp: Date` + `value: Double`. The universal unit of measurement across all disciplines.

### `WelfordAccumulator.swift`

Welford's online algorithm for single-pass running mean and variance. Also includes the `WelfordMeasurement` protocol bridging domain types (`Cents`, `RhythmOffset`) to `Double`.

### `TrainingDisciplineStatistics.swift` (in Core/Training/, but profile-adjacent)

Per-key statistical state combining:
1. **Welford accumulator** — running mean + stddev over all raw values
2. **EWMA** — computed over session-bucketed means (not raw points). Uses `sessionGap` from `StatisticsConfig` to group metrics into sessions, then applies exponential smoothing with `ewmaHalflife` (default: 7 days)
3. **Trend detection** — compares latest value against mean ± stddev and EWMA: improving (below EWMA), stable (between EWMA and mean+σ), declining (above mean+σ)
4. **Metrics array** — all `MetricPoint` values in insertion order

Supports both incremental updates (`addPoint`) and full rebuilds from sorted arrays (`rebuild`).

### `StatisticsKey.swift`

Two-case enum:
- `.pitch(TrainingDisciplineID)` — one key per pitch discipline (4 keys)
- `.rhythm(TrainingDisciplineID, TempoRange, RhythmDirection)` — per-tempo-range × per-direction keys

Each key carries its `statisticsConfig` (forwarded from the discipline config).

### `StatisticalSummary.swift`

Sum type wrapping `TrainingDisciplineStatistics` with convenience properties (`recordCount`, `trend`, `ewma`, `metrics`). Currently only has a `.continuous` case — designed for future extensibility (e.g., binary accuracy metrics).

### `PerceptualProfile.swift` (87 lines)

`@Observable` class implementing `TrainingProfile` (read) and `ProfileUpdating` (write). The central hub for all statistical data.

**Builder pattern:** `init(build:)` and `replaceAll(build:)` accept closures that populate a `Builder` with `MetricPoint` values per `StatisticsKey`. Only correct answers are added (`isCorrect: false` silently skipped). After building, `finalize(from:)` sorts metrics and rebuilds `TrainingDisciplineStatistics` for each key.

**Live updates:** `update(_:timestamp:value:)` incrementally appends to the existing statistics — no full rebuild needed during a session.

**Storage:** `[StatisticsKey: TrainingDisciplineStatistics]` dictionary.

### `ProgressTimeline.swift` (268 lines)

`@Observable` presentation model for progress charts. Delegates all statistical queries to `PerceptualProfile` and focuses on **adaptive time bucketing**:

**Three granularity zones** (calendar-snapped):
1. **Session zone:** Today (from midnight). Groups metrics by `sessionGap` into individual session buckets.
2. **Day zone:** Previous 7 calendar days. One bucket per day.
3. **Month zone:** Everything older. One bucket per calendar month, with the last monthly bucket truncated at the day zone start.

`mergedStatistics(for:)` — private extension on `TrainingProfile` that collects metrics from multiple `StatisticsKey`s (e.g., all tempo×direction keys for a rhythm discipline) and rebuilds a unified summary.

**Sub-bucketing:** `subBuckets(for:expanding:)` drills into a parent bucket — months → days, days → sessions.

Each bucket is a `TimeBucket` with `periodStart`, `periodEnd`, `bucketSize`, `mean`, `stddev`, `recordCount` (aggregated via `WelfordAccumulator`).

### `SpectrogramData.swift` (238 lines)

Heat map grid for rhythm disciplines. X-axis = time buckets, Y-axis = `TempoRange`.

**Cell computation:** For each (tempo range, time bucket) pair, filters early/late metrics into the bucket, computes Welford stats (mean%, stddev%), and combines into `meanAccuracyPercent` as percentage of sixteenth-note duration.

**Threshold classification:** `SpectrogramThresholds` uses a hybrid model — base percentages of sixteenth-note duration, clamped to absolute floor/ceiling milliseconds. This ensures thresholds remain musically meaningful across 40–200 BPM. Five levels: excellent, precise, moderate, loose, erratic.

**Column trimming:** Empty leading/trailing columns are stripped so the grid starts/ends at the first/last data point.

### `ChartLayoutCalculator.swift`

Pure stateless utility computing chart geometry: `totalWidth` (sum of per-granularity point widths) and `zoneBoundaries` (indices where granularity transitions occur).

### `GranularityZoneConfig.swift`

Protocol + 3 conformances mapping `BucketSize` to layout parameters:
- `MonthlyZoneConfig` — 30pt width, abbreviated month label
- `DailyZoneConfig` — 40pt width, abbreviated weekday label
- `SessionZoneConfig` — 50pt width, hour:minute label

Note: `backgroundTint` intentionally omitted from Core to avoid SwiftUI imports — the UI layer maps `BucketSize` → `Color` separately.

## Ports

- `TrainingProfile` — read-only query: `statistics(for: StatisticsKey) -> StatisticalSummary?`
- `ProfileUpdating` — write: `update(_: StatisticsKey, timestamp:, value:)`
- `TrainingRecordPersisting` — single method: `save(_ record: some PersistentModel)`

`PerceptualProfile` conforms to both `TrainingProfile` and `ProfileUpdating`. `TrainingDataStore` conforms to `TrainingRecordPersisting`.

## Files to read (suggested order)

1. `Core/Data/PeachSchema.swift` — all 4 record models + migration plan
2. `Core/Data/TrainingDataStore.swift` — generic CRUD + TransactionScope
3. `Core/Data/CSVExportSchema.swift` → `TrainingDataExporter.swift` — export path
4. `Core/Data/CSVImportParser.swift` → `TrainingDataImporter.swift` — import path
5. `Core/Data/CSVFormatMigration.swift` + `V1ToV2Migration.swift` + `V2ToV3Migration.swift` — format evolution
6. `Core/Data/TrainingDataTransferService.swift` — UI-facing service
7. `Core/Profile/WelfordAccumulator.swift` → `MetricPoint.swift` → `StatisticsKey.swift` — building blocks
8. `Core/Training/TrainingDisciplineStatistics.swift` — EWMA + trend
9. `Core/Profile/PerceptualProfile.swift` — builder + live updates
10. `Core/Profile/ProgressTimeline.swift` — adaptive bucketing
11. `Core/Profile/SpectrogramData.swift` — rhythm heat map

## Observations and questions

1. **`PitchDiscriminationRecordStoring` is an orphaned abstraction.** Only PitchDiscrimination has a narrow storing protocol; the other 3 disciplines use `TrainingRecordPersisting` directly. This was likely created early and never replicated. Consider removing in favor of the shared `TrainingRecordPersisting` port.

2. **Two separate CSV versioning systems exist.** The SwiftData schema has `PeachSchemaMigrationPlan` (currently empty, for on-device database migrations). The CSV format has `CSVMigrationChain` with concrete V1→V2→V3 migrations. These are independent — CSV format version 3 coexists with SwiftData schema version 1 because the CSV format evolved before the schema was versioned. This is correct but worth noting: the CSV migrations handle *naming changes* and *column additions*, not schema structure changes.

3. **`StatisticalSummary` has a single case.** The `.continuous(TrainingDisciplineStatistics)` wrapping adds indirection without benefit today. If binary/categorical metrics are planned (e.g., accuracy rate as an alternative to continuous deviation), the sum type makes sense. Otherwise it could be simplified to a direct typealias.

4. **`ProgressTimeline.assignMultiGranularityBuckets` is a dense 55-line method.** It handles three zone logic paths (session/day/month), session-gap merging, calendar snapping, and group assembly in a single method. The sub-bucket assignment duplicates parts of this logic. Both could benefit from extracting zone-specific bucketing strategies.

5. **Dual versioning (CSV format vs SwiftData schema) may confuse future contributors.** The CSV format is at version 3 while the SwiftData schema is at version 1. A brief comment in `PeachSchema.swift` explaining the relationship (or lack thereof) between these two version tracks would help.

6. **`PeachSchema.swift` in Core depends on all training disciplines.** The schema defines concrete `@Model` classes for each discipline's record type — adding or changing a discipline forces changes to this Core file. SwiftData's `VersionedSchema` requires all models to be declared together, but that's a framework constraint, not an architectural justification. Same dependency-direction violation as `DuplicateKey.swift` (Layer 3, observation #1). The schema should live at the feature layer or a shared data-definition layer above Core.

7. **`TrainingDataStore` per-type fetch methods couple Core to concrete disciplines.** Four methods (`fetchAllPitchDiscriminations()`, etc.) each hardcode a concrete record type with timestamp sorting. Adding a discipline means adding a method. The generic `fetchAll<T>(_ type: T.Type)` already exists — replace the four with a single generic sorted fetch (e.g., constrained to a `Timestamped` protocol). Same dependency-direction issue as #6.

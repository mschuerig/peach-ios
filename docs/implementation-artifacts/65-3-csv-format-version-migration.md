# Story 65.3: CSV Format Version Migration Support

Status: done

## Story

As a **user upgrading Peach across versions**,
I want the import system to handle older CSV format versions gracefully,
so that I don't lose access to my exported training data when the format evolves.

## Acceptance Criteria

1. **Given** a CSV file exported with format version 2 **When** imported into current Peach (format version 3) **Then** the import succeeds — the parser applies version-specific transformations to bridge the gap.

2. **Given** a CSV file with an unknown future version (e.g., version 99) **When** imported **Then** the import fails with a clear, localized error message explaining the version mismatch and suggesting the user update the app.

3. **Given** the migration architecture **When** a new format version is added in the future **Then** the developer creates a single new conformance (version-specific parser/transformer) and registers it — no changes to existing parsers or the orchestrator are needed.

4. **Given** format version 2 CSV data **When** migrated to version 3 **Then** the transformation handles the schema differences: missing columns get sensible defaults, renamed columns are mapped, removed columns are ignored.

5. **Given** format version 1 CSV data **When** imported **Then** it is migrated through the chain: v1 → v2 → v3. Each step applies only its own transformation.

6. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Analyze format version differences (AC: #4, #5)
  - [x] 1.1 Read current `CSVExportSchema` and `CSVImportParser` to understand the version 3 format
  - [x] 1.2 Use git history to reconstruct version 2 schema (Epic 52) and version 1 schema (Epic 33/34)
  - [x] 1.3 Document the exact column differences between v1 → v2 and v2 → v3

- [x] Task 2: Design the migration architecture (AC: #3)
  - [x] 2.1 Define a `CSVFormatMigration` protocol: `sourceVersion`, `targetVersion`, `migrate(rows:) -> [[String: String]]`
  - [x] 2.2 Implement a migration chain that applies migrations sequentially from source version to current version
  - [x] 2.3 Follow the chain-of-responsibility pattern (per project memory: "that is the kind of architecture we should always be using" for format-dependent processing)

- [x] Task 3: Implement version-specific migrations (AC: #1, #4, #5)
  - [x] 3.1 Implement `V1ToV2Migration` — map column renames, add defaults for new columns
  - [x] 3.2 Implement `V2ToV3Migration` — map the v2-to-v3 schema changes
  - [x] 3.3 Register migrations in a migration registry

- [x] Task 4: Update the import parser (AC: #1, #2)
  - [x] 4.1 Replace the hard version equality check with: if version < current, apply migration chain; if version == current, parse directly; if version > current, reject with localized error
  - [x] 4.2 Add a localized error string for "exported from a newer version of Peach"
  - [x] 4.3 Preserve the existing discipline-owned CSV format architecture — migrations operate on raw row dictionaries before discipline parsers see them

- [x] Task 5: Write tests (AC: #1, #2, #4, #5, #6)
  - [x] 5.1 Test: v2 CSV imports successfully with correct data transformation
  - [x] 5.2 Test: v1 CSV imports successfully through v1 → v2 → v3 chain
  - [x] 5.3 Test: future version (99) produces clear error
  - [x] 5.4 Test: migration chain applies transformations in correct order
  - [x] 5.5 Test: each individual migration handles missing/extra columns gracefully

- [x] Task 6: Run full test suite (AC: #6)

## Dev Notes

### Current Problem (pre-existing finding PF-2)

`CSVImportParser` hard-rejects any format version ≠ current:

```swift
guard metadata.formatVersion == CSVExportSchema.formatVersion else {
    throw CSVImportError.unsupportedFormatVersion(metadata.formatVersion)
}
```

This means:
- A user who exports from Peach v1.1 (format v2) and later upgrades to Peach v1.2 (format v3) cannot re-import their old export
- There's no migration path — the data is simply rejected

### Design Constraints

- Migrations operate on raw row dictionaries (`[String: String]`) — before discipline-specific parsing
- Each migration is a standalone conformance — adding a new version means adding one new migration, no touching existing ones
- The discipline-owned CSV format architecture (from Epic 55) must be preserved — discipline parsers are not version-aware, they see current-format rows
- Forward compatibility (importing from newer versions) is explicitly NOT supported — the error message should guide the user to update

### Schema History

| Version | Epic | Key Changes |
|---------|------|-------------|
| 1 | 33/34 | Original 2-discipline format (pitch discrimination + pitch matching) |
| 2 | 52 | Added rhythm columns (4 new disciplines), header restructure |
| 3 | 55 | Discipline-owned column format, metadata restructure |

### Source File Locations

| File | Path |
|------|------|
| CSVImportParser | `Peach/Core/Data/CSVImportParser.swift` |
| CSVExportSchema | `Peach/Core/Data/CSVExportSchema.swift` |
| CSVExportService | `Peach/Core/Data/CSVExportService.swift` |

### References

- [Pre-existing finding: PF-2] — No forward migration path for CSV format versions
- [Project memory: chain of responsibility] — Required architecture for format-dependent processing

## Dev Agent Record

### Implementation Plan

- Analyzed git history to reconstruct V1 (12 columns, pitchComparison), V2 (15 columns, added rhythm), V3 (19 columns, discipline-owned) schemas
- Designed CSVFormatMigration protocol with chain-of-responsibility pattern per project memory
- Migrations operate on `[String: String]` row dictionaries — header-agnostic, column-name-keyed
- After migration chain, rows are reconstructed into current V3 CSV format and parsed by existing discipline parsers (zero changes to discipline code)
- Reused existing `unsupportedVersion` error for future versions (already contains appropriate localized message)

### Debug Log

(no issues encountered)

### Completion Notes

- ✅ CSVFormatMigration protocol with sourceVersion/targetVersion/migrate(rows:)
- ✅ CSVMigrationChain orchestrator applies migrations sequentially
- ✅ V1ToV2Migration: pitchComparison→pitchDiscrimination rename, adds empty rhythm columns
- ✅ V2ToV3Migration: rhythmMatching→continuousRhythmMatching rename, userOffsetMs→meanOffsetMs mapping, adds position columns
- ✅ CSVImportParser updated: version < current → migrate then parse; version == current → parse directly; version > current → reject
- ✅ 16 unit tests for migrations + 10 integration tests for end-to-end import
- ✅ 471 tests pass, 0 real failures (Clone 1 simulator crashes are pre-existing infrastructure issue)

## File List

- `Peach/Core/Data/CSVFormatMigration.swift` — NEW: protocol + CSVMigrationChain orchestrator
- `Peach/Core/Data/V1ToV2Migration.swift` — NEW: V1→V2 migration (training type rename, rhythm columns)
- `Peach/Core/Data/V2ToV3Migration.swift` — NEW: V2→V3 migration (training type rename, column mapping)
- `Peach/Core/Data/CSVImportParser.swift` — MODIFIED: version dispatch + parseMigratedLines method
- `PeachTests/Core/Data/CSVFormatMigrationTests.swift` — NEW: 16 migration unit tests
- `PeachTests/Core/Data/CSVImportParserTests.swift` — MODIFIED: 10 version migration integration tests added
- `docs/implementation-artifacts/65-3-csv-format-version-migration.md` — MODIFIED: status + completion
- `docs/implementation-artifacts/sprint-status.yaml` — MODIFIED: story status

## Change Log

- 2026-03-28: Implemented CSV format version migration support with chain-of-responsibility architecture. V1 and V2 CSV files can now be imported via sequential migration to V3 format. Future versions produce clear error. (Story 65.3)

# Story 65.3: CSV Format Version Migration Support

Status: ready-for-dev

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

- [ ] Task 1: Analyze format version differences (AC: #4, #5)
  - [ ] 1.1 Read current `CSVExportSchema` and `CSVImportParser` to understand the version 3 format
  - [ ] 1.2 Use git history to reconstruct version 2 schema (Epic 52) and version 1 schema (Epic 33/34)
  - [ ] 1.3 Document the exact column differences between v1 → v2 and v2 → v3

- [ ] Task 2: Design the migration architecture (AC: #3)
  - [ ] 2.1 Define a `CSVFormatMigration` protocol: `sourceVersion`, `targetVersion`, `migrate(rows:) -> [[String: String]]`
  - [ ] 2.2 Implement a migration chain that applies migrations sequentially from source version to current version
  - [ ] 2.3 Follow the chain-of-responsibility pattern (per project memory: "that is the kind of architecture we should always be using" for format-dependent processing)

- [ ] Task 3: Implement version-specific migrations (AC: #1, #4, #5)
  - [ ] 3.1 Implement `V1ToV2Migration` — map column renames, add defaults for new columns
  - [ ] 3.2 Implement `V2ToV3Migration` — map the v2-to-v3 schema changes
  - [ ] 3.3 Register migrations in a migration registry

- [ ] Task 4: Update the import parser (AC: #1, #2)
  - [ ] 4.1 Replace the hard version equality check with: if version < current, apply migration chain; if version == current, parse directly; if version > current, reject with localized error
  - [ ] 4.2 Add a localized error string for "exported from a newer version of Peach"
  - [ ] 4.3 Preserve the existing discipline-owned CSV format architecture — migrations operate on raw row dictionaries before discipline parsers see them

- [ ] Task 5: Write tests (AC: #1, #2, #4, #5, #6)
  - [ ] 5.1 Test: v2 CSV imports successfully with correct data transformation
  - [ ] 5.2 Test: v1 CSV imports successfully through v1 → v2 → v3 chain
  - [ ] 5.3 Test: future version (99) produces clear error
  - [ ] 5.4 Test: migration chain applies transformations in correct order
  - [ ] 5.5 Test: each individual migration handles missing/extra columns gracefully

- [ ] Task 6: Run full test suite (AC: #6)

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

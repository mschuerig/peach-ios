# Story 55.3: Discipline-Owned CSV Format

Status: ready-for-dev

## Story

As a **developer maintaining Peach**,
I want each training discipline to own its CSV column definitions, row formatting, and row parsing,
So that adding or removing a discipline never requires modifying shared CSV infrastructure.

## Context

The current CSV export/import is a fixed-width union schema: every row has 20 columns, each discipline fills its subset and pads the rest with empty strings. This means `CSVExportSchemaV2`, `CSVRecordFormatter`, `CSVImportParserV2`, and `CSVImportParser.ImportResult` all hardcode knowledge of every discipline's columns.

There is no installed base to maintain backward compatibility for. V1 schema, V1 parser, and the version-dispatch infrastructure can be removed entirely.

## Acceptance Criteria

1. **Each discipline declares its CSV columns** -- The discipline protocol (from 55.2) includes a requirement for column names specific to that discipline. Common columns (`trainingType`, `timestamp`) remain in shared infrastructure.

2. **Each discipline produces key-value pairs for export** -- Given a record, the discipline returns `[(columnName, value)]` pairs. The exporter assembles the full row by mapping key-value pairs into the union column positions.

3. **Each discipline parses its own rows on import** -- Given a row's fields and column-to-index mapping, the discipline parses its specific columns and returns a `PersistentModel` record. The import parser dispatches to the correct discipline by `trainingType` string.

4. **Column set is assembled from registry** -- The exporter/schema collects all columns from registered disciplines at format time. No hardcoded union column list.

5. **`CSVRecordFormatter` is eliminated** -- Formatting is provided by each discipline's protocol conformance. (Shared with 55.2 AC #8.)

6. **`CSVExportSchemaV2.TrainingType` enum is eliminated** -- Training type strings are provided by each discipline's protocol conformance.

7. **`CSVImportParserV2.RowResult` enum is eliminated** -- Row parsing returns `any PersistentModel` instead of per-discipline enum cases.

8. **`ImportResult` is discipline-agnostic** -- Replaced with a structure that does not have per-discipline typed arrays (e.g., a `[any PersistentModel]` or `[String: [any PersistentModel]]` keyed by training type).

9. **`ImportSummary` is discipline-agnostic** -- Per-discipline imported/skipped counts are replaced with a generic structure (e.g., `[String: (imported: Int, skipped: Int)]` keyed by training type).

10. **V1 artifacts are deleted:**
    - `CSVExportSchema.swift` (V1 schema)
    - `CSVExportSchemaTests.swift`
    - `CSVImportParserV1.swift`
    - `CSVImportParserV1Tests.swift`
    - `CSVFormatVersionReader.swift`
    - `CSVFormatVersionReaderTests.swift`

11. **Version dispatch chain is removed** -- `CSVImportParser` no longer negotiates between V1 and V2 parsers. Single parser for the current format.

12. **Shared formatting utilities are preserved** -- `CSVParserHelpers`, RFC 4180 escaping, ISO 8601 timestamp formatting, note name formatting, interval formatting remain available as shared utilities for disciplines to use.

13. **All existing tests pass** -- Full test suite passes with zero regressions. Tests for deleted V1 artifacts are also deleted.

## Tasks / Subtasks

- [ ] Task 1: Extend discipline protocol with CSV requirements (depends on 55.2 Task 1)
  - [ ] Column names specific to the discipline
  - [ ] Training type string identifier
  - [ ] Export: record → key-value pairs
  - [ ] Import: fields + column index map → record

- [ ] Task 2: Delete V1 artifacts
  - [ ] Delete `CSVExportSchema.swift`, `CSVImportParserV1.swift`, `CSVFormatVersionReader.swift`
  - [ ] Delete corresponding test files
  - [ ] Remove V1 parser registration from `CSVImportParser`

- [ ] Task 3: Rebuild export schema from registry
  - [ ] Common columns defined in shared infrastructure
  - [ ] Per-discipline columns collected from registry
  - [ ] Header row assembled dynamically

- [ ] Task 4: Rebuild exporter with key-value assembly
  - [ ] Each discipline produces key-value pairs from its records
  - [ ] Exporter maps pairs into column positions and pads remaining columns
  - [ ] Update tests

- [ ] Task 5: Rebuild import parser with discipline dispatch
  - [ ] Parse training type from first column
  - [ ] Look up discipline by training type string
  - [ ] Delegate row parsing to discipline
  - [ ] Return discipline-agnostic result
  - [ ] Update tests

- [ ] Task 6: Make `ImportResult` and `ImportSummary` discipline-agnostic
  - [ ] Replace per-discipline typed arrays/counts
  - [ ] Update `TrainingDataImporter` (already discipline-agnostic from 55.2)
  - [ ] Update import UI to work with generic summary
  - [ ] Update tests

- [ ] Task 7: Delete `CSVRecordFormatter` (shared with 55.2)
  - [ ] Formatting logic already moved to discipline conformances in 55.2
  - [ ] Delete file and tests

- [ ] Task 8: Run full test suite
  - [ ] All tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **Depends on 55.2** -- The discipline protocol must exist before CSV responsibilities can be added to it. This story extends the protocol rather than defining it.
- **No backward compatibility** -- There is no installed base. V1 schema and parser are dead code. Single format version going forward.
- **Key-value pairs, not positional** -- Disciplines produce named pairs, not positional arrays. The exporter handles column ordering. This means a discipline doesn't need to know about other disciplines' columns.
- **Import validation** -- Currently each parser method validates that irrelevant columns are empty. With discipline-owned parsing, each discipline only reads its own columns and ignores the rest. The strict "must be empty" validation can be relaxed or moved to a separate validation pass.
- **Format version** -- The metadata line (`# peach-export-format:N`) should be bumped to V3 to distinguish from the old union format, even though V1/V2 import is being dropped. This protects against confusion if someone tries to import an old file.

### Existing Code to Reference

- **`CSVExportSchemaV2.swift`** -- Current union column list and training type enum. [Source: Peach/Core/Data/CSVExportSchemaV2.swift]
- **`CSVRecordFormatter.swift`** -- Per-discipline format methods with empty-string padding. [Source: Peach/Core/Data/CSVRecordFormatter.swift]
- **`CSVImportParserV2.swift`** -- Per-discipline row parsing with RowResult enum. [Source: Peach/Core/Data/CSVImportParserV2.swift]
- **`CSVImportParser.swift`** -- Version dispatch chain with ImportResult. [Source: Peach/Core/Data/CSVImportParser.swift]
- **`TrainingDataImporter.swift`** -- Import logic with per-discipline arrays and duplicate keys. [Source: Peach/Core/Data/TrainingDataImporter.swift]
- **`CSVParserHelpers`** -- Shared parsing utilities to preserve. [Source: Peach/Core/Data/CSVParserHelpers.swift]

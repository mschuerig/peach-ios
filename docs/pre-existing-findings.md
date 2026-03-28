# Pre-Existing Findings Catalog

**Created:** 2026-03-23
**Purpose:** Single source of truth for all known pre-existing issues. Every finding has a disposition. No finding exists without accountability.

**History:** Closed findings are removed from this file to keep it actionable. To retrieve any previously closed item, run: `git log -p -- docs/pre-existing-findings.md` and search for the finding ID.

**Process:** When a review surfaces a "pre-existing" finding, the reviewer must cite the catalog entry ID. If no entry exists, it's a new finding — add it here with a disposition. See `docs/project-context.md` for the full protocol.

---

## WONT-FIX — Documented Exceptions

### CQ-3: `HapticFeedbackManager` imports UIKit

**Source:** story 54-3, story 51-1
**Reason:** `UIImpactFeedbackGenerator` has no SwiftUI equivalent. The class is already behind the `HapticFeedback` protocol, making the UIKit dependency a leaf implementation detail. Documented exception in dependency check script.

### DT-2: SwiftData records use raw primitives at persistence boundary

**Source:** code-review-2026-03-05, Section 1
**Reason:** The raw-to-domain boundary is already encapsulated by store adapters. Remaining raw field access is in contexts where raw types are natural (CSV export formatters, deduplication keys, metric extraction).

### TQ-1: Tests use `Task.sleep` for async synchronization

**Source:** story 58.2 code review
**Reason:** Multiple test files use `Task.sleep(for: .milliseconds(...))` as synchronization barriers for concurrent work (notification delivery, task cancellation). On loaded CI machines these could be flaky. Replacing with deterministic synchronization (e.g., `AsyncStream`, continuations, or polling with timeout) would be more robust but is a cross-cutting concern across many test files.

### ST-2: Xcode AppIntents build warning

**Source:** story 46-5
**Reason:** Xcode build system artifact from `appintentsmetadataprocessor`. Project doesn't use AppIntents. Zero runtime impact, not our code.

## OPEN — Needs Architectural Decision

### PF-1: SoundFontEngine render-thread try-lock silently drops MIDI events

**Source:** adversarial review 2026-03-27
**Symptom:** The audio render callback uses `withLockIfAvailable` (try-lock). When the main thread holds the lock during a schedule update, the entire audio frame skips MIDI dispatch. Events are lost, not deferred.
**Risk:** Audible note dropouts in fast-tempo rhythm patterns when schedule updates are frequent.
**Disposition:** Tracked as story 65.1 in Epic 65.

### PF-3: CSV import accepts negative rhythm offset values without validation

**Source:** story 64.9 code review (D1)
**Symptom:** `RhythmOffsetDetectionDiscipline.parseCSVRow` and `ContinuousRhythmMatchingDiscipline.parseCSVRow` only check `isFinite` on `offsetMs`, not that values are non-negative. A malformed CSV could introduce negative offsets that bypass the adapter's `abs()` calls. The `abs()` in `combinedMeanPercent` happens to guard against this at the computation layer, but the validation gap remains at the import boundary.
**Risk:** Negative offsets stored in SwiftData could produce incorrect statistics if any future code path reads `record.offsetMs` directly without `abs()`.
**Disposition:** Open — needs import validation fix (`offsetMs >= 0` or `abs()` at parse time).

### PF-2: No forward migration path for CSV format versions

**Source:** adversarial review 2026-03-27
**Symptom:** `CSVImportParser` hard-rejects any format version ≠ current (`CSVExportSchema.formatVersion`, currently 3). No degradation, partial parsing, or version migration exists.
**Risk:** Data portability risk — users exporting from newer Peach and importing into older Peach (or vice versa) get a hard error with no recovery.
**Disposition:** Tracked as story 65.3 in Epic 65.

## RESOLVED

### TF-2: `CSVImportParserTests/futureVersionProducesError()` fails on German-locale simulators

**Source:** story 66-2 (observed pre-existing on clean `main` at commit a251771)
**Symptom:** Test asserts `description.contains("update")` on a `String(localized:)` value. On German-locale simulators, the localized string uses "aktualisiere" instead of "update", causing the assertion to fail.
**Fix:** Removed fragile localized string assertions. The enum case pattern match (`if case .unsupportedVersion(let version)`) already validates the error type and version number, making the string check redundant.
**Disposition:** CLOSED — fixed in story 66.2.

### TF-1: `ProgressTimelineTests` flaky failures near midnight

**Source:** story 61-2 (observed pre-existing on clean `main` at commit 92998e7), extended in story 64-7
**Symptom:** Tests using `hoursAgo` offsets fail intermittently when run between midnight and ~1 AM. Originally found in `subBucketsSessionEmpty()` and `sessionBuckets()`, also affected five stddev tests (`stddevZero`, `stddevNonZero`, `stddevUsesSampleVariance`, `stddevZeroForSinglePoint`, `stddevTwoPointsBessels`).
**Root cause:** Tests used `hoursAgo` offsets (1.0, 0.99, etc.) which placed records before midnight when the test ran shortly after midnight. The bucketing algorithm uses `startOfDay(now)` as the session zone boundary, so records landed in the day zone instead of the session zone, splitting records across buckets.
**Fix:** Replaced `hoursAgo` with explicit dates anchored to `startOfDay(now) + offset`, guaranteeing records always land in the session zone. Story 64-7 applied the same fix to the remaining stddev tests.

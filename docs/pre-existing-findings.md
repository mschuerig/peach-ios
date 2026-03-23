# Pre-Existing Findings Catalog

**Created:** 2026-03-23
**Purpose:** Single source of truth for all known pre-existing issues surfaced across code reviews and story implementations. Every finding has a disposition. No finding exists without accountability.

**Process:** When a review surfaces a "pre-existing" finding, the reviewer must cite the catalog entry ID. If no entry exists, it's a new finding — add it here with a disposition.

---

## Disposition Legend

| Status | Meaning |
|--------|---------|
| **CLOSED** | Fixed in codebase, verified |
| **WONT-FIX** | Intentional design or not worth fixing, with documented reason |
| **OPEN** | Needs a story or inline fix |

---

## Domain Type Discipline

### DT-1: `PianoKeyboardView` uses `Int` instead of `MIDINote` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** File deleted — `PianoKeyboardView.swift` was dead code with zero references (2026-03-23)

### DT-2: Persistence boundary — SwiftData models use raw primitives — WONT-FIX

**Source:** code-review-2026-03-05, Section 1
**Reason:** The raw-to-domain boundary is already encapsulated by store adapters. Remaining raw field access is in contexts where raw types are natural (CSV export formatters, deduplication keys, metric extraction). Adding computed bridging properties would have minimal benefit.

### DT-3: `NotePlayer.play()` accepts `TimeInterval` instead of `NoteDuration` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed by:** L13 in code-review-2026-03-13 (changed to `Duration`)

### DT-4: `PitchMatchingSession.referenceFrequency` is `Double?` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** Now `Frequency?` (verified in code)

### DT-5: `CompletedPitchMatching` uses `Double` for cent values — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** `CompletedPitchMatchingTrial` now uses `Cents` for both `initialCentOffset` and `userCentError` (verified in code)

### DT-6: `PerceptualProfile.update()` takes `centOffset: Double` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** Profile rewritten to generic `StatisticsKey`-based store; no `centOffset: Double` in profile API

### DT-7: Hard-coded `127` instead of `MIDINote.validRange.upperBound` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** `KazezNoteStrategy.swift` now uses `MIDINote.validRange.upperBound` and `.lowerBound` (verified in code)

### DT-8: `PerceptualProfile` uses `128` magic number — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** Profile rewritten; no magic number array sizing

### DT-9: `SettingsKeys` stores MIDI defaults as raw `Int` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** Defaults already use domain types (`defaultNoteRangeMin: MIDINote = 36`, etc.) via `ExpressibleByIntegerLiteral`. Original review was stale.

### DT-10: `CSVImportParser` MIDI range with raw `(0...127)` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed:** Changed to `MIDINote.validRange.contains()` in both `PitchDiscriminationCSVParser` and `PitchMatchingCSVParser` (2026-03-23)

### DT-11: `SoundFontNotePlayer.decompose()` returns raw `cents: Double` — CLOSED

**Source:** code-review-2026-03-05, Section 1
**Fixed by:** H2 in code-review-2026-03-13

---

## Constants & Magic Numbers

### CN-1: Kazez formula factors undocumented — CLOSED

**Source:** code-review-2026-03-05, Section 2
**Fixed:** Now `narrowingCoefficient` and `wideningCoefficient` named constants with formula documentation (verified in code)

### CN-2: Feedback duration duplicated across sessions — CLOSED

**Source:** code-review-2026-03-05, Section 2
**Fixed:** Extracted to `TrainingConstants.feedbackDuration` (confirmed in glossary)

### CN-3: MIDI velocity duplicated across sessions — CLOSED

**Source:** code-review-2026-03-05, Section 2
**Fixed:** Extracted to `TrainingConstants.defaultNoteVelocity` (confirmed in glossary)

### CN-4: Time bucket thresholds as magic numbers — CLOSED

**Source:** code-review-2026-03-05, Section 2
**Fixed by:** L2 in code-review-2026-03-13 (changed to `Duration` named constants)

---

## Code Quality

### CQ-1: `TrainingDataStore` uses `print()` instead of `Logger` — CLOSED

**Source:** code-review-2026-03-05, Section 5
**Fixed:** No `print()` calls found in `TrainingDataStore.swift` (verified by grep)

### CQ-2: `import OSLog` vs `import os` inconsistency — CLOSED

**Source:** code-review-2026-03-05, Section 5
**Fixed:** Standardized to `import os` in `KazezNoteStrategy.swift`, `PerceptualProfile.swift`, and `AdaptiveRhythmOffsetDetectionStrategy.swift` (2026-03-23)

### CQ-3: `HapticFeedbackManager` imports UIKit — WONT-FIX

**Source:** story 54-3, story 51-1 ("1 pre-existing documented violation")
**Reason:** `UIImpactFeedbackGenerator` has no SwiftUI equivalent. The class is already behind the `HapticFeedback` protocol, making the UIKit dependency a leaf implementation detail. Documented exception in dependency check script.

### CQ-4: Device disconnection logged at wrong level — CLOSED

**Source:** code-review-2026-03-05, Section 5
**Fixed:** Changed from `logger.info` to `logger.warning` in `AudioSessionInterruptionMonitor.swift` (2026-03-23)

### CQ-5: `SoundFontNotePlayer` lacks lifecycle logging — CLOSED

**Source:** code-review-2026-03-05, Section 5
**Fixed:** Added `logger.debug` for `play()` and `stopAll()` in `SoundFontPlayer.swift` (2026-03-23)

### CQ-6: Error level too severe for UI race condition — CLOSED

**Source:** code-review-2026-03-05, Section 5
**Fixed:** Changed from `logger.error` to `logger.warning` in `PitchDiscriminationSession.swift` (2026-03-23)

---

## Code Duplication

### CD-1: Session state machine boilerplate — OPEN

**Source:** code-review-2026-03-05, Section 4
**Severity:** MEDIUM
**Details:** All four sessions (`PitchDiscriminationSession`, `PitchMatchingSession`, `RhythmOffsetDetectionSession`, `ContinuousRhythmMatchingSession`) duplicate `interruptionMonitor` wiring, `feedbackTask` lifecycle management, and `stop()` cleanup. ~15-20 duplicated lines per session × 4 sessions.
**Action:** Create story to extract a `SessionLifecycle` helper struct that owns feedback task management and interruption monitor wiring. Composition, not inheritance.

### CD-2: Bucket statistics calculation duplicated — CLOSED

**Source:** code-review-2026-03-05, Section 4
**Fixed by:** L6 in code-review-2026-03-13

### CD-3: Screen toolbar/lifecycle duplication — CLOSED

**Source:** code-review-2026-03-05, Section 4
**Fixed by:** L7 in code-review-2026-03-13

---

## Architecture

### AR-1: `@Model` types leaking through non-storage interfaces — CLOSED

**Source:** code-review-2026-03-13, H8
**Fixed:** All H-items in 2026-03-13 marked complete

### AR-2: Service orchestration in SettingsScreen — CLOSED

**Source:** code-review-2026-03-13, H3
**Fixed:** Moved to composition root

### AR-3: Incomplete profile reset — CLOSED

**Source:** code-review-2026-03-13, H4
**Fixed:** Profile rewritten with single `resetAll()` method

### AR-4: Non-atomic data replacement in TrainingDataImporter — CLOSED

**Source:** code-review-2026-03-13, H5
**Fixed:** Batch-save method added

### AR-5: PerceptualProfile training-mode asymmetries — CLOSED

**Source:** code-review-2026-03-13, L15
**Fixed:** Profile completely rewritten to generic `StatisticsKey`-based store. All disciplines go through the same `StatisticsKey → TrainingDisciplineStatistics` path. No per-note arrays, no separate reset methods — single `resetAll()`. The asymmetry table from the original review is entirely obsolete.

---

## Glossary & Documentation

### GL-1: Glossary outdated algorithm terminology — CLOSED

**Source:** code-review-2026-03-05, Section 6
**Fixed:** Glossary now documents Kazez Note Strategy accurately, no stale narrowing/widening/regional entries

### GL-2: Glossary Note1/Note2 terminology — CLOSED

**Source:** code-review-2026-03-05, Section 6
**Fixed:** Glossary uses referenceNote/targetNote consistently

### GL-3: Glossary stale "Weak Spot" definition — CLOSED

**Source:** code-review-2026-03-05, Section 6
**Fixed:** No `weakSpots` method found in production code; glossary entry removed

### GL-4: Training modes missing from glossary — CLOSED

**Source:** code-review-2026-03-05, Section 6
**Fixed:** Glossary now has "Training Discipline" entry with all four disciplines

### GL-5: "Natural vs. Mechanical" in glossary — CLOSED

**Source:** code-review-2026-03-05, Section 6
**Fixed:** Removed from glossary

### GL-6: "Adaptive Note Strategy" stale — CLOSED

**Source:** code-review-2026-03-05, Section 6
**Fixed:** Glossary now documents "Kazez Note Strategy"

### GL-7: Cent terminology creep — CLOSED

**Source:** code-review-2026-03-05, Section 6
**Fixed:** Glossary now explicitly distinguishes Cent Offset, Initial Cent Offset, and User Cent Error

---

## Test Infrastructure

### TI-1: `fatalError()` in test helpers — CLOSED

**Source:** test-review-2026-02-21, P0 #1
**Fixed by:** commit `0bf633b` and H1 in code-review-2026-03-13

### TI-2: 47 `Task.sleep` hard waits — CLOSED

**Source:** test-review-2026-02-21, P0 #2
**Fixed:** Replaced with deterministic helpers; H7 in code-review-2026-03-13 removed AudioSession sleeps

### TI-3: Oversized test files — CLOSED

**Source:** test-review-2026-02-21, P0 #3
**Fixed:** Split into smaller files per fix log

### TI-4: Audio interruption test coverage missing — CLOSED

**Source:** test-review-2026-02-21, P0 #4
**Fixed:** `TrainingSessionAudioInterruptionTests.swift` added (13 tests)

### TI-5: Placeholder PeachTests.swift — CLOSED

**Source:** test-review-2026-02-21, P0 #5
**Fixed:** Deleted

### TI-6: Flaky PitchComparisonSession lifecycle/reset tests — CLOSED

**Source:** stories 41-5, 41-10; code-review-2026-03-13 L14/L16/L17
**Fixed:** Replaced polling with continuation-based sync

### TI-7: Flaky `ProgressTimelineTests/ewmaHalflife` — CLOSED

**Source:** story 42-2
**Fixed:** No recent failures observed. Theoretical midnight-boundary fragility noted but not actionable.

### TI-8: Missing `async` on ~75 @Test functions — CLOSED

**Source:** code-review-2026-03-13, H6
**Fixed:** All @Test functions now async

---

## Story-Specific Pre-Existing Findings

### ST-1: Session merging bug in `assignBuckets` — OPEN

**Source:** story 41-1 (M3 finding)
**Severity:** MEDIUM
**Details:** `assignBuckets` compares against session start instead of last record's timestamp for gap detection. `assignMultiGranularityBuckets` was written correctly. Both code paths are live: `assignBuckets` serves `ProgressSparklineView` on the Start Screen; `assignMultiGranularityBuckets` serves the Profile chart.
**Action:** Create story to consolidate `buckets(for:)` to use `allGranularityBuckets(for:)`, then delete `assignBuckets` as dead code. One code path instead of two.

### ST-2: Build warning — pre-existing AppIntents warning — WONT-FIX

**Source:** story 46-5
**Reason:** Xcode build system artifact from `appintentsmetadataprocessor`. Project doesn't use AppIntents. Zero runtime impact, not our code.

---

## Summary

| Status | Count |
|--------|-------|
| **CLOSED** | 37 |
| **OPEN** | 2 |
| **WONT-FIX** | 3 |

### Open Items

| ID | Severity | Summary | Action |
|----|----------|---------|--------|
| CD-1 | MEDIUM | Session state machine boilerplate duplicated across 4 sessions | Story: extract `SessionLifecycle` helper |
| ST-1 | MEDIUM | Buggy `assignBuckets` still live on Start Screen sparkline | Story: consolidate to `allGranularityBuckets`, delete `assignBuckets` |

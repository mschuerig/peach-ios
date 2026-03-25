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

## OPEN — Needs Investigation

### TF-1: `ProgressTimelineTests/subBucketsSessionEmpty()` and `sessionBuckets()` flaky failures

**Source:** story 61-2 (observed pre-existing on clean `main` at commit 92998e7)
**Symptom:** Both tests fail intermittently. Failures reproduce on clean `main` without any changes.
**Likely cause:** Timing-dependent test logic (related to TQ-1) or date-boundary sensitivity in bucket calculations.

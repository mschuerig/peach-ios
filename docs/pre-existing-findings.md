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

### ST-2: Xcode AppIntents build warning

**Source:** story 46-5
**Reason:** Xcode build system artifact from `appintentsmetadataprocessor`. Project doesn't use AppIntents. Zero runtime impact, not our code.

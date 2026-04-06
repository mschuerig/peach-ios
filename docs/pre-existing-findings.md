# Pre-Existing Findings Catalog

**Created:** 2026-03-23
**Purpose:** Single source of truth for all known pre-existing issues. Every finding has a disposition. No finding exists without accountability.

**History:** Closed findings are removed from this file to keep it actionable. To retrieve any previously closed item, run: `git log -p -- docs/pre-existing-findings.md` and search for the finding ID.

**Process:** When a review surfaces a "pre-existing" finding, the reviewer must cite the catalog entry ID. If no entry exists, it's a new finding — add it here with a disposition. See `docs/project-context.md` for the full protocol.

---

## WONT-FIX — Documented Exceptions

_None currently._

## OPEN — Needs Architectural Decision

### PF-001: Redundant Session Stop via Background Notification on macOS

**Found:** 2026-03-29 (Story 68.6)
**Severity:** Low (cosmetic log noise, no correctness impact)

On macOS, each session's `AudioSessionInterruptionMonitor` independently listens for `NSApplication.didResignActiveNotification` and calls `stop()`. The `TrainingLifecycleCoordinator` also stops the current session via `handleAppDeactivated()`. This results in 4× redundant "stop() called but already idle" log messages on every app switch.

**Fix:** Stop passing `backgroundNotificationName` to sessions on macOS, since the coordinator now owns the training lifecycle. The notification-based stop in sessions was the original mechanism before the coordinator existed.

### PF-002: PeachApp Initialized Twice on macOS

**Found:** 2026-03-29 (Story 68.6)
**Severity:** Medium (wasteful startup — double ModelContainer, AudioEngine, etc.)

On macOS, SwiftUI initializes the `@main App` struct twice before one instance is used. This creates duplicate `PerceptualProfile`, `SoundFontEngine`, sessions, and other heavyweight objects. Visible in logs as 2× "PerceptualProfile initialized (cold start)".

**Fix:** Move heavyweight initialization out of `PeachApp.init()` into a lazily-created shared container, or use `@State` with a factory that guards against double init. This is a known SwiftUI macOS behavior.

### PF-003: Training Session Restart on In-Stack Navigation to Settings/Profile

**Found:** 2026-04-07 (Story 75.3 code review)
**Severity:** Medium (session progress lost on navigation round-trip)

When the user taps Settings or Profile in the training screen toolbar, SwiftUI's NavigationStack fires `onDisappear` on the training screen, which calls `lifecycle.trainingScreenDisappeared()` → `stopCurrentSession()` → `session.stop()`. The `stop()` method fully clears session state (`sessionBestCentDifference`, `currentTrial`, `lastResult` — all nilled). When the user navigates back, `onAppear` fires and `startCurrentSession()` restarts training from scratch, losing all in-session progress.

**Fix:** Introduce pause/resume semantics distinct from stop/start. Either add `pause()`/`resume()` to the `TrainingSession` protocol, or have the lifecycle coordinator distinguish between temporary pushes (Settings/Profile) and permanent pops (back to Start Screen). Requires multi-file change across the session protocol, all session implementations, and the lifecycle coordinator.

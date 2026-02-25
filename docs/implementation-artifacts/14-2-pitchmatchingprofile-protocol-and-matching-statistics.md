# Story 14.2: PitchMatchingProfile Protocol and Matching Statistics

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want PerceptualProfile to track pitch matching statistics via a new protocol,
So that PitchMatchingSession can record and read matching accuracy data through a clean interface.

## Acceptance Criteria

1. **PitchMatchingProfile protocol created** — Defines: `func updateMatching(note: Int, centError: Double)`, `var matchingMean: Double? { get }` (mean absolute error in cents), `var matchingStdDev: Double? { get }` (standard deviation), `var matchingSampleCount: Int { get }`, `func resetMatching()`. File located at `Core/Profile/PitchMatchingProfile.swift`.

2. **PerceptualProfile conforms to PitchMatchingProfile** — Stores aggregate matching statistics: running mean absolute error, running standard deviation (Welford's algorithm), and sample count. These are overall aggregates — not per-note for v0.2.

3. **PerceptualProfile conforms to PitchMatchingObserver** — `pitchMatchingCompleted(_:)` calls `updateMatching(note:centError:)` to update matching statistics incrementally.

4. **Profile rebuilt from both record types on startup** — `PeachApp.swift` fetches `PitchMatchingRecord` data alongside `ComparisonRecord` data and feeds both into `PerceptualProfile` to reconstruct the complete profile.

5. **Cold start returns nil/zero** — When no pitch matching data exists: `matchingMean` and `matchingStdDev` return `nil`, `matchingSampleCount` returns `0`.

6. **resetMatching() is independent from discrimination reset** — `resetMatching()` clears all matching statistics while discrimination statistics remain untouched. Conversely, `reset()` (discrimination) does not affect matching statistics.

7. **Settings "Reset All Training Data" clears both** — The reset action in Settings must call both `reset()` and `resetMatching()` so all training data is cleared.

8. **All existing tests pass** — New tests verify: matching statistics update via Welford's, cold start nil values, reset independence from discrimination, profile rebuild from both record types.

## Tasks / Subtasks

- [x] Task 1: Create PitchMatchingProfile protocol (AC: #1)
  - [x] 1.1 Create `Peach/Core/Profile/PitchMatchingProfile.swift` with all 5 method/property declarations matching architecture doc signatures
  - [x] 1.2 Write conformance test: `PeachTests/Core/Profile/PitchMatchingProfileTests.swift` — verify `PerceptualProfile` conforms to `PitchMatchingProfile` (compile-time check via type assignment)

- [x] Task 2: Implement matching statistics in PerceptualProfile (AC: #2, #5)
  - [x] 2.1 Add matching aggregate properties to `PerceptualProfile`: `private var matchingCount: Int`, `private var matchingMeanAbs: Double`, `private var matchingM2: Double`
  - [x] 2.2 Implement `updateMatching(note:centError:)` — take `abs(centError)`, apply Welford's algorithm to the three aggregate accumulators. The `note` parameter is accepted but unused in v0.2 (overall aggregates only)
  - [x] 2.3 Implement `matchingMean` — return `matchingMeanAbs` if `matchingCount > 0`, else `nil`
  - [x] 2.4 Implement `matchingStdDev` — return `sqrt(matchingM2 / (matchingCount - 1))` if `matchingCount >= 2`, else `nil`
  - [x] 2.5 Implement `matchingSampleCount` — return `matchingCount`
  - [x] 2.6 Implement `resetMatching()` — zero out all three matching accumulators; leave discrimination `noteStats` untouched
  - [x] 2.7 Add `: PitchMatchingProfile` to `PerceptualProfile` class declaration (alongside existing `: PitchDiscriminationProfile`)
  - [x] 2.8 Write tests: Welford's mean/stdDev accuracy after multiple updates, cold start nil/zero values, resetMatching independence from discrimination stats, reset() independence from matching stats

- [x] Task 3: Add PitchMatchingObserver conformance (AC: #3)
  - [x] 3.1 Add `extension PerceptualProfile: PitchMatchingObserver` at bottom of `PerceptualProfile.swift` (matches existing `ComparisonObserver` extension pattern)
  - [x] 3.2 Implement `pitchMatchingCompleted(_:)` — call `updateMatching(note: result.referenceNote, centError: result.userCentError)`
  - [x] 3.3 Write test: verify observer calls `updateMatching` and stats update correctly

- [x] Task 4: Rebuild profile from PitchMatchingRecord on startup (AC: #4)
  - [x] 4.1 In `PeachApp.swift`, after the existing comparison record loop, add: fetch `PitchMatchingRecord` via `dataStore.fetchAllPitchMatchings()` and call `profile.updateMatching(note:centError:)` for each record
  - [x] 4.2 Include pitch matching record count in the startup log message

- [x] Task 5: Update Settings reset to clear matching stats (AC: #6, #7)
  - [x] 5.1 Add `@Environment(\.perceptualProfile) private var profile` to `SettingsScreen`
  - [x] 5.2 In `resetAllTrainingData()`, after `comparisonSession.resetTrainingData()`, call `profile.resetMatching()`

- [x] Task 6: Run full test suite and verify (AC: #8)
  - [x] 6.1 Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] 6.2 Verify all existing tests pass with zero regressions
  - [x] 6.3 Verify all new tests pass

## Dev Notes

### Technical Requirements

- **Protocol-first design** — define `PitchMatchingProfile` protocol before implementing conformance. [Source: docs/project-context.md#Error-Handling]
- **Protocol naming convention** — capability noun without `-able` or `-Protocol` suffix: `PitchMatchingProfile`, not `PitchMatchingProfileProtocol`. [Source: docs/project-context.md#Project-Specific-Naming]
- **Default MainActor isolation** — do NOT add explicit `@MainActor` to the protocol or implementation. Swift 6.2 default isolation applies. [Source: docs/project-context.md#Concurrency]
- **No access control modifiers** — single-module app; `internal` is the default. Never use `public` or `open`. [Source: docs/project-context.md#Access-Control]
- **Welford's online algorithm** — already proven in `PerceptualProfile.update()` for discrimination stats. Reuse the exact same pattern for matching stats. The three accumulators are: `sampleCount`, running `mean`, and `m2` (sum of squared differences from mean).
- **`centError` is signed, `matchingMean` is absolute** — `CompletedPitchMatching.userCentError` is a signed cent error from the user. The `updateMatching` implementation must take `abs(centError)` before applying Welford's, because `matchingMean` represents "mean absolute error in cents" per the architecture doc. [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]
- **`note` parameter unused in v0.2** — `updateMatching(note:centError:)` accepts the MIDI note for forward compatibility (per-note matching stats planned later). The v0.2 implementation tracks only overall aggregates and does NOT create a per-note array. [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

### Architecture Compliance

- **Exact protocol signature from architecture doc:**
  ```swift
  protocol PitchMatchingProfile {
      func updateMatching(note: Int, centError: Double)
      var matchingMean: Double? { get }
      var matchingStdDev: Double? { get }
      var matchingSampleCount: Int { get }
      func resetMatching()
  }
  ```
  [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

- **AnyObject constraint consideration** — `PitchDiscriminationProfile` has `: AnyObject` (added in story 14.1 because test code needed `===` identity comparison). Apply the same `AnyObject` constraint to `PitchMatchingProfile` if `PitchMatchingSession` (future story 15.1) will store the profile as a protocol type and tests will need identity checks. Decision: **add `AnyObject`** — `PerceptualProfile` is a class, and all future conformers will be too. Consistency with `PitchDiscriminationProfile` pattern. [Source: docs/implementation-artifacts/14-1 Dev Notes — AnyObject learning]

- **Dual conformance on PerceptualProfile:**
  ```swift
  @Observable
  final class PerceptualProfile: PitchDiscriminationProfile, PitchMatchingProfile {
      // Existing: 128-slot noteStats array for discrimination
      // New: three aggregate matching accumulators (matchingCount, matchingMeanAbs, matchingM2)
  }
  ```
  [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

- **Observer conformance** — `PerceptualProfile` conforms to both `ComparisonObserver` (existing) and `PitchMatchingObserver` (new). Both are declared as extensions at the bottom of `PerceptualProfile.swift`. [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

- **Dependency boundaries after this story:**
  - `ComparisonSession` depends on `PitchDiscriminationProfile` (unchanged)
  - `PitchMatchingSession` (future story 15.1) will depend on `PitchMatchingProfile`
  - `PeachApp.swift` keeps concrete `PerceptualProfile` (composition root)
  - Profile Screen keeps concrete `PerceptualProfile` for now
  [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

- **Startup reconstruction** — `PeachApp.swift` rebuilds the complete profile from both record types:
  1. Fetch `ComparisonRecord` → call `profile.update()` for each (existing)
  2. Fetch `PitchMatchingRecord` → call `profile.updateMatching()` for each (new)
  [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

### Library & Framework Requirements

- **No new dependencies** — this is a pure Swift protocol + implementation. No libraries, frameworks, or imports beyond `Foundation` (for `Date` in observer).
- **Zero third-party dependencies** — project rule. [Source: docs/project-context.md#Technology-Stack]
- **`@Observable` interaction** — `PerceptualProfile` is `@Observable`. Adding new stored properties (`matchingCount`, `matchingMeanAbs`, `matchingM2`) will automatically participate in observation. SwiftUI views observing `PerceptualProfile` will re-render when matching stats change. The protocol itself should NOT be marked `@Observable`.

### File Structure Requirements

**New files:**
| File | Location | Description |
|------|----------|-------------|
| `PitchMatchingProfile.swift` | `Peach/Core/Profile/` | Protocol with 5 method/property declarations |
| `PitchMatchingProfileTests.swift` | `PeachTests/Core/Profile/` | Conformance verification + matching stats tests |

**Modified files:**
| File | Location | Change |
|------|----------|--------|
| `PerceptualProfile.swift` | `Peach/Core/Profile/` | Add `: PitchMatchingProfile` conformance, matching aggregate properties, `updateMatching()`, `resetMatching()`, `PitchMatchingObserver` extension |
| `PeachApp.swift` | `Peach/App/` | Fetch `PitchMatchingRecord` on startup and rebuild matching stats |
| `SettingsScreen.swift` | `Peach/Settings/` | Add `@Environment(\.perceptualProfile)`, call `profile.resetMatching()` in reset action |

**Unchanged files (verified no changes needed):**
| File | Reason |
|------|--------|
| `PitchDiscriminationProfile.swift` | Discrimination protocol unaffected |
| `ComparisonSession.swift` | Depends only on `PitchDiscriminationProfile`; `resetTrainingData()` calls `profile.reset()` which is discrimination-only |
| `TrainingDataStore.swift` | Already has `PitchMatchingObserver` conformance and `fetchAllPitchMatchings()` from story 13.1 |
| `PitchMatchingObserver.swift` | Observer protocol already exists from story 13.1 |
| `CompletedPitchMatching.swift` | Value type already exists from story 13.1 |
| `PitchMatchingRecord.swift` | SwiftData model already exists from story 13.1 |
| `MockTrainingDataStore.swift` | Already conforms to `PitchMatchingObserver` from story 13.1 |
| `NextComparisonStrategy.swift` | No matching dependency |
| `SummaryStatisticsView.swift` | Profile Screen integration is a later story |

**`Core/Profile/` directory after this story:**
```
Peach/Core/Profile/
├── PerceptualProfile.swift           # Modified: adds PitchMatchingProfile conformance + PitchMatchingObserver
├── PitchDiscriminationProfile.swift  # Unchanged
├── PitchMatchingProfile.swift        # NEW: protocol file
├── ThresholdTimeline.swift           # Unchanged
└── TrendAnalyzer.swift               # Unchanged
```

### Testing Requirements

- **Swift Testing only** — `@Test`, `@Suite`, `#expect()`. Never XCTest. [Source: docs/project-context.md#Testing-Rules]
- **All test functions must be `async`** — default MainActor isolation handles actor safety. [Source: docs/project-context.md#Testing-Rules]
- **No `test` prefix** on function names — `@Test` attribute marks the test. [Source: docs/project-context.md#Testing-Rules]
- **Behavioral test descriptions** — e.g., `@Test("PerceptualProfile conforms to PitchMatchingProfile")`. [Source: docs/project-context.md#Testing-Rules]
- **Run full suite**: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'` — never run only specific test files. [Source: docs/project-context.md#Pre-Commit-Gate]

**New tests to write:**

1. **Conformance test** — compile-time check:
   ```swift
   @Test("PerceptualProfile conforms to PitchMatchingProfile")
   func conformsToPitchMatchingProfile() async {
       let profile = PerceptualProfile()
       let _: PitchMatchingProfile = profile
       #expect(profile is PitchMatchingProfile)
   }
   ```

2. **Cold start** — matchingMean/matchingStdDev are nil, matchingSampleCount is 0:
   ```swift
   @Test("cold start returns nil mean and stdDev, zero sample count")
   func coldStart() async {
       let profile = PerceptualProfile()
       #expect(profile.matchingMean == nil)
       #expect(profile.matchingStdDev == nil)
       #expect(profile.matchingSampleCount == 0)
   }
   ```

3. **Welford's mean** — after N updates, mean absolute error is correct:
   ```swift
   @Test("matching mean tracks absolute cent error")
   func matchingMean() async {
       let profile = PerceptualProfile()
       profile.updateMatching(note: 60, centError: 10.0)
       profile.updateMatching(note: 60, centError: -20.0)  // abs = 20
       #expect(profile.matchingMean == 15.0)  // (10 + 20) / 2
       #expect(profile.matchingSampleCount == 2)
   }
   ```

4. **Welford's stdDev** — after 2+ updates, stdDev is correct:
   ```swift
   @Test("matching stdDev computed from absolute errors")
   func matchingStdDev() async {
       let profile = PerceptualProfile()
       profile.updateMatching(note: 60, centError: 10.0)
       profile.updateMatching(note: 60, centError: -20.0)  // abs = 20
       // stdDev of [10, 20] = sqrt(50) ≈ 7.071
       let stdDev = try #require(profile.matchingStdDev)
       #expect(abs(stdDev - 7.0710678) < 0.001)
   }
   ```

5. **resetMatching independence** — resetting matching does NOT affect discrimination:
   ```swift
   @Test("resetMatching clears matching but preserves discrimination")
   func resetMatchingIndependence() async {
       let profile = PerceptualProfile()
       profile.update(note: 60, centOffset: 50.0, isCorrect: true)
       profile.updateMatching(note: 60, centError: 10.0)
       profile.resetMatching()
       #expect(profile.matchingMean == nil)
       #expect(profile.matchingSampleCount == 0)
       #expect(profile.statsForNote(60).sampleCount == 1)  // discrimination preserved
   }
   ```

6. **reset() independence** — resetting discrimination does NOT affect matching:
   ```swift
   @Test("reset clears discrimination but preserves matching")
   func resetDiscriminationIndependence() async {
       let profile = PerceptualProfile()
       profile.update(note: 60, centOffset: 50.0, isCorrect: true)
       profile.updateMatching(note: 60, centError: 10.0)
       profile.reset()
       #expect(profile.statsForNote(60).sampleCount == 0)  // discrimination cleared
       #expect(profile.matchingMean == 10.0)  // matching preserved
       #expect(profile.matchingSampleCount == 1)
   }
   ```

7. **Observer integration** — `pitchMatchingCompleted` updates matching stats:
   ```swift
   @Test("pitchMatchingCompleted updates matching statistics")
   func observerUpdatesStats() async {
       let profile = PerceptualProfile()
       let result = CompletedPitchMatching(referenceNote: 60, initialCentOffset: 50.0, userCentError: 15.0)
       profile.pitchMatchingCompleted(result)
       #expect(profile.matchingSampleCount == 1)
       #expect(profile.matchingMean == 15.0)
   }
   ```

**No mock for PitchMatchingProfile needed in this story** — tests use real `PerceptualProfile` which conforms. A mock will be needed when `PitchMatchingSession` is created in story 15.1.

**Existing test count:** 422 tests as of story 14.1 code review. All must pass unchanged.

### Previous Story Intelligence (Story 14.1)

- **Key learning: `AnyObject` constraint needed on profile protocols** — story 14.1 had to add `AnyObject` to `PitchDiscriminationProfile` because test code uses `===` identity comparison on protocol-typed variables. Apply the same to `PitchMatchingProfile`. [Source: docs/implementation-artifacts/14-1 Debug Log]
- **Key learning: conformance is declarative when methods already exist** — in 14.1, `PerceptualProfile` already had all 8 methods. Here, we're ADDING new methods, so implementation is needed (not just conformance declaration).
- **Key learning: no default implementations in protocols** — all methods must be declared without defaults to ensure compile-time enforcement. [Source: Story 12.1 learning]
- **Key learning: update ALL conforming types** — when adding protocol methods, ensure all mocks and preview types are updated. For this story, no existing mocks need updating (no `PitchMatchingProfile` mock exists yet).
- **Code review pattern: check docstrings** — story 14.1 review found stale docstrings referencing old types. Be precise with any comments referencing type names.
- **Test count at 14.1 completion:** 422 tests passing (after code review fixes).

### Git Intelligence

```
c317de9 Fix code review findings for 14-1-extract-pitchdiscriminationprofile-protocol
feee989 Implement story 14.1: Extract PitchDiscriminationProfile Protocol
c87ef57 Add story 14.1: Extract PitchDiscriminationProfile Protocol
bed01cc Fix code review findings for 13-1-pitchmatchingrecord-data-model-and-trainingdatastore-extension
4a84ff7 Implement story 13.1: PitchMatchingRecord Data Model and TrainingDataStore Extension
```

- **Commit pattern:** `Add story X.Y: Title` for story creation, `Implement story X.Y: Title` for implementation, `Fix code review findings for X-Y-slug` for review fixes.
- **Recent work context:** Stories 13.1 (PitchMatchingRecord + TrainingDataStore extension) and 14.1 (PitchDiscriminationProfile extraction) are direct predecessors. This story builds on both: uses the data model from 13.1 and follows the protocol pattern from 14.1.
- **Story 13.1 created:** `PitchMatchingRecord`, `CompletedPitchMatching`, `PitchMatchingObserver`, `TrainingDataStore` CRUD + observer conformance, `MockTrainingDataStore` extension. All these are prerequisites for 14.2 and already exist.

### Existing Code Patterns to Follow

**Protocol file pattern** (mirroring `PitchDiscriminationProfile.swift`):
```swift
protocol PitchMatchingProfile: AnyObject {
    func updateMatching(note: Int, centError: Double)
    var matchingMean: Double? { get }
    var matchingStdDev: Double? { get }
    var matchingSampleCount: Int { get }
    func resetMatching()
}
```
No comments, no docstrings — method names are self-explanatory. (Architecture doc shows docstrings for illustration but project convention is no unnecessary comments.)

**Conformance declaration pattern** (mirroring 14.1):
Add `PitchMatchingProfile` to the class declaration directly:
```swift
@Observable
final class PerceptualProfile: PitchDiscriminationProfile, PitchMatchingProfile {
    // existing discrimination properties...
    // NEW matching aggregate properties...
}
```

**Observer extension pattern** (mirroring existing `ComparisonObserver` extension):
```swift
extension PerceptualProfile: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        updateMatching(note: result.referenceNote, centError: result.userCentError)
    }
}
```

**Welford's algorithm pattern** (mirroring existing `update()` in PerceptualProfile):
```swift
// Existing discrimination Welford's (reference):
stats.sampleCount += 1
let delta = centOffset - stats.mean
stats.mean += delta / Double(stats.sampleCount)
let delta2 = centOffset - stats.mean
stats.m2 += delta * delta2
```
Apply the same pattern to matching aggregates using `abs(centError)` as the input value.

**PeachApp.swift startup rebuild pattern** (mirroring existing comparison rebuild):
```swift
// Existing (discrimination):
let existingRecords = try dataStore.fetchAllComparisons()
for record in existingRecords {
    profile.update(note: record.note1, centOffset: abs(record.note2CentOffset), isCorrect: record.isCorrect)
}
// NEW (matching):
let pitchMatchingRecords = try dataStore.fetchAllPitchMatchings()
for record in pitchMatchingRecords {
    profile.updateMatching(note: record.referenceNote, centError: record.userCentError)
}
```

### Pitfalls and Anti-Patterns to Avoid

1. **Do NOT create a per-note matching array** — v0.2 uses overall aggregates only (3 scalar accumulators). Do not create a 128-slot array for matching. The protocol allows expansion later. [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]
2. **Do NOT use signed centError directly in Welford's** — take `abs(centError)` first. `matchingMean` is "mean absolute error", not "mean signed error". The signed value would average to near zero and be meaningless.
3. **Do NOT add `resetMatching()` to the existing `reset()` method** — the two resets are independent per AC #6. `reset()` clears discrimination only. `resetMatching()` clears matching only. Settings calls both.
4. **Do NOT create a mock for `PitchMatchingProfile`** — tests use real `PerceptualProfile`. A mock is only needed in story 15.1 when `PitchMatchingSession` is created.
5. **Do NOT modify `ComparisonSession`** — it depends only on `PitchDiscriminationProfile` and has no awareness of matching. The Settings reset goes through `SettingsScreen` → `comparisonSession.resetTrainingData()` + `profile.resetMatching()`.
6. **Do NOT add `@Observable` to the protocol** — it's a protocol, not a class. The macro is on `PerceptualProfile`.
7. **Do NOT use `any PitchMatchingProfile`** — bare protocol type is correct in a single-module app.
8. **Do NOT add `import Foundation` to the protocol file** — no Foundation types in the protocol signature (`Int`, `Double` are Swift stdlib).

### Project Structure Notes

- New protocol file `PitchMatchingProfile.swift` goes in `Core/Profile/` alongside `PitchDiscriminationProfile.swift` and `PerceptualProfile.swift` — matches architecture doc structure. [Source: docs/planning-artifacts/architecture.md#Updated-Project-Structure-v0.2]
- No new directories needed.
- No conflicts with existing structure.

### References

- [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]
- [Source: docs/planning-artifacts/architecture.md#Updated-Project-Structure-v0.2]
- [Source: docs/planning-artifacts/epics.md#Epic-14-Story-14.2]
- [Source: docs/project-context.md#Protocol-First-Design]
- [Source: docs/project-context.md#Testing-Rules]
- [Source: docs/project-context.md#Project-Specific-Naming]
- [Source: docs/project-context.md#Swift-6.2-Concurrency]
- [Source: Peach/Core/Profile/PerceptualProfile.swift — Welford's algorithm reference + conformance target]
- [Source: Peach/Core/Profile/PitchDiscriminationProfile.swift — protocol pattern to mirror]
- [Source: Peach/PitchMatching/PitchMatchingObserver.swift — observer protocol to conform to]
- [Source: Peach/PitchMatching/CompletedPitchMatching.swift — result type for observer]
- [Source: Peach/Core/Data/PitchMatchingRecord.swift — SwiftData model for startup rebuild]
- [Source: Peach/Core/Data/TrainingDataStore.swift — fetchAllPitchMatchings() for startup]
- [Source: Peach/App/PeachApp.swift — composition root, startup rebuild location]
- [Source: Peach/Settings/SettingsScreen.swift — reset action to extend]
- [Source: PeachTests/Comparison/MockTrainingDataStore.swift — mock pattern reference]
- [Source: docs/implementation-artifacts/14-1-extract-pitchdiscriminationprofile-protocol.md — previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues encountered.

### Completion Notes List

- Created `PitchMatchingProfile` protocol with `AnyObject` constraint (mirroring `PitchDiscriminationProfile` pattern from story 14.1)
- Implemented Welford's online algorithm for matching statistics using 3 scalar accumulators (`matchingCount`, `matchingMeanAbs`, `matchingM2`) — no per-note array per v0.2 spec
- `updateMatching(note:centError:)` takes `abs(centError)` before applying Welford's, producing mean absolute error as specified
- `PitchMatchingObserver` conformance added as extension at bottom of `PerceptualProfile.swift` (matching `ComparisonObserver` extension pattern)
- `PeachApp.swift` startup now reconstructs profile from both `ComparisonRecord` and `PitchMatchingRecord` data
- `SettingsScreen.resetAllTrainingData()` now calls both `comparisonSession.resetTrainingData()` and `profile.resetMatching()`
- 8 new tests added covering: conformance, cold start, Welford's mean/stdDev accuracy, single-sample edge case, reset independence (both directions), and observer integration
- All 430 tests pass (422 existing + 8 new), zero regressions

### Change Log

- 2026-02-26: Implemented story 14.2 — PitchMatchingProfile protocol, PerceptualProfile conformance with Welford's matching statistics, PitchMatchingObserver extension, startup profile rebuild from PitchMatchingRecord, Settings reset integration. 8 new tests, 430 total passing.
- 2026-02-26: Code review fixes — (1) `matchingStdDev` test: `try!` → `try`, function `async` → `async throws` (project pattern compliance), (2) `updateMatching`: added MIDI note range guard matching `update()` pattern, (3) removed extra blank line before MARK section.

### File List

New files:
- Peach/Core/Profile/PitchMatchingProfile.swift
- PeachTests/Core/Profile/PitchMatchingProfileTests.swift

Modified files:
- Peach/Core/Profile/PerceptualProfile.swift
- Peach/App/PeachApp.swift
- Peach/Settings/SettingsScreen.swift
- docs/implementation-artifacts/sprint-status.yaml
- docs/implementation-artifacts/14-2-pitchmatchingprofile-protocol-and-matching-statistics.md

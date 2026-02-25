# Story 14.1: Extract PitchDiscriminationProfile Protocol

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want the existing PerceptualProfile discrimination interface extracted into a protocol,
So that ComparisonSession and NextComparisonStrategy depend on an abstract interface rather than the concrete class.

## Acceptance Criteria

1. **PitchDiscriminationProfile protocol created** — Defines: `func update(note: Int, centOffset: Double, isCorrect: Bool)`, `func weakSpots(count: Int) -> [Int]`, `var overallMean: Double? { get }`, `var overallStdDev: Double? { get }`, `func statsForNote(_ note: Int) -> PerceptualNote`, `func averageThreshold(midiRange: ClosedRange<Int>) -> Int?`, `func setDifficulty(note: Int, difficulty: Double)`, `func reset()`. File located at `Core/Profile/PitchDiscriminationProfile.swift`.

2. **PerceptualProfile conforms to PitchDiscriminationProfile** — No implementation changes needed. Conformance is declarative — all methods already exist.

3. **ComparisonSession depends on PitchDiscriminationProfile (protocol)** — The `profile` property type changes from `PerceptualProfile` (concrete) to `PitchDiscriminationProfile` (protocol). Accepts any conforming type.

4. **NextComparisonStrategy depends on PitchDiscriminationProfile (protocol)** — The `nextComparison(profile:settings:lastComparison:)` parameter type changes from `PerceptualProfile` to `PitchDiscriminationProfile`. All implementations (`KazezNoteStrategy`, `AdaptiveNoteStrategy`) updated accordingly.

5. **All existing tests pass with zero functional changes** — This is a pure extraction refactoring. No behavior changes. Full test suite must pass.

## Tasks / Subtasks

- [x] Task 1: Create PitchDiscriminationProfile protocol (AC: #1)
  - [x] 1.1 Create `Peach/Core/Profile/PitchDiscriminationProfile.swift` with all 8 method/property declarations matching existing `PerceptualProfile` signatures exactly
  - [x] 1.2 Write tests: `PeachTests/Core/Profile/PitchDiscriminationProfileTests.swift` — verify `PerceptualProfile` conforms to `PitchDiscriminationProfile` (compile-time check via type assignment)

- [x] Task 2: Declare PerceptualProfile conformance (AC: #2)
  - [x] 2.1 Add `: PitchDiscriminationProfile` to `PerceptualProfile` class declaration
  - [x] 2.2 Verify conformance compiles — no new method implementations needed

- [x] Task 3: Update ComparisonSession to depend on protocol (AC: #3)
  - [x] 3.1 Change `ComparisonSession.init` parameter type from `PerceptualProfile` to `PitchDiscriminationProfile`
  - [x] 3.2 Change stored property type from `PerceptualProfile` to `PitchDiscriminationProfile`
  - [x] 3.3 Update `ComparisonTestHelpers.swift` factory method — the `profile` parameter and tuple field keep type `PerceptualProfile` (concrete) since tests need to call `update()` directly for setup, but verify it passes into `ComparisonSession` through the protocol type

- [x] Task 4: Update NextComparisonStrategy and implementations (AC: #4)
  - [x] 4.1 Change `NextComparisonStrategy.nextComparison(profile:settings:lastComparison:)` parameter type from `PerceptualProfile` to `PitchDiscriminationProfile`
  - [x] 4.2 Update `KazezNoteStrategy.nextComparison` — change `profile` parameter type to `PitchDiscriminationProfile`
  - [x] 4.3 Update `AdaptiveNoteStrategy.nextComparison` — change `profile` parameter type to `PitchDiscriminationProfile`
  - [x] 4.4 Update `MockNextComparisonStrategy` — change `lastReceivedProfile` type from `PerceptualProfile?` to `PitchDiscriminationProfile?`

- [x] Task 5: Update remaining consumers (AC: #3, #5)
  - [x] 5.1 Check `SummaryStatisticsView.computeStats(from:midiRange:)` — this uses `PerceptualProfile` directly. Leave as concrete type for now (Profile Screen will depend on both protocols in a later story per architecture doc)
  - [x] 5.2 Check `PeachApp.swift` — keeps concrete `PerceptualProfile` for instantiation and environment injection; no change needed (it creates the concrete instance)
  - [x] 5.3 Check preview mocks (`ComparisonScreen.swift` `MockNotePlayerForPreview`) — no profile dependency, no change needed

- [x] Task 6: Run full test suite and verify (AC: #5)
  - [x] 6.1 Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] 6.2 Verify all existing tests pass with zero regressions
  - [x] 6.3 Verify new conformance test passes

## Dev Notes

### Technical Requirements

- **Protocol-first design** — define `PitchDiscriminationProfile` protocol before declaring conformance. This is the project's standard pattern. [Source: docs/project-context.md#Error-Handling]
- **Protocol naming convention** — capability nouns without `-able` or `-Protocol` suffix: `PitchDiscriminationProfile`, not `PitchDiscriminationProfileProtocol`. [Source: docs/project-context.md#Project-Specific-Naming]
- **Default MainActor isolation** — do NOT add explicit `@MainActor` to the protocol. Swift 6.2 default isolation applies. [Source: docs/project-context.md#Concurrency]
- **No access control modifiers** — single-module app; `internal` is the default and should not be explicit. Never use `public` or `open`. [Source: docs/project-context.md#Access-Control]
- **`PerceptualNote` must remain accessible** — the protocol's `statsForNote(_:)` returns `PerceptualNote`. This struct is defined inside `PerceptualProfile.swift`. It must remain importable by protocol consumers. If it's currently nested or scoped, ensure it's a top-level type or accessible through the module.

### Architecture Compliance

- **Exact protocol signature from architecture doc** — the 8 members are specified in `docs/planning-artifacts/architecture.md` section "Profile Protocol Split — PitchDiscriminationProfile & PitchMatchingProfile". Use those signatures verbatim:
  ```swift
  protocol PitchDiscriminationProfile {
      func update(note: Int, centOffset: Double, isCorrect: Bool)
      func weakSpots(count: Int) -> [Int]
      var overallMean: Double? { get }
      var overallStdDev: Double? { get }
      func statsForNote(_ note: Int) -> PerceptualNote
      func averageThreshold(midiRange: ClosedRange<Int>) -> Int?
      func setDifficulty(note: Int, difficulty: Double)
      func reset()
  }
  ```
  [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

- **Dependency boundaries per architecture** — after this story:
  - `ComparisonSession` depends on `PitchDiscriminationProfile` (protocol)
  - `NextComparisonStrategy` depends on `PitchDiscriminationProfile` (protocol)
  - `PeachApp.swift` keeps concrete `PerceptualProfile` (composition root instantiates concrete types)
  - Profile Screen keeps concrete `PerceptualProfile` for now (will depend on both protocols in story 14.2+)
  [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]

- **ComparisonObserver conformance stays on PerceptualProfile** — the `ComparisonObserver` extension (`comparisonCompleted(_:)`) remains on the concrete class. It is NOT part of `PitchDiscriminationProfile`. The observer calls `update()` internally.
  [Source: Peach/Core/Profile/PerceptualProfile.swift]

- **`ComparisonSession` stores profile as protocol type but receives updates through observer pattern** — `ComparisonSession` holds `profile: PitchDiscriminationProfile` for reads (passing to strategy) and `reset()`. Profile updates happen through the observer array (`observers: [ComparisonObserver]`), where `PerceptualProfile` is added as a `ComparisonObserver`. The session never calls `profile.update()` directly.
  [Source: Peach/Comparison/ComparisonSession.swift]

### Library & Framework Requirements

- **No new dependencies** — this is a pure Swift protocol extraction. No libraries, frameworks, or imports beyond `Foundation` (if needed for `PerceptualNote`).
- **Zero third-party dependencies** — project rule. Do not add any external packages. [Source: docs/project-context.md#Technology-Stack]
- **Swift 6.2 protocol features** — standard protocol declaration. No associated types, no `some`/`any` complexity needed. The protocol is simple and concrete-type-returning (`PerceptualNote` is a specific struct, not an associated type).
- **`@Observable` interaction** — `PerceptualProfile` is `@Observable`. Protocol conformance does not interfere with the `@Observable` macro. The protocol itself should NOT be marked `@Observable` (it's a protocol, not a class).

### File Structure Requirements

**New files:**
| File | Location | Description |
|------|----------|-------------|
| `PitchDiscriminationProfile.swift` | `Peach/Core/Profile/` | Protocol with 8 method/property declarations |
| `PitchDiscriminationProfileTests.swift` | `PeachTests/Core/Profile/` | Conformance verification test |

**Modified files:**
| File | Location | Change |
|------|----------|--------|
| `PerceptualProfile.swift` | `Peach/Core/Profile/` | Add `: PitchDiscriminationProfile` conformance to class declaration |
| `ComparisonSession.swift` | `Peach/Comparison/` | Change `profile` property and init parameter type to `PitchDiscriminationProfile` |
| `NextComparisonStrategy.swift` | `Peach/Core/Algorithm/` | Change `profile` parameter type to `PitchDiscriminationProfile` |
| `KazezNoteStrategy.swift` | `Peach/Core/Algorithm/` | Change `profile` parameter type to `PitchDiscriminationProfile` |
| `AdaptiveNoteStrategy.swift` | `Peach/Core/Algorithm/` | Change `profile` parameter type to `PitchDiscriminationProfile` |
| `MockNextComparisonStrategy.swift` | `PeachTests/Comparison/` | Change `lastReceivedProfile` type to `PitchDiscriminationProfile?` |

**Unchanged files (verified no changes needed):**
| File | Reason |
|------|--------|
| `PeachApp.swift` | Creates concrete `PerceptualProfile`; passes to `ComparisonSession` which accepts protocol type via implicit upcasting |
| `SummaryStatisticsView.swift` | Uses concrete `PerceptualProfile` directly; Profile Screen refactor is a later story |
| `ProfileScreen.swift` | Holds `@Environment` with concrete type; unchanged until profile screen integration story |
| `ComparisonTestHelpers.swift` | Factory returns concrete `PerceptualProfile` in tuple; passes into `ComparisonSession` via protocol type — may need tuple field type update if tests reference `profile` through the tuple |
| `TrainingDataStore.swift` | No profile dependency |
| `ComparisonScreen.swift` | No direct profile dependency |

**Current `Core/Profile/` directory:**
```
Peach/Core/Profile/
├── PerceptualProfile.swift           # Modified: adds PitchDiscriminationProfile conformance
├── PitchDiscriminationProfile.swift  # NEW: protocol file
├── ThresholdTimeline.swift           # Unchanged
└── TrendAnalyzer.swift               # Unchanged
```

### Testing Requirements

- **Swift Testing only** — `@Test`, `@Suite`, `#expect()`. Never XCTest. [Source: docs/project-context.md#Testing-Rules]
- **All test functions must be `async`** — default MainActor isolation handles actor safety. [Source: docs/project-context.md#Testing-Rules]
- **No `test` prefix** on function names — `@Test` attribute marks the test. [Source: docs/project-context.md#Testing-Rules]
- **Behavioral test descriptions** — `@Test("PerceptualProfile conforms to PitchDiscriminationProfile")`. [Source: docs/project-context.md#Testing-Rules]
- **Run full suite**: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'` — never run only specific test files. [Source: docs/project-context.md#Pre-Commit-Gate]

**Minimal new test scope** — this is a pure extraction refactoring. The primary test is a compile-time conformance check:
```swift
@Test("PerceptualProfile conforms to PitchDiscriminationProfile")
func conformsToPitchDiscriminationProfile() async {
    let profile = PerceptualProfile()
    let _: PitchDiscriminationProfile = profile  // Compile-time conformance check
    #expect(profile is PitchDiscriminationProfile)
}
```

**No mock for PitchDiscriminationProfile needed in this story** — `ComparisonSession` tests use a real `PerceptualProfile` instance (which now conforms to the protocol). Mock creation for the protocol is deferred to when a second conforming type exists.

**Existing test count:** 421 tests as of story 13.1 code review. All must pass unchanged.

### Existing Code Patterns to Follow

**Protocol file pattern** (mirroring `NotePlayer.swift`, `NextComparisonStrategy.swift`):
```swift
// No imports needed unless Foundation types are used in signatures
protocol PitchDiscriminationProfile {
    func update(note: Int, centOffset: Double, isCorrect: Bool)
    func weakSpots(count: Int) -> [Int]
    var overallMean: Double? { get }
    var overallStdDev: Double? { get }
    func statsForNote(_ note: Int) -> PerceptualNote
    func averageThreshold(midiRange: ClosedRange<Int>) -> Int?
    func setDifficulty(note: Int, difficulty: Double)
    func reset()
}
```
No comments, no docstrings — the method names are self-explanatory.

**Conformance declaration pattern** (mirroring `PerceptualProfile: ComparisonObserver`):
The existing `ComparisonObserver` conformance is declared via extension at the bottom of `PerceptualProfile.swift`. For `PitchDiscriminationProfile`, add it directly to the class declaration since all methods are already in the main class body (not in an extension):
```swift
@Observable
final class PerceptualProfile: PitchDiscriminationProfile {
    // ... existing implementation unchanged
}
```

**`ComparisonSession` init pattern** — current signature:
```swift
init(notePlayer: NotePlayer, strategy: NextComparisonStrategy, profile: PerceptualProfile, observers: [ComparisonObserver], ...)
```
Change to:
```swift
init(notePlayer: NotePlayer, strategy: NextComparisonStrategy, profile: PitchDiscriminationProfile, observers: [ComparisonObserver], ...)
```

### Previous Story Intelligence (Story 13.1)

- **Key learning: Update ALL conforming types** — when adding protocol methods or changing signatures, ensure all conforming types (including test mocks and preview mocks) are updated. Story 12.1 learned this the hard way with `MockNotePlayerForPreview`.
- **Key learning: Dynamic dispatch for test mocks** — if a method is only in a protocol extension (not declared in the protocol), mocks can't override it. Declare all 8 methods directly in the protocol (no default implementations).
- **Key learning: `fetchAll()` was renamed to `fetchAllComparisons()`** in 13.1 code review — naming precision matters when multiple data types coexist.
- **Test count at 13.1 completion:** 421 tests passing (after code review fixes).
- **`MockTrainingDataStore`** was extended with `PitchMatchingObserver` conformance — pattern for adding protocol conformance to existing mocks.
- **Settings preview** requires array syntax for multiple models: `[ComparisonRecord.self, PitchMatchingRecord.self]` — no impact on this story but good to know.

### Git Intelligence

```
bed01cc Fix code review findings for 13-1-pitchmatchingrecord-data-model-and-trainingdatastore-extension
4a84ff7 Implement story 13.1: PitchMatchingRecord Data Model and TrainingDataStore Extension
3b86300 Add story 13.1: PitchMatchingRecord Data Model and TrainingDataStore Extension
737d647 Mark story 12.2 as won't do and close epics 11, 12
b34e86d Fix code review findings for 12-1-playbackhandle-protocol-and-noteplayer-redesign
```

- **Commit pattern:** `Add story X.Y: Title` for story creation, `Implement story X.Y: Title` for implementation, `Fix code review findings for X-Y-slug` for review fixes.
- **Recent work is refactoring-heavy** — stories 11.1 (renames), 12.1 (protocol redesign), 13.1 (data model). This story continues the refactoring theme.
- **Story 12.2 was marked `wont-do`** — `ComparisonSession` didn't need `PlaybackHandle` integration because `stopAll()` covered the need. Lesson: don't over-refactor when simpler solutions exist.

### Project Structure Notes

- New protocol file `PitchDiscriminationProfile.swift` goes in `Core/Profile/` alongside `PerceptualProfile.swift` — this matches the architecture document's updated project structure. [Source: docs/planning-artifacts/architecture.md#Updated-Project-Structure-v0.2]
- No new directories needed.
- No conflicts with existing structure.

### Pitfalls and Anti-Patterns to Avoid

1. **Do NOT add `any` keyword to protocol usage sites** — `profile: PitchDiscriminationProfile` is correct, not `profile: any PitchDiscriminationProfile`. In a single-module app with no existential boxing concerns, the bare protocol type is idiomatic.
2. **Do NOT create a mock for `PitchDiscriminationProfile` in this story** — tests use real `PerceptualProfile` which now conforms. A mock is only needed when a second conforming type is required for testing.
3. **Do NOT move `PerceptualNote` to a separate file** — it lives in `PerceptualProfile.swift` and is accessible module-wide. Moving it is unnecessary scope creep.
4. **Do NOT change `@Environment(\.perceptualProfile)` type** — the environment value stays as concrete `PerceptualProfile`. Protocol-based environment injection is not needed until the Profile Screen integration story.
5. **Do NOT add default implementations to the protocol** — all 8 methods must be declared without defaults. This ensures compile-time enforcement that conforming types implement everything. [Source: Story 12.1 learning — dynamic dispatch]
6. **Do NOT remove the `ComparisonObserver` extension** on `PerceptualProfile` — it stays. The observer pattern is separate from the discrimination profile protocol.

### References

- [Source: docs/planning-artifacts/architecture.md#Profile-Protocol-Split]
- [Source: docs/planning-artifacts/architecture.md#Updated-Project-Structure-v0.2]
- [Source: docs/planning-artifacts/epics.md#Epic-14-Story-14.1]
- [Source: docs/project-context.md#Protocol-First-Design]
- [Source: docs/project-context.md#Testing-Rules]
- [Source: docs/project-context.md#Project-Specific-Naming]
- [Source: docs/project-context.md#Swift-6.2-Concurrency]
- [Source: Peach/Core/Profile/PerceptualProfile.swift — source of truth for method signatures]
- [Source: Peach/Comparison/ComparisonSession.swift — primary consumer to update]
- [Source: Peach/Core/Algorithm/NextComparisonStrategy.swift — protocol to update]
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift — strategy implementation to update]
- [Source: Peach/Core/Algorithm/AdaptiveNoteStrategy.swift — strategy implementation to update]
- [Source: PeachTests/Comparison/MockNextComparisonStrategy.swift — test mock to update]
- [Source: PeachTests/Comparison/ComparisonTestHelpers.swift — verify factory compatibility]
- [Source: docs/implementation-artifacts/13-1-pitchmatchingrecord-data-model-and-trainingdatastore-extension.md — previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build failure: `(any PitchDiscriminationProfile)?` not usable with `===` identity operator in tests. Fixed by adding `AnyObject` constraint to protocol — all profile implementations are `@Observable` classes, so class constraint is semantically correct.

### Completion Notes List

- Created `PitchDiscriminationProfile` protocol with all 8 method/property declarations matching architecture doc verbatim
- Added `AnyObject` constraint to protocol (deviation from architecture doc) — required because test code uses `===` identity comparison on protocol-typed variables, and `PerceptualProfile` is a class (`@Observable`)
- Declared `PerceptualProfile: PitchDiscriminationProfile` conformance — purely declarative, zero implementation changes
- Updated `ComparisonSession` stored property and init parameter to protocol type
- Updated `NextComparisonStrategy` protocol and both implementations (`KazezNoteStrategy`, `AdaptiveNoteStrategy`) to use protocol type
- Updated `MockNextComparisonStrategy.lastReceivedProfile` to protocol type
- Verified `ComparisonTestHelpers.swift` needs no changes — concrete `PerceptualProfile` passes through protocol type via implicit upcasting
- Verified `PeachApp.swift`, `SummaryStatisticsView`, preview mocks need no changes
- All tests pass (419 test cases including 1 new conformance test)

### Change Log

- 2026-02-25: Implemented story 14.1 — extracted PitchDiscriminationProfile protocol from PerceptualProfile

### File List

**New files:**
- `Peach/Core/Profile/PitchDiscriminationProfile.swift`
- `PeachTests/Core/Profile/PitchDiscriminationProfileTests.swift`

**Modified files:**
- `Peach/Core/Profile/PerceptualProfile.swift`
- `Peach/Comparison/ComparisonSession.swift`
- `Peach/Core/Algorithm/NextComparisonStrategy.swift`
- `Peach/Core/Algorithm/KazezNoteStrategy.swift`
- `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift`
- `PeachTests/Comparison/MockNextComparisonStrategy.swift`
- `docs/implementation-artifacts/sprint-status.yaml`
- `docs/implementation-artifacts/14-1-extract-pitchdiscriminationprofile-protocol.md`

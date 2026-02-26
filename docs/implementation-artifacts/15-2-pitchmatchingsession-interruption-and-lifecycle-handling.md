# Story 15.2: PitchMatchingSession Interruption and Lifecycle Handling

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want pitch matching to handle interruptions gracefully — discarding incomplete attempts and returning to the Start Screen when appropriate,
So that my training data is never corrupted and the app behaves predictably when I switch away.

## Acceptance Criteria

1. **stop() from playingReference** — reference note audio is stopped via `notePlayer.stopAll()`, state transitions to `idle`, no result recorded, no observer notification.

2. **stop() from playingTunable** — tunable note handle is stopped via `currentHandle?.stop()`, incomplete attempt discarded (no result recorded, no observer notification), state transitions to `idle`.

3. **stop() from showingFeedback** — feedback timer (`feedbackTask`) is cancelled, state transitions to `idle`.

4. **stop() from idle** — no-op (guard returns immediately).

5. **App backgrounding stops session** — when `UIApplication.didEnterBackgroundNotification` is received during active pitch matching, `stop()` is called automatically and session transitions to `idle`. (The view layer handles returning to Start Screen in a later story, same pattern as ComparisonSession.)

6. **Audio interruption stops session** — when `AVAudioSession.interruptionNotification` is received with `.began` type, `stop()` is called automatically. When `.ended` is received, session remains stopped (no auto-resume).

7. **Audio route change stops session** — when `AVAudioSession.routeChangeNotification` is received with `.oldDeviceUnavailable` reason (headphones/Bluetooth disconnected), `stop()` is called. Other route changes do not stop the session.

8. **Navigation stop** — the view calls `session.stop()` before navigating away (view-layer concern, handled when PitchMatchingScreen is built in story 16.x; this story only ensures `stop()` is correct).

9. **All existing tests pass** — 452 tests from story 15.1 plus new tests for: stop() from each state, background notification handling, audio interruption handling, route change handling, idempotent stop calls, no observer notification on discarded attempts, training restarts after interruption.

## Tasks / Subtasks

- [x] Task 1: Enhance stop() method (AC: #1, #2, #3, #4)
  - [x] 1.1 Add `notePlayer.stopAll()` call to `stop()` — stops reference note audio when no handle exists (mirrors `ComparisonSession.stop()`)
  - [x] 1.2 Clear `currentChallenge` in `stop()` for clean state on restart
  - [x] 1.3 Write tests: stop from `playingReference` stops audio and transitions to idle, stop from `playingTunable` stops handle and transitions to idle, stop from `showingFeedback` cancels feedback timer and transitions to idle, stop from `idle` is no-op, stop does not notify observers
  - [x] 1.4 Verify existing stop test still passes

- [x] Task 2: Add audio interruption observers (AC: #6, #7)
  - [x] 2.1 Add `import AVFoundation` to PitchMatchingSession.swift
  - [x] 2.2 Add `audioInterruptionObserver: NSObjectProtocol?` and `audioRouteChangeObserver: NSObjectProtocol?` properties
  - [x] 2.3 Implement `setupAudioInterruptionObservers()` — register observers for `AVAudioSession.interruptionNotification` and `AVAudioSession.routeChangeNotification` (exact same pattern as `ComparisonSession`)
  - [x] 2.4 Implement `handleAudioInterruption(typeValue:)` — `.began` → stop(), `.ended` → no-op (log only)
  - [x] 2.5 Implement `handleAudioRouteChange(reasonValue:)` — `.oldDeviceUnavailable` → stop(), all others → log and continue
  - [x] 2.6 Call `setupAudioInterruptionObservers()` from `init`
  - [x] 2.7 Write tests: interruption began stops from playingTunable, interruption ended does not restart, nil type handled gracefully, interruption on idle is safe, route change oldDeviceUnavailable stops, non-stop route changes continue, route change on idle is safe

- [x] Task 3: Add app background notification observer (AC: #5)
  - [x] 3.1 Add `import UIKit` (for `UIApplication.didEnterBackgroundNotification`)
  - [x] 3.2 Add `backgroundObserver: NSObjectProtocol?` property
  - [x] 3.3 Register observer for `UIApplication.didEnterBackgroundNotification` in `setupAudioInterruptionObservers()` — calls `stop()` on receive
  - [x] 3.4 Write tests: background notification stops from playingTunable, background notification on idle is safe

- [x] Task 4: Add isolated deinit for cleanup (AC: #6, #7)
  - [x] 4.1 Add `isolated deinit` that removes all three notification observers from `notificationCenter`
  - [x] 4.2 Verify no memory leak or observer leak in test cleanup

- [x] Task 5: Update test factory and add restart tests (AC: #9)
  - [x] 5.1 Update `makePitchMatchingSession()` factory to accept `notificationCenter: NotificationCenter` parameter (default `.default`, pass to session)
  - [x] 5.2 Write test: training can restart after interruption stop
  - [x] 5.3 Write test: training can restart after route change stop
  - [x] 5.4 Write test: training can restart after background stop

- [x] Task 6: Run full test suite and verify (AC: #9)
  - [x] 6.1 Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] 6.2 Verify all existing 452 tests pass with zero regressions
  - [x] 6.3 Verify all new interruption/lifecycle tests pass

## Dev Notes

### Technical Requirements

- **Mirror `ComparisonSession` interruption pattern exactly** — `setupAudioInterruptionObservers()`, `handleAudioInterruption(typeValue:)`, `handleAudioRouteChange(reasonValue:)`. The code is nearly identical; adapt only the method names (e.g., `stop()` not `stopTraining()`). [Source: Peach/Comparison/ComparisonSession.swift:471-550]
- **`notePlayer.stopAll()` in `stop()`** — the current `stop()` only calls `currentHandle?.stop()`. When the session is in `playingReference`, there is no handle — the reference note is played via fixed-duration `play(frequency:duration:velocity:amplitudeDB:)`. `stopAll()` is the "panic button" that silences all audio. [Source: Peach/Core/Audio/NotePlayer.swift:63-68]
- **Notification observer closures must extract userInfo synchronously** before crossing actor boundary via `Task { @MainActor in }`. This is the pattern from ComparisonSession — prevents data races on notification payload. [Source: Peach/Comparison/ComparisonSession.swift:476-498]
- **`isolated deinit`** (Swift 6.1+ SE-0371) for MainActor-safe cleanup of notification observers. [Source: Peach/Comparison/ComparisonSession.swift:219-228]
- **Default MainActor isolation** — do NOT add explicit `@MainActor` to new methods. Only use `@MainActor` inside `@Sendable` closures (notification callbacks). [Source: docs/project-context.md#Concurrency]
- **Idempotent stop()** — must be safe to call from any state, including idle (no-op). Multiple rapid calls must not crash. [Source: docs/project-context.md#Error-Resilience]

### Architecture Compliance

- **Notification observer pattern from ComparisonSession (copy exactly):**
  ```swift
  audioInterruptionObserver = notificationCenter.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
  ) { [weak self] notification in
      let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
      Task { @MainActor [weak self] in
          self?.handleAudioInterruption(typeValue: typeValue)
      }
  }
  ```
  [Source: Peach/Comparison/ComparisonSession.swift:476-486]

- **Route change observer (copy exactly):**
  ```swift
  audioRouteChangeObserver = notificationCenter.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
  ) { [weak self] notification in
      let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
      Task { @MainActor [weak self] in
          self?.handleAudioRouteChange(reasonValue: reasonValue)
      }
  }
  ```
  [Source: Peach/Comparison/ComparisonSession.swift:489-499]

- **Background observer (new — not in ComparisonSession):**
  ```swift
  backgroundObserver = notificationCenter.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
  ) { [weak self] _ in
      Task { @MainActor [weak self] in
          self?.stop()
      }
  }
  ```

- **Enhanced stop() method (add `stopAll()` and clear `currentChallenge`):**
  ```swift
  func stop() {
      guard state != .idle else { return }
      Task {
          try? await notePlayer.stopAll()
      }
      trainingTask?.cancel()
      trainingTask = nil
      feedbackTask?.cancel()
      feedbackTask = nil
      let handleToStop = currentHandle
      currentHandle = nil
      referenceFrequency = nil
      currentChallenge = nil
      Task {
          try? await handleToStop?.stop()
      }
      state = .idle
  }
  ```
  Key difference from current: adds `notePlayer.stopAll()` (for reference note) and clears `currentChallenge`. ComparisonSession calls `stopAll()` as the first thing in its `stop()`. [Source: Peach/Comparison/ComparisonSession.swift:338-367]

- **`isolated deinit` pattern:**
  ```swift
  isolated deinit {
      if let observer = audioInterruptionObserver {
          notificationCenter.removeObserver(observer)
      }
      if let observer = audioRouteChangeObserver {
          notificationCenter.removeObserver(observer)
      }
      if let observer = backgroundObserver {
          notificationCenter.removeObserver(observer)
      }
  }
  ```
  [Source: Peach/Comparison/ComparisonSession.swift:219-228]

- **Scope boundary:** This story modifies `PitchMatchingSession` only. It does NOT:
  - Add UI screens (story 16.x)
  - Update ContentView to handle PitchMatchingSession backgrounding/navigation (story 17.x — ContentView currently only handles ComparisonSession)
  - Wire PitchMatchingSession into `PeachApp.swift` (story 16.x or later)

### Library & Framework Requirements

- **`import AVFoundation`** — for `AVAudioSession.interruptionNotification`, `AVAudioSession.routeChangeNotification`, `AVAudioSessionInterruptionTypeKey`, `AVAudioSessionRouteChangeReasonKey`, `AVAudioSession.InterruptionType`, `AVAudioSession.RouteChangeReason`.
- **`import UIKit`** — for `UIApplication.didEnterBackgroundNotification`. PitchMatchingSession is a service, not a view, so UIKit import is acceptable per project rules ("no UIKit in views"). [Source: docs/project-context.md#Framework-Specific-Rules]
- **No new dependencies** — all notification APIs are system frameworks. Zero third-party dependencies. [Source: docs/project-context.md#Technology-Stack]
- **Use existing `NotePlayer.stopAll()`** — already defined in protocol. `SoundFontNotePlayer` sends MIDI All Notes Off (CC 123). `MockNotePlayer` has `stopAllCallCount` for test verification. [Source: Peach/Core/Audio/NotePlayer.swift:63-68]

### File Structure Requirements

**Modified files:**
| File | Location | Changes |
|------|----------|---------|
| `PitchMatchingSession.swift` | `Peach/PitchMatching/` | Add imports, notification observers, enhanced stop(), isolated deinit |
| `PitchMatchingSessionTests.swift` | `PeachTests/PitchMatching/` | Add interruption/lifecycle tests, update factory |

**No new files.** All changes are additions to existing files created in story 15.1.

**`PitchMatching/` directory (unchanged):**
```
Peach/PitchMatching/
├── PitchMatchingSession.swift        # MODIFIED: interruption handling
├── PitchMatchingObserver.swift       # Exists (story 13.1)
├── CompletedPitchMatching.swift      # Exists (story 13.1)
└── PitchMatchingChallenge.swift      # Exists (architecture)
```

**Test directory (unchanged structure):**
```
PeachTests/PitchMatching/
├── PitchMatchingSessionTests.swift   # MODIFIED: add interruption tests
├── MockPitchMatchingProfile.swift    # Exists (story 15.1)
└── MockPitchMatchingObserver.swift   # Exists (story 15.1)
```

### Testing Requirements

- **Swift Testing only** — `@Test`, `@Suite`, `#expect()`. Never XCTest. [Source: docs/project-context.md#Testing-Rules]
- **All test functions must be `async`** — default MainActor isolation handles actor safety. [Source: docs/project-context.md#Testing-Rules]
- **Struct-based suites** — no classes, no `setUp`/`tearDown`; use factory methods. [Source: docs/project-context.md#Testing-Rules]
- **Run full suite**: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'` [Source: docs/project-context.md#Pre-Commit-Gate]
- **Inject `NotificationCenter`** for test isolation — create a fresh `NotificationCenter()` per test, pass to session via factory. This prevents cross-test notification interference. [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:13-14]

**Update factory method** to support `notificationCenter`:
```swift
func makePitchMatchingSession(
    settingsOverride: TrainingSettings? = TrainingSettings(),
    noteDurationOverride: TimeInterval? = 0.0,
    notificationCenter: NotificationCenter = .default
) -> (session: PitchMatchingSession, notePlayer: MockNotePlayer, profile: MockPitchMatchingProfile, observer: MockPitchMatchingObserver) {
    let notePlayer = MockNotePlayer()
    let profile = MockPitchMatchingProfile()
    let observer = MockPitchMatchingObserver()
    let session = PitchMatchingSession(
        notePlayer: notePlayer,
        profile: profile,
        observers: [observer],
        settingsOverride: settingsOverride,
        noteDurationOverride: noteDurationOverride,
        notificationCenter: notificationCenter
    )
    return (session, notePlayer, profile, observer)
}
```

**Test patterns to mirror** (from `ComparisonSessionAudioInterruptionTests.swift`):

1. **Audio interruption began stops from each state:**
   - Post `AVAudioSession.interruptionNotification` with `[AVAudioSessionInterruptionTypeKey: InterruptionType.began.rawValue]`
   - Verify `session.state == .idle` via `waitForState`
   [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:12-27]

2. **Audio interruption ended does NOT auto-restart:**
   - Post `.began` then `.ended`
   - Verify session remains idle after sleep
   [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:76-100]

3. **Nil type handled gracefully:**
   - Post with `userInfo: nil`
   - Verify session continues (no crash, no state change)
   [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:102-119]

4. **Interruption on idle is safe:**
   - Post `.began` while idle
   - Verify remains idle, no crash
   [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:121-137]

5. **Route change oldDeviceUnavailable stops session:**
   - Post `AVAudioSession.routeChangeNotification` with `[AVAudioSessionRouteChangeReasonKey: RouteChangeReason.oldDeviceUnavailable.rawValue]`
   [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:141-157]

6. **Non-stop route changes continue training:**
   - Test `.newDeviceAvailable`, `.categoryChange`, nil
   - Verify session continues
   [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:159-186]

7. **Can restart after interruption/route change:**
   - Stop via notification, then `startPitchMatching()` again
   - Verify session reaches `playingTunable`
   [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:208-246]

**New test structure** — add a new `@Suite` for interruption tests or add to existing:
```swift
@Suite("PitchMatchingSession Audio Interruption Tests", .serialized)
struct PitchMatchingSessionAudioInterruptionTests {
    // Tests here mirror ComparisonSessionAudioInterruptionTests
}
```
Use `.serialized` to prevent parallel execution of notification-posting tests.

**Key stop() tests to write:**

1. **stop from playingReference** — use `instantPlayback = false`, `simulatedPlaybackDuration = 5.0` to hold in `playingReference` state; call `stop()`; verify `state == .idle` and `notePlayer.stopAllCallCount >= 1`
2. **stop from playingTunable** — start, wait for `playingTunable`; call `stop()`; verify `state == .idle` and `lastHandle.stopCallCount >= 1`
3. **stop from showingFeedback** — commit result, wait for `showingFeedback`; call `stop()`; verify `state == .idle` and session does NOT advance to next challenge
4. **stop from idle is no-op** — verify calling `stop()` on fresh session doesn't crash, state remains `idle`
5. **stop does not notify observers** — stop from `playingTunable`; verify `observer.pitchMatchingCompletedCallCount == 0`
6. **double stop is safe** — stop twice rapidly; verify no crash

### Previous Story Intelligence (Story 15.1)

- **452 tests passing** as of story 15.1 completion (including code review fixes). All must pass unchanged.
- **Handle race condition fix (M1)** — `commitResult` and `stop()` capture handle locally and nil `currentHandle` synchronously before spawning async stop Task. This pattern must be preserved — do not regress. [Source: docs/implementation-artifacts/15-1-pitchmatchingsession-core-state-machine.md#Code-Review-Fixes]
- **`waitForState` helper** already exists with `Issue.record()`, `Task.yield()`, and 5ms poll interval. Reuse directly — do not create a new one. [Source: PeachTests/PitchMatching/PitchMatchingSessionTests.swift:7-21]
- **`MockNotePlayer.instantPlayback`** — set `false` with `simulatedPlaybackDuration = 5.0` to hold session in `playingReference` state for testing stop() during reference note. [Source: PeachTests/PitchMatching/PitchMatchingSessionTests.swift:95-96]
- **`MockNotePlayer.stopAllCallCount`** — verify `notePlayer.stopAll()` is called in stop(). Check existing MockNotePlayer for this property.
- **Existing stop() test** — `stopTransitionsToIdle` at line 310 already tests basic stop from `playingTunable`. Keep it; add more comprehensive stop tests.
- **Code review learnings:** stale docstrings, unused dependency comments. Do not add unnecessary documentation.

### Git Intelligence

```
5253417 Fix code review findings for 15-1-pitchmatchingsession-core-state-machine
d483f4c Implement story 15.1: PitchMatchingSession Core State Machine
709c8c4 Add story 15.1: PitchMatchingSession Core State Machine
397fef8 Fix code review findings for 14-2-pitchmatchingprofile-protocol-and-matching-statistics
486b158 Implement story 14.2: PitchMatchingProfile Protocol and Matching Statistics
```

- **Files from 15.1:** `Peach/PitchMatching/PitchMatchingSession.swift` (199 lines), `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` (342 lines), `PeachTests/PitchMatching/MockPitchMatchingProfile.swift`, `PeachTests/PitchMatching/MockPitchMatchingObserver.swift`
- **Commit pattern:** `Add story X.Y: Title` → `Implement story X.Y: Title` → `Fix code review findings for X-Y-slug`
- **Story 3.4 is the direct analog** — "Training Interruption and App Lifecycle Handling" for ComparisonSession. Mirror it exactly for PitchMatchingSession. [Source: docs/implementation-artifacts/3-4-training-interruption-and-app-lifecycle-handling.md]

### Existing Code Patterns to Follow

**ComparisonSession `setupAudioInterruptionObservers()` (lines 474-502):**
- Two observers: `AVAudioSession.interruptionNotification` and `AVAudioSession.routeChangeNotification`
- Both use `queue: .main` and `[weak self]` with `Task { @MainActor in }`
- Extract notification data synchronously BEFORE the `Task { @MainActor in }` closure
- PitchMatchingSession adds a third: `UIApplication.didEnterBackgroundNotification`

**ComparisonSession `stop()` (lines 338-367):**
- Calls `notePlayer.stopAll()` first (Task-wrapped)
- Cancels `trainingTask` and `feedbackTask`
- Resets all state (`currentComparison`, `lastCompletedComparison`, `sessionBestCentDifference`)
- Sets `state = .idle`

**ComparisonSession `isolated deinit` (lines 219-228):**
- Removes both notification observers from `notificationCenter`

**ComparisonSession interruption test patterns** (ComparisonSessionAudioInterruptionTests.swift):
- Separate `@Suite` with `.serialized` trait
- Fresh `NotificationCenter()` per test
- Post notification, `waitForState(.idle)`, verify
- Test all states, nil payloads, restart capability

### Pitfalls and Anti-Patterns to Avoid

1. **Do NOT forget `notePlayer.stopAll()` in `stop()`** — without it, the reference note keeps playing after stop() during `playingReference` state. The current `stop()` only stops `currentHandle` which is nil during reference note playback.
2. **Do NOT use `object: nil` for audio notifications** — must use `object: AVAudioSession.sharedInstance()`. Using nil would catch audio interruptions from all sessions. [Source: Peach/Comparison/ComparisonSession.swift:478]
3. **Do NOT auto-resume after interruption ends** — "instant stop, no auto-resume" is a UX principle. [Source: Peach/Comparison/ComparisonSession.swift:520-522]
4. **Do NOT extract notification data inside `Task { @MainActor in }`** — must extract `typeValue` / `reasonValue` synchronously in the closure BEFORE crossing actor boundary. This prevents a data race. [Source: Peach/Comparison/ComparisonSession.swift:482]
5. **Do NOT share `NotificationCenter.default` across tests** — each test must create its own `NotificationCenter()` for isolation. [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift:13-14]
6. **Do NOT create a separate test file** — add interruption tests to the existing `PitchMatchingSessionTests.swift` as a new `@Suite`, or add to the existing suite. Keep things co-located.
7. **Do NOT modify `ComparisonSession`** — changes are isolated to PitchMatchingSession.
8. **Do NOT modify `ContentView`** — app backgrounding navigation (popping to Start Screen for PitchMatchingSession) belongs in story 16.x/17.x when PitchMatchingScreen is created.
9. **Do NOT add explicit `@MainActor`** — redundant with default isolation. Only use in `@Sendable` closures (notification callbacks). [Source: docs/project-context.md#Concurrency]
10. **Do NOT use Combine** for notification observation — use `NotificationCenter.addObserver(forName:)` closure API. [Source: docs/project-context.md#Never-Do-This]

### Project Structure Notes

- All changes are in existing files — no new files, no new directories.
- `PitchMatchingSession.swift` stays in `Peach/PitchMatching/` — same location as story 15.1.
- Tests stay in `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` — add new `@Suite` for interruption tests.

### References

- [Source: Peach/Comparison/ComparisonSession.swift:338-367 — stop() pattern with stopAll()]
- [Source: Peach/Comparison/ComparisonSession.swift:471-550 — audio interruption/route change observers]
- [Source: Peach/Comparison/ComparisonSession.swift:219-228 — isolated deinit pattern]
- [Source: PeachTests/Comparison/ComparisonSessionAudioInterruptionTests.swift — complete test patterns]
- [Source: Peach/Core/Audio/NotePlayer.swift:63-68 — stopAll() protocol method]
- [Source: Peach/PitchMatching/PitchMatchingSession.swift — current implementation from 15.1]
- [Source: PeachTests/PitchMatching/PitchMatchingSessionTests.swift — current tests and factory]
- [Source: Peach/App/ContentView.swift — scenePhase handling pattern (view-layer backgrounding)]
- [Source: docs/planning-artifacts/epics.md#Story-15.2 — acceptance criteria]
- [Source: docs/planning-artifacts/architecture.md#PitchMatchingSession-State-Machine — architecture spec]
- [Source: docs/project-context.md#Technology-Stack — Swift 6.2, AVFoundation, zero dependencies]
- [Source: docs/project-context.md#Concurrency — default MainActor isolation]
- [Source: docs/project-context.md#Testing-Rules — Swift Testing, async tests, struct suites]
- [Source: docs/project-context.md#Error-Resilience — error boundary, interruption handling]
- [Source: docs/project-context.md#Never-Do-This — no Combine, no ObservableObject]
- [Source: docs/implementation-artifacts/15-1-pitchmatchingsession-core-state-machine.md — previous story]
- [Source: docs/implementation-artifacts/3-4-training-interruption-and-app-lifecycle-handling.md — ComparisonSession interruption story analog]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Build failure: missing `import UIKit` in test file for `UIApplication.didEnterBackgroundNotification` — fixed by adding `import UIKit` to PitchMatchingSessionTests.swift

### Completion Notes List

- Enhanced `stop()` to call `notePlayer.stopAll()` first (stops reference note audio during `playingReference` state) and clear `currentChallenge` for clean restart
- Added audio interruption observer (`AVAudioSession.interruptionNotification`) — `.began` stops session, `.ended` is no-op (no auto-resume)
- Added route change observer (`AVAudioSession.routeChangeNotification`) — `.oldDeviceUnavailable` stops session, all other reasons continue
- Added background observer (`UIApplication.didEnterBackgroundNotification`) — stops session on app backgrounding
- Added `isolated deinit` for cleanup of all three notification observers
- Updated test factory with `notificationCenter` parameter for test isolation
- All patterns mirror ComparisonSession exactly: synchronous userInfo extraction before actor boundary crossing, `[weak self]` captures, `Task { @MainActor in }` dispatch
- 473 tests pass (452 existing + 21 new), zero regressions

### Change Log

- 2026-02-26: Implemented story 15.2 — PitchMatchingSession interruption and lifecycle handling
- 2026-02-26: Code review fixes — added missing state guard after tunable note play(), added logging to stop(), added interruption tests from playingReference and showingFeedback states

### Senior Developer Review (AI)

**Reviewer:** Michael on 2026-02-26
**Outcome:** Approved with fixes applied

**Findings (3 fixed, 3 noted):**

| # | Severity | Description | Status |
|---|----------|-------------|--------|
| H1 | HIGH | Missing state guard after tunable note `play()` in `playNextChallenge()` — orphaned handle possible if `stop()` called during await | Fixed |
| M1 | MEDIUM | Missing test coverage for audio interruption from `playingReference` and `showingFeedback` states | Fixed |
| M2 | MEDIUM | `stop()` method lacked logging (ComparisonSession logs state transitions) | Fixed |
| L1 | LOW | `setupAudioInterruptionObservers()` name misleading (sets up 3 observers, not just audio) | Noted |
| L2 | LOW | Test function naming inconsistent with ComparisonSession reference (camelCase vs underscores) | Noted |
| L3 | LOW | Completion Notes reported 18 new tests but actual count was 19 | Noted (corrected to 21 after fixes) |

### File List

- Peach/PitchMatching/PitchMatchingSession.swift (modified: added imports, notification observers, enhanced stop(), isolated deinit, state guard after tunable play, logging)
- PeachTests/PitchMatching/PitchMatchingSessionTests.swift (modified: added stop() tests, audio interruption suite, background tests, restart tests, updated factory, playingReference/showingFeedback interruption tests)

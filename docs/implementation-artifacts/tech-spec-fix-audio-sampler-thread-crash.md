---
title: 'Fix AVAudioUnitSampler thread-unsafe reset crash'
type: 'bugfix'
created: '2026-04-25'
status: 'done'
baseline_commit: '83681ae'
context: ['docs/project-context.md']
---

# Fix AVAudioUnitSampler thread-unsafe reset crash

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `SoundFontEngine.scheduleEvents()` calls `sampler.auAudioUnit.reset()` on the main thread while the audio render thread is concurrently processing MIDI events. This triggers a `CAVerboseAbort` in Apple's `SamplerBaseElement::IncrementActiveLayerVoiceCount`, crashing the test host process. The crash is non-deterministic — whichever tests are in flight when it happens get reported as "failed" at 0.000 seconds, causing widespread, seemingly random test failures every session.

**Approach:** Replace the main-thread `.reset()` call with a render-thread-safe "All Notes Off" (MIDI CC#123) mechanism. Add an atomic `needsAllNotesOff` flag to `DoubleBufferedScheduleState`. The main thread sets the flag; the render thread consumes it on generation change and dispatches CC#123 to all active channels from its own thread.

## Boundaries & Constraints

**Always:** All `AVAudioUnitSampler` interactions that affect voice state (note-on, note-off, reset, CC) must happen on the audio render thread or via the sampler's high-level API when no render callback is active. The lock-free double-buffer protocol must remain intact.

**Ask First:** Any change to the render callback signature or the `DoubleBufferedScheduleState` memory layout beyond adding the flag.

**Never:** Do not call `auAudioUnit.reset()` from the main thread while the render callback is active. Do not add locks or blocking synchronization to the render callback (real-time thread).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Schedule replacement | `scheduleEvents()` called while render thread processes old schedule | Old notes silenced via CC#123 on render thread; new schedule starts cleanly | N/A |
| Rapid replacement | Multiple `scheduleEvents()` calls before render thread processes any | Flag remains set; CC#123 fires once on next generation change detection | N/A |
| Clear schedule | `clearSchedule()` called | No CC#123 (flag not set); notes ring out naturally | N/A |
| Create channel | `createChannel()` called | No CC#123 (flag not set); existing notes continue | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Core/Audio/SoundFontEngine.swift` -- Main fix: DoubleBufferedScheduleState flag + scheduleEvents + render callback
- `Peach/Settings/IntervalSelection.swift` -- Boy Scout Rule: explicit Equatable to prevent RawRepresentable JSON comparison non-determinism (discovered during investigation)
- `PeachTests/Core/Audio/SoundFontEngineTests.swift` -- Verify no crash on rapid schedule replacement (existing tests cover this)
- `docs/pre-existing-findings.md` -- Close PF-004 (misdiagnosed; was collateral from this crash)

## Tasks & Acceptance

**Execution:**
- [ ] `Peach/Core/Audio/SoundFontEngine.swift` -- Add `needsAllNotesOff: Atomic<Bool>` to `DoubleBufferedScheduleState`; initialize to `false`
- [ ] `Peach/Core/Audio/SoundFontEngine.swift` -- In `scheduleEvents()`, replace the `sampler.auAudioUnit.reset()` loop with `scheduleState.needsAllNotesOff.store(true, ordering: .relaxed)` before the `swapScheduleSlot` call
- [ ] `Peach/Core/Audio/SoundFontEngine.swift` -- In the render callback's generation-change block, consume the flag via `.exchange(false, ordering: .relaxed)` and dispatch CC#123 (status `0xB0 | ch`, data1 `123`, data2 `0`) via the slot's MIDI blocks to all channels that have a block
- [ ] `docs/pre-existing-findings.md` -- Update PF-004 disposition to CLOSED with reference to this fix

**Acceptance Criteria:**
- Given rapid `scheduleEvents()` calls during active audio rendering, when the test suite runs 5 consecutive times, then zero crashes occur (zero 0.000s failures)
- Given `scheduleEvents()` replaces an active schedule, when the render thread detects the generation change, then CC#123 is sent on the render thread (not the main thread)
- Given `createChannel()` or `clearSchedule()` is called, when the render thread detects the generation change, then no CC#123 is sent

## Design Notes

The `.reset()` call was originally added to "flush stale MIDI events" on schedule replacement. CC#123 (All Notes Off) achieves the same outcome — it silences any lingering note-ons from the replaced schedule — but is safe to dispatch from the render thread via the `scheduleMIDIEventBlock`. The flag piggybacks on the generation counter's release/acquire fence: the main thread stores the flag before the releasing generation bump, so the render thread sees it after its acquiring generation load.

## Verification

**Commands:**
- `bin/test.sh && bin/test.sh -p mac` -- expected: all tests pass on both platforms
- Run `bin/test.sh` 5 times consecutively -- expected: zero crashes (zero 0.000s failures)

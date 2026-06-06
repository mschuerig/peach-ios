# Performance and Debugging

## Instruments templates

### Audio System Trace

The primary "did I glitch, and why" tool. Per-cycle render activity on the audio I/O thread: deadline (start/end), whether each cycle hit or missed, and the work done inside. Combined with Thread State, you see whether the render thread was preempted, blocked on a lock, or waiting for a workgroup peer.

Open Xcode → Instruments → Audio System Trace template. Profile on device under load; record around the symptom.

### Time Profiler with "Record Waiting Threads"

Critical for audio. Without "Record Waiting Threads" enabled, a render thread blocked on a mutex shows zero samples — invisible. With it enabled, you see exactly where it parks and which thread holds the lock.

Settings → recording options → check "Record Waiting Threads".

### System Trace

Syscall / VM activity. Use when Audio System Trace shows a missed deadline but the render code looks clean — typically the culprit is a page fault, `malloc` going to the kernel, or an unexpected `pthread_mutex` syscall.

### Allocations

Scope a region of interest to the render block. A non-zero allocation count inside the render region is a defect — pre-allocate or use a lock-free pool.

### Leaks / Thread Sanitizer

Complement Allocations for lifetime and data-race bugs. **TSan must not ship** — it dilates the render thread; only use during dev/test.

## Debugging tools

### AU Lab (macOS)

Minimal AUv3 host downloadable from Apple's Additional Tools for Xcode. Iterate on a plugin in isolation with the AU view loaded and routing visible. Faster than launching Logic for every build.

### `auval` / `auvaltool`

Apple's Audio Unit validation CLI. Tests format negotiation, parameter ranges, render correctness, MIDI, state save/restore, offline rendering.

**Required by hosts** (Logic, GarageBand, MainStage) and effectively mandatory before shipping an AUv3 extension; failures here are the most common reason a plugin doesn't appear in a host.

```bash
auval -v aufx Xmpl ACME
```

`-v <type> <subtype> <manufacturer>`. Inspect the full report, not just the pass/fail line. Run after every signing or Info.plist change.

### Console.app

Filter by subsystem:

- `com.apple.audio.AudioToolbox`
- `com.apple.coreaudio`
- `com.apple.coremidi`
- `com.apple.audio.AVFAudio`

Watch processes `coreaudiod` and `mediaserverd`. AVAudioEngine logs configuration changes and graph reconfigures here.

### sysdiagnose

For customer-reported glitches you can't reproduce. Triggering on iOS: **Volume Up + Volume Down + Power**. Captures `coreaudiod` state, IOAudio kext logs, and the system log window around the failure.

## Instrumenting render code

### `os_signpost`

Marks render boundaries; shows up in Instruments. **Caveat**: the signpost API takes a logging path that *may* take locks or grow buffers on first emission; Apple has not published an RT-safety guarantee. Empirically it's usually fine when the `OSLog` is created and warm before audio starts, but verify per Xcode/OS version and disable in release with a compile-time flag.

Doumler and others recommend writing render telemetry to a lock-free SPSC ring and emitting signposts from a non-RT consumer thread.

### `AURenderObserver`

Registered on an `AUAudioUnit` to receive `AURenderEvent`s out of band. Useful for tracing parameter ramps and scheduled MIDI without instrumenting the render block itself.

### `AURenderEventType`

Discriminator on the event union you walk inside the render block:

- `.parameter`, `.parameterRamp`
- `.MIDI`, `.MIDISysEx`
- `.midiEventList`

## Reproducing dropouts

Force the failure:

- Max polyphony, deepest effects chain, smallest I/O buffer (`setPreferredIOBufferDuration`).
- Add CPU pressure: background Xcode build, `yes > /dev/null &`.
- On device, throttle thermals by running under load.
- Trigger route changes (unplug headphones, toggle Bluetooth) to exercise `AVAudioEngineConfigurationChangeNotification` and `mediaServicesWereResetNotification`.
- Network / low-memory events can take allocator locks — exercise them.

Capture with Audio System Trace running; the missed cycle and surrounding thread state will be in the trace.

## Detection in code

- `AVAudioEngine.configurationChangeNotification` — graph torn down → rebuild and restart.
- `AVAudioSession.mediaServicesWereResetNotification` — rare, total reset → reconfigure session and engine from scratch.
- `AUAudioUnit.renderResourcesAllocated` — `false` until resources are allocated.
- Inspect `AUAudioUnitStatus` returned from render blocks; non-`noErr` returns are dropouts you caused.

## A workflow for "I think it's glitching"

1. **Reproduce.** Get a deterministic recipe. "Once an hour on a 12 Pro Max" is not enough.
2. **Capture an Audio System Trace** with the recipe running. Look for missed cycles.
3. **Time-Profile** with Waiting Threads enabled. Are the render thread and a non-RT thread fighting over the same lock?
4. **Allocations** with the render region scoped. Is the render block allocating?
5. **Console** for the subsystems above. Did the engine log a configuration change you didn't handle?
6. **sysdiagnose** if customer reported. Look at `coreaudiod.log` and underrun counters.

## Common diagnostic findings

| What the trace shows | Cause |
|---|---|
| Render cycle ends late; preceded by a long `lck_mtx_lock` syscall | A lock you took on the render thread, or a lock another thread holds and the render thread waits on |
| Render cycle ends late; preceded by `malloc` | Allocation on the render thread |
| Render cycle ends late; preceded by a page fault | Untouched buffer; pre-touch pages at setup |
| Engine stopped; "configuration change" logged | Route change; observe `configurationChangeNotification` |
| `mediaserverd` crashed and respawned | `mediaServicesWereResetNotification`; rebuild everything |
| `auval` fails on parameter validation | Parameter range or default out of bounds |
| `auval` fails on render correctness | Bad output; check input/output bus formats |

## Authoritative sources

- Analyzing audio performance with Instruments — https://developer.apple.com/documentation/audiotoolbox/analyzing-audio-performance-with-instruments
- AVAudioEngine configurationChangeNotification — https://developer.apple.com/documentation/avfoundation/avaudioengine/configurationchangenotification
- AVAudioSession mediaServicesWereResetNotification — https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
- WWDC20 — "Meet Audio Workgroups" — https://developer.apple.com/videos/play/wwdc2020/10224/
- WWDC16 — "System Trace in Depth" — https://developer.apple.com/videos/play/wwdc2016/411/
- `auvaltool` references:
  - https://forrestcli.com/tools/auvaltool
  - https://moonbase.sh/articles/debugging-your-audio-unit-plugin-with-auval-aka-auvaltool/
  - https://www.audiodog.co.uk/blog/2022/07/17/how-to-validate-core-audio-units/
- Michael Tyson — "Four common mistakes in audio development" — atastypixel.com (often slow / 500s; cite URL, verify before quoting)
- Timur Doumler — ADC and CppCon talks on real-time programming

## Verification status

`os_signpost` RT-safety nuance, `AURenderObserver` semantics, and the `AURenderEventType` cases shift between Xcode/OS versions. Verify against the headers shipped in the Xcode version you target (`<AudioToolbox/AudioUnitProperties.h>`, `<os/signpost.h>`).

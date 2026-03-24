---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: []
workflowType: 'research'
lastStep: 2
research_type: 'technical'
research_topic: 'iOS Audio Latency Optimization for Real-Time Rhythm Training'
research_goals: 'Identify and fix latency/jitter issues in continuous rhythm match discipline; achieve real-time tap-to-sound responsiveness comparable to professional music apps like AUM'
user_name: 'Michael'
date: '2026-03-24'
web_research_enabled: true
source_verification: true
---

# iOS Audio Latency Optimization for Real-Time Rhythm Training

**Date:** 2026-03-24
**Author:** Michael
**Target:** iOS 26+

---

## Executive Summary

The continuous rhythm match discipline in Peach has perceptible latency and jitter because of three integration-layer issues between the UI and the audio engine — **not** because of the audio engine itself. Peach's core audio architecture (render-thread MIDI scheduling, pre-allocated buffers, non-blocking locks, batch scheduling) is architecturally sound and comparable to what professional apps use.

The dominant issue is that the **SwiftUI Button fires on finger lift (touch-up), not finger press (touch-down)**, adding 50-200ms of latency. Professional music apps universally trigger sound on touch-down. Two secondary issues — a **dual clock domain** (wall-clock vs. audio-thread sample counter) causing 10-30ms of timing jitter, and **audio session buffer preference set after activation** (possibly ignored, falling back to 20ms instead of 5ms) — compound the problem.

**Three fixes, in order of priority:**

1. **Replace SwiftUI Button with `DragGesture(minimumDistance: 0)`** — fires on touch-down. Expected improvement: -50 to -200ms. Small effort.
2. **Reorder audio session configuration** — set `setPreferredIOBufferDuration(0.005)` before `setActive(true)`, log actual `ioBufferDuration`. Trivial effort.
3. **Unify clock domains** — replace `CACurrentMediaTime()` timing with `currentSamplePosition` from the audio render thread. Eliminates jitter. Medium effort.

**After all three fixes, expected total tap-to-sound latency: 13-27ms** (8-17ms unavoidable touch delivery + 5-10ms audio buffer), which is comparable to AUM and other professional music apps.

---

## Table of Contents

1. [Technology Stack Analysis](#technology-stack-analysis) — iOS audio API hierarchy, AVAudioSession configuration, AVAudioUnitSampler dispatch, how AUM achieves low latency, real-time thread constraints, touch event latency
2. [Peach Codebase: Identified Latency Sources](#peach-codebase-identified-latency-sources) — 6 specific latency sources with code locations and estimated impact
3. [Summary of Latency Budget](#summary-of-latency-budget) — Worst-case vs. best-case latency breakdown
4. [Integration Patterns: Concrete Fix Implementations](#integration-patterns-concrete-fix-implementations) — 5 fixes with code examples, ordered by priority
5. [Architectural Patterns and Design Analysis](#architectural-patterns-and-design-analysis) — What Peach does right, dual clock domain anti-pattern, immediate-play path, thread safety analysis
6. [Implementation Approaches and Verification](#implementation-approaches-and-verification) — Phased implementation strategy, 3 verification methods, testing strategy, risk assessment

---

## Research Overview

This report investigates why the continuous rhythm match discipline in Peach exhibits perceptible latency and jitter when tapping, making it unusable for rhythm training. The root causes were identified through web research into iOS audio APIs, analysis of the Peach codebase (`SoundFontEngine`, `SoundFontStepSequencer`, `ContinuousRhythmMatchingSession`, `ContinuousRhythmMatchingScreen`), and comparison with low-latency patterns used by professional music apps like AUM.

**Key finding:** The audio engine is correctly implemented. The problems are in the UI-to-engine integration: touch event handling (SwiftUI Button = touch-up), timing model (dual clock domains), and audio session configuration order. See the Executive Summary for the three prioritized fixes and the full sections below for detailed analysis and code.

---

## Technical Research Scope Confirmation

**Research Topic:** iOS Audio Latency Optimization for Real-Time Rhythm Training
**Research Goals:** Identify and fix latency/jitter issues in continuous rhythm match discipline; achieve real-time tap-to-sound responsiveness comparable to professional music apps like AUM

**Technical Research Scope:**

- Architecture Analysis - design patterns, frameworks, system architecture
- Implementation Approaches - development methodologies, coding patterns
- Technology Stack - languages, frameworks, tools, platforms
- Integration Patterns - APIs, protocols, interoperability
- Performance Considerations - scalability, optimization, patterns

**Scope Confirmed:** 2026-03-24

---

## Technology Stack Analysis

### iOS Audio APIs: The Latency Hierarchy

There are three levels of audio API on iOS, each with different latency characteristics:

| API Level | Typical Latency | Use Case |
|-----------|----------------|----------|
| AVAudioPlayer / AVPlayer | 50-200ms | Media playback, not real-time |
| AVAudioEngine + AVAudioUnitSampler | 5-20ms | Real-time instruments, games |
| Raw AudioUnit / AUAudioUnit render callbacks | 1.5-5ms | Pro audio apps, DAWs |

Peach uses **AVAudioEngine with AVAudioUnitSampler**, which is the correct middle tier. The theoretical minimum latency at this level is determined by the I/O buffer size.

_Source: [Audio API Overview - objc.io](https://www.objc.io/issues/24-audio/audio-api-overview/), [Apple Core Audio Overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html)_

### AVAudioSession Configuration

The `AVAudioSession` buffer duration directly controls hardware latency:

| Buffer Duration | Buffer Size (@ 44.1kHz) | Round-Trip Latency |
|----------------|------------------------|--------------------|
| Default (~20ms) | 882 frames | ~40ms |
| 5ms (0.005) | 221 frames | ~10ms |
| 2.9ms (0.0029) | 128 frames | ~5.8ms |
| 1.5ms (0.0015) | 64 frames | ~3ms |

**Important:** `setPreferredIOBufferDuration` is a *hint*. The actual duration must be checked after activation via `ioBufferDuration`. It should be set *before* activating the session for best results.

_Source: [Apple Developer Documentation - setPreferredIOBufferDuration](https://developer.apple.com/documentation/avfaudio/avaudiosession/1616589-setpreferrediobufferduration), [Apple Technical Q&A QA1631](https://developer.apple.com/library/archive/qa/qa1631/_index.html)_

### AVAudioUnitSampler: Immediate MIDI Dispatch

`AVAudioUnitSampler.startNote()` dispatches a MIDI note-on event to the sampler's audio unit. This goes through the AVAudioEngine processing graph and is rendered in the next audio buffer cycle. The latency path is:

```
Touch event → Main thread → startNote() → AUScheduleMIDIEventBlock → Next render cycle → DAC
```

The critical question is: how many milliseconds elapse between `startNote()` being called and audio emerging from the speaker?

At a 5ms buffer duration, the answer is **5-10ms** (one to two buffer cycles), which should be imperceptible. But this assumes `startNote()` is called from the main thread without delay.

_Source: [AVAudioPlayerNode Documentation](https://developer.apple.com/documentation/avfaudio/avaudioplayernode), [Apple Developer Forums - Low latency host code](https://developer.apple.com/forums/thread/65675)_

### How AUM Achieves Low Latency

AUM (by Kymatica) achieves near-zero perceptible latency through:

1. **Direct hardware sample rate** — no sample rate conversion
2. **128-sample buffers** as baseline (~2.9ms at 44.1kHz)
3. **Latency compensation** — MIDI events are timestamped into the future, with latency compensated at hardware outputs
4. **No main thread involvement** for audio-critical paths
5. **AUv3 hosting** with sample-accurate event dispatch

_Source: [AUM Users Guide](https://www.kymatica.com/aum/help), [Kymatica Developer Notes](https://devnotes.kymatica.com/)_

### Real-Time Audio Thread Constraints

The audio render thread runs at real-time priority and must never:
- Allocate memory (no `malloc`, no Swift Array operations)
- Take locks that could contend with non-real-time threads
- Call Objective-C message dispatch (no `@objc` methods in the hot path)
- Do I/O, logging, or any syscall that might block

_Source: [mikeash.com - Why CoreAudio is Hard](https://www.mikeash.com/pyblog/why-coreaudio-is-hard.html), [WWDC 2010 Session 413](https://asciiwwdc.com/2010/sessions/413)_

### Touch Event Latency on iOS

iOS touch events (`touchesBegan`) are delivered on the main thread at the display refresh rate (60Hz or 120Hz on ProMotion devices). This introduces a baseline latency:

| Display | Touch Delivery Interval | Worst-Case Touch Latency |
|---------|------------------------|-------------------------|
| 60Hz | 16.7ms | ~16.7ms |
| 120Hz (ProMotion) | 8.3ms | ~8.3ms |

This is unavoidable and present in *all* iOS music apps. The key is to minimize everything *after* the touch event arrives.

---

## Peach Codebase: Identified Latency Sources

### Source 1: SwiftUI Button Action Dispatch (HIGH IMPACT — likely the biggest problem)

**Location:** `ContinuousRhythmMatchingScreen.swift:105-106`

```swift
Button {
    session.handleTap()
} label: { ... }
.buttonStyle(.borderedProminent)
```

**Problem:** SwiftUI `Button` actions fire on `.touchUpInside` (finger lift), not `touchesBegan` (finger down). This adds **the entire press duration** to the latency — typically 50-150ms depending on how the user taps.

Additionally, SwiftUI Button has internal animation and accessibility machinery that can delay action delivery by several frames compared to a raw UIKit gesture recognizer.

**Expected Impact:** 50-200ms of additional latency compared to `touchesBegan`.

**Fix:** Replace the SwiftUI Button with a custom view that uses a `UIKit` tap gesture recognizer targeting `.began` phase, or use a SwiftUI `DragGesture(minimumDistance: 0)` with an `.onChanged` handler (fires on touch down). See Integration Patterns section for concrete implementation.

### Source 2: `handleTap()` Timestamp Uses Wall Clock, Not Audio Clock (MEDIUM IMPACT)

**Location:** `ContinuousRhythmMatchingSession.swift:61, 147`

```swift
currentTime: @escaping () -> Double = { CACurrentMediaTime() }
// ...
let tapTime = currentTime()
```

**Problem:** `CACurrentMediaTime()` measures wall-clock time, but the step sequencer's position is derived from **audio render thread sample counting** (`currentSamplePosition`). These two clocks can drift apart, especially when:
- The audio thread is delayed by lock contention
- The system sleeps/wakes
- There is any thermal throttling

The offset calculation (`tapTime - gapTime`) compares wall-clock tap time against wall-clock-estimated gap time, but `sequencerStartTime` is captured *after* `stepSequencer.start()` completes — which includes `Task` scheduling overhead and `loadPreset`'s 20ms sleep.

**Expected Impact:** 10-30ms systematic offset, plus variable jitter.

**Fix:** Express tap time in the audio clock domain. Read `currentSamplePosition` at tap time and compare directly against the scheduled gap event's sample offset.

### Source 3: `immediateNoteOn` Called from Cooperative Task Context (MEDIUM IMPACT)

**Location:** `ContinuousRhythmMatchingSession.swift:174`, `SoundFontStepSequencer.swift:129-140`

```swift
// In handleTap():
try stepSequencer.playImmediateNote(velocity: velocity)

// In playImmediateNote():
func playImmediateNote(velocity: MIDIVelocity) throws {
    let midiNoteRaw = UInt8(Self.clickNote.rawValue)
    noteOffTask?.cancel()
    engine.immediateNoteOn(channel: channel, note: midiNoteRaw, velocity: velocity.rawValue)
    // ...
}
```

`immediateNoteOn` calls `AVAudioUnitSampler.startNote()` which is an Objective-C method that dispatches synchronously to the audio graph. This is actually fine in terms of latency — it will take effect on the next render cycle.

However, the call originates from `handleTap()` which is called from a SwiftUI Button action, which runs on the main actor. If the main thread is busy (e.g., SwiftUI layout pass, animation), this call is delayed until the main thread is free.

**Expected Impact:** 0-16ms depending on main thread contention.

### Source 4: Audio Session Category `.playback` Instead of `.playAndRecord` (LOW-MEDIUM IMPACT)

**Location:** `SoundFontEngine.swift:327`

```swift
try session.setCategory(.playback, mode: .default, options: [])
```

**Problem:** The `.playback` category is designed for media playback, not real-time instruments. While it does honor `setPreferredIOBufferDuration`, the `.playAndRecord` category with `.default` or `.measurement` mode is what professional music apps use for lowest latency, as it signals to iOS that the app needs real-time I/O processing priority.

**Note:** `.measurement` mode disables all system signal processing but can cause low volume. `.default` mode with `.playAndRecord` category may be the best balance.

**Expected Impact:** May not change the buffer size, but could affect scheduling priority and system-level optimizations. Needs testing.

### Source 5: `sequencerStartTime` Captured After Async Overhead (LOW-MEDIUM IMPACT)

**Location:** `ContinuousRhythmMatchingSession.swift:132-136`

```swift
startTask = Task {
    do {
        try await stepSequencer.start(tempo: settings.tempo, stepProvider: self)
        sequencerStartTime = currentTime()
        startTrackingLoop()
    }
}
```

**Problem:** `stepSequencer.start()` includes `loadPreset()` which has a deliberate 20ms sleep. After that, `sequencerStartTime` is captured. But the audio engine's `samplePosition` counter started ticking the moment `scheduleEvents()` was called inside `start()`. The gap between these two timestamps creates a **systematic offset** in all gap timing calculations.

**Expected Impact:** ~20ms+ systematic offset (the loadPreset delay plus Task scheduling overhead).

### Source 6: Buffer Duration Set After Engine Start (MINOR)

**Location:** `SoundFontEngine.swift:111-113`

```swift
try Self.configureAudioSession()  // activates session
try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)  // set after activation
try engine.start()
```

**Problem:** Apple's documentation states that buffer duration preferences should be set *before* activating the session. Setting it after activation may result in the preference being ignored.

**Expected Impact:** Potentially the 5ms buffer is not honored, falling back to the 20ms default.

_Source: [Apple Developer Forums - AVAudioSession understanding](https://developer.apple.com/forums/thread/25197)_

---

## Summary of Latency Budget

| Source | Estimated Latency | Type |
|--------|------------------|------|
| Touch delivery (hardware) | 8-17ms | Unavoidable |
| SwiftUI Button (touchUpInside) | 50-200ms | **Fixable** |
| Main thread contention | 0-16ms | Partially fixable |
| Buffer duration (if 5ms honored) | 5-10ms | Correct |
| Buffer duration (if default 20ms) | 20-40ms | **Fixable** |
| Clock domain mismatch | 10-30ms jitter | **Fixable** |
| sequencerStartTime offset | ~20ms+ | **Fixable** |
| **Total (worst case)** | **113-333ms** | |
| **Total (best case, all fixed)** | **13-27ms** | Comparable to AUM |

The SwiftUI Button is almost certainly the dominant issue. Professional music apps universally use `touchesBegan` (touch down), not button actions (touch up). This single change alone could reduce perceived latency by 50-200ms.

---

## Integration Patterns: Concrete Fix Implementations

### Fix 1: Touch-Down Trigger via DragGesture (CRITICAL — implement first)

Replace the SwiftUI `Button` with a `DragGesture(minimumDistance: 0)` that fires on touch-down. This is the single highest-impact fix.

**Current code** (`ContinuousRhythmMatchingScreen.swift:104-123`):
```swift
Button {
    session.handleTap()
} label: {
    VStack(spacing: 12) { /* ... */ }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
}
.buttonStyle(.borderedProminent)
```

**Proposed replacement — Pure SwiftUI approach:**
```swift
VStack(spacing: 12) {
    Image(systemName: "hand.tap")
        .font(.system(size: Self.buttonIconSize(isCompact: isCompactHeight)))
    Text("Tap")
        .font(Self.buttonTextFont(isCompact: isCompactHeight))
        .fontWeight(.semibold)
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
.frame(minHeight: Self.buttonMinHeight(isCompact: isCompactHeight))
.background(.tint, in: RoundedRectangle(cornerRadius: 12))
.foregroundStyle(.white)
.contentShape(Rectangle())
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            session.handleTap()
        }
)
```

**Key insight:** `DragGesture(minimumDistance: 0).onChanged` fires on the *first touch point* — equivalent to `touchesBegan`. No waiting for finger lift.

**Important caveat:** `onChanged` fires continuously as the finger moves. The `handleTap()` method must be idempotent for a given cycle (it already is — the `hitCycleIndices` guard on line 159 prevents double-counting). However, `playImmediateNote` would fire multiple times. Two solutions:

1. **Debounce at the gesture level** — track a `@State private var isTouchActive = false` flag, set it in `onChanged`, clear it in `onEnded`. Only call `handleTap()` on the transition from false → true.
2. **Debounce in `handleTap()`** — add a minimum inter-tap interval (e.g., half a sixteenth note).

**Recommended: Option 1**, as it keeps the concern at the UI layer:
```swift
@State private var isTouchActive = false

// In the gesture:
.gesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            guard !isTouchActive else { return }
            isTouchActive = true
            session.handleTap()
        }
        .onEnded { _ in
            isTouchActive = false
        }
)
```

**Alternative — UIViewRepresentable approach** (if DragGesture has unexpected SwiftUI overhead):
```swift
struct TouchDownView: UIViewRepresentable {
    let onTouchDown: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = TouchView()
        view.onTouchDown = onTouchDown
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class TouchView: UIView {
        var onTouchDown: (() -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            onTouchDown?()
        }
    }
}
```

**Confidence:** HIGH — this is a well-established pattern. Every professional iOS music app triggers sound on touch-down, not touch-up.

_Source: [SwiftUI DragGesture - minimumDistance](https://developer.apple.com/documentation/swiftui/draggesture/minimumdistance), [Handle Press and Release Events in SwiftUI](https://serialcoder.dev/text-tutorials/swiftui/handle-press-and-release-events-in-swiftui/), [Apple - touchesBegan](https://developer.apple.com/documentation/uikit/uiresponder/1621142-touchesbegan)_

---

### Fix 2: Audio Session Configuration Order (CRITICAL — easy win)

Reorder `configureAudioSession()` to set the preferred buffer duration *before* activating the session, and verify the actual buffer duration after activation.

**Current code** (`SoundFontEngine.swift:111-113, 325-329`):
```swift
private static func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setActive(true)
}
// ...
try Self.configureAudioSession()
try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
try engine.start()
```

**Proposed fix:**
```swift
private static func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setPreferredIOBufferDuration(0.005)
    try session.setActive(true)

    // Log actual buffer duration to verify the preference was honored
    let actual = session.ioBufferDuration
    Logger(subsystem: "com.peach.app", category: "SoundFontEngine")
        .info("Requested 5ms buffer, got \(actual * 1000, format: .fixed(precision: 1))ms")
}
```

Remove the separate `setPreferredIOBufferDuration` call from `init`.

**Confidence:** HIGH — Apple's documentation explicitly states preferences should be set before activation.

_Source: [Apple QA1631](https://developer.apple.com/library/archive/qa/qa1631/_index.html), [Apple Developer Forums - AVAudioSession understanding](https://developer.apple.com/forums/thread/25197)_

---

### Fix 3: Unify Clock Domains (MEDIUM — eliminates jitter)

The current timing model uses `CACurrentMediaTime()` for tap timestamps but audio-thread sample counting for playback position. These are different clock domains and can drift.

**Root cause:** `sequencerStartTime` is captured via `CACurrentMediaTime()` *after* an `await` chain, while `samplePosition` starts counting from the moment `scheduleEvents()` is called on the render thread.

**Proposed fix — use sample position for everything:**

In `handleTap()`, instead of:
```swift
let tapTime = currentTime()
let elapsed = tapTime - sequencerStartTime
let playingCycleIndex = Int(elapsed / cycleDuration)
```

Do:
```swift
let tapSamplePosition = stepSequencer.currentSamplePosition
let samplesPerCycle = stepSequencer.samplesPerCycle  // expose from step sequencer
let playingCycleIndex = Int(tapSamplePosition / samplesPerCycle)
```

And for offset calculation, instead of:
```swift
let gapTime = sequencerStartTime
    + Double(playingCycleIndex * 4 + gapPosition.rawValue) * sixteenthDuration
let offset = tapTime - gapTime
```

Do:
```swift
let samplesPerStep = stepSequencer.samplesPerStep  // expose from step sequencer
let gapSampleOffset = Int64(playingCycleIndex * 4 + gapPosition.rawValue) * samplesPerStep
let offsetSamples = tapSamplePosition - gapSampleOffset
let offsetSeconds = Double(offsetSamples) / sampleRate.rawValue
```

This eliminates `sequencerStartTime` entirely and removes all wall-clock / audio-clock drift. The offset is now measured in the same domain as the scheduled events.

**Trade-off:** `currentSamplePosition` is read via `OSAllocatedUnfairLock.withLock`, which is a fast operation (~nanoseconds) but technically blocks. This is fine on the main thread — the lock is only contended during render-thread frame processing (microseconds).

**Confidence:** HIGH — this is the standard approach in professional audio apps. The audio render timeline is the single source of truth for timing.

_Source: [Making Sense of Time in AVAudioPlayerNode](https://medium.com/@mehsamadi/making-sense-of-time-in-avaudioplayernode-475853f84eb6), [WWDC 2014 Session 502](https://asciiwwdc.com/2014/sessions/502)_

---

### Fix 4: Audio Session Category (LOW PRIORITY — test empirically)

Consider switching from `.playback` to `.playAndRecord`:

```swift
try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
```

**Note:** `.playAndRecord` requires the `defaultToSpeaker` option, otherwise audio routes to the earpiece. This category signals to iOS that the app needs real-time I/O priority.

**However:** Since Peach doesn't actually record audio, this may trigger an unnecessary microphone permission prompt. Test whether `.playback` with the corrected buffer duration order (Fix 2) is sufficient before resorting to this.

**Confidence:** MEDIUM — the latency benefit is undocumented; some developers report it matters, others don't.

---

### Fix 5: Immediate Note Dispatch Path Optimization (LOW PRIORITY)

The current `playImmediateNote` → `immediateNoteOn` → `sampler.startNote()` path is already reasonably efficient. `AVAudioUnitSampler.startNote()` internally calls the `scheduleMIDIEventBlock` with `AUEventSampleTimeImmediate`, which is the fastest path available.

One possible micro-optimization: call `scheduleMIDIEventBlock` directly instead of going through `startNote()`, to avoid Objective-C message dispatch overhead:

```swift
func immediateNoteOn(channel: ChannelID, note: UInt8, velocity: UInt8) {
    scheduleLockState.withLock { data in
        guard let midiBlock = data.midiBlocks[channel.rawValue] else { return }
        var bytes: (UInt8, UInt8, UInt8) = (Self.noteOnBase | channel.rawValue, note, velocity)
        withUnsafeBytes(of: &bytes) { raw in
            midiBlock(AUEventSampleTimeImmediate, 0, 3,
                      raw.baseAddress!.assumingMemoryBound(to: UInt8.self))
        }
    }
}
```

**Confidence:** LOW — the Objective-C dispatch overhead is ~nanoseconds and unlikely to be perceptible. Only pursue if the higher-impact fixes don't resolve the issue.

---

### Integration Summary: Recommended Fix Order

| Priority | Fix | Expected Impact | Effort |
|----------|-----|----------------|--------|
| 1 | Touch-down trigger (DragGesture) | -50 to -200ms | Small |
| 2 | Audio session config order + verify buffer | -0 to -15ms (ensures 5ms buffer) | Trivial |
| 3 | Unify clock domains (sample position) | Eliminates 10-30ms jitter | Medium |
| 4 | Audio session category (.playAndRecord) | Unknown, test empirically | Trivial |
| 5 | Direct scheduleMIDIEventBlock | ~0ms (micro-optimization) | Small |

**After fixes 1-3, expected total latency: 13-27ms** (8-17ms touch delivery + 5-10ms audio buffer), which is comparable to professional music apps.

---

## Architectural Patterns and Design Analysis

### Current Architecture: What Peach Does Right

Peach's audio engine (`SoundFontEngine`) already follows several important architectural patterns:

1. **Render-thread MIDI scheduling** — Events are dispatched via `AUScheduleMIDIEventBlock` inside an `AVAudioSourceNode` render callback, with sample-accurate timing. This is the correct pattern for sample-accurate sequencing.

2. **Pre-allocated event buffer** — The `scheduleBuffer` is allocated once at init (4096 events) and reused, avoiding memory allocation on the render thread.

3. **Non-blocking render-thread lock** — The `OSAllocatedUnfairLock.withLockIfAvailable` (try-lock) pattern on the render thread ensures the audio pipeline never stalls waiting for the main thread. If the lock is held, the render frame is skipped — this is the correct trade-off (a missed scheduling frame is far less perceptible than an audio glitch).

4. **Batch scheduling** — The step sequencer pre-schedules 500 cycles (~8 minutes of audio) at once, then refills near the end. This eliminates any per-cycle scheduling overhead during playback.

**Verdict:** The fundamental audio engine architecture is sound. The problems are in the *integration layer* between UI events and the audio engine, not in the engine itself.

_Source: [Four common mistakes in audio development](https://atastypixel.com/four-common-mistakes-in-audio-development/), [mikeash.com - Why CoreAudio is Hard](https://www.mikeash.com/pyblog/why-coreaudio-is-hard.html)_

---

### Architectural Anti-Pattern: Dual Clock Domains

The most significant architectural issue is the **dual clock domain** design:

```
┌─────────────────────────────────────────────────────────┐
│  AUDIO DOMAIN (render thread)                           │
│  Clock: samplePosition (incremented per render frame)    │
│  Events: ScheduledMIDIEvent.sampleOffset                │
│  Truth: absolute, monotonic, jitter-free                │
└─────────────────────────────────────────────────────────┘
        ▲ gap between domains ▼
┌─────────────────────────────────────────────────────────┐
│  UI DOMAIN (main thread)                                │
│  Clock: CACurrentMediaTime() (system mach_absolute_time)│
│  Events: handleTap() timestamp, sequencerStartTime      │
│  Truth: approximate, can drift from audio clock          │
└─────────────────────────────────────────────────────────┘
```

**The problem:** These two clocks are *correlated but not synchronized*. On most iOS devices at 48kHz, `mach_absolute_time` and the audio sample clock are identical. But at 44.1kHz (which AVAudioEngine may use), Apple's own documentation notes drift caused by internal resampling. Even at 48kHz, the *bridging point* between domains — `sequencerStartTime = currentTime()` captured after an async `await` — introduces systematic offset.

**The correct pattern** used by professional audio apps:

```
┌─────────────────────────────────────────────────────────┐
│  SINGLE CLOCK DOMAIN: Audio render thread               │
│  All timing expressed in sample offsets                  │
│  Tap → read currentSamplePosition → compare to gap      │
│  No wall-clock involved in any timing calculation        │
└─────────────────────────────────────────────────────────┘
```

**Architectural recommendation:** Eliminate `CACurrentMediaTime()` from all timing-critical code paths. The render thread's `samplePosition` is the only clock that matters. Wall-clock time should only be used for non-critical purposes (logging, analytics).

_Source: [Kymatica - iOS Audio Sync](https://devnotes.kymatica.com/ios_audio_sync.html), [Apple Developer Forums - Clock drift](https://developer.apple.com/forums/thread/103550), [Apple Developer Forums - Is 48kHz audio always in sync with mach_absolute_time?](https://developer.apple.com/forums/thread/91205)_

---

### Architectural Pattern: The Immediate-Play Path

When a user taps to fill a gap, the audio response must take the shortest possible path:

**Current path (6 hops, ~100-250ms):**
```
finger down → iOS touch system → SwiftUI Button (waits for finger UP) →
Button action → handleTap() → playImmediateNote() → immediateNoteOn() →
sampler.startNote() → next render cycle → DAC → speaker
```

**Optimal path (4 hops, ~15-25ms):**
```
finger down → iOS touch system → DragGesture.onChanged →
handleTap() → immediateNoteOn() → next render cycle → DAC → speaker
```

Key architectural principles for the immediate-play path:

1. **No intermediate async boundaries** — The path from touch to `startNote()` must be synchronous on the main thread. No `Task {}`, no `await`, no dispatch queues.

2. **Touch-down, not touch-up** — This is non-negotiable for real-time instruments. The `touchesBegan` / `DragGesture(minimumDistance: 0)` pattern is universally used.

3. **Minimal computation between touch and sound** — The gap evaluation (which cycle? which gap position? is it a hit?) is O(1) arithmetic and acceptable. But any SwiftUI state updates that trigger layout should happen *after* the note-on, not before.

4. **Sound first, visual feedback second** — In `handleTap()`, the `playImmediateNote()` call should come before `recordGapResult()`, `advanceCycleCount()`, and `showHitFeedback()`. Currently it does (line 174 is before lines 179-181), which is correct.

---

### Architectural Pattern: Thread Safety Without Priority Inversion

Peach's `OSAllocatedUnfairLock` pattern is architecturally sound but has a subtle risk:

```swift
// Render thread (real-time priority):
_ = lockState.withLockIfAvailable { data in  // try-lock: non-blocking ✓
    // dispatch MIDI events
}

// Main thread (normal priority):
lockState.withLock { data in  // blocking lock ✓ (acceptable on main thread)
    // update schedule
}
```

**Risk:** If the main thread calls `withLock` at the same moment the render thread calls `withLockIfAvailable`, the render thread will fail to acquire the lock and skip the frame. This is the correct behavior — but if `scheduleEvents()` (which iterates 4096 events under the lock) takes longer than one render frame (~5ms at 5ms buffer), it could cause *consecutive* skipped frames and audible gaps.

**Mitigation already in place:** The `scheduleEvents()` copy loop is simple (`data.buffer[i] = events[i]`) and should complete well within 5ms even for 4096 events. No action needed unless profiling reveals contention.

**The `currentSamplePosition` read path** (used by the proposed Fix 3) also goes through `withLock`, but this is a single integer read — nanoseconds of contention, negligible.

_Source: [OSAllocatedUnfairLock Documentation](https://developer.apple.com/documentation/os/osallocatedunfairlock), [Thread Safety in Swift](https://swiftwithmajid.com/2023/09/05/thread-safety-in-swift-with-locks/)_

---

### Architectural Pattern: Render-Thread Clock as Single Source of Truth

The render callback's `AudioTimeStamp` parameter provides both `mSampleTime` and `mHostTime`. Peach's `AVAudioSourceNode` callback already increments `samplePosition` from frame counts, which tracks `mSampleTime`.

For the proposed clock unification (Fix 3), the architecture should look like:

```
Step Sequencer             ContinuousRhythmMatchingSession
┌──────────────────┐      ┌──────────────────────────────┐
│ scheduleEvents() │      │ handleTap()                  │
│   events[i].     │      │   pos = currentSamplePosition│
│   sampleOffset   │      │   cycle = pos / samplesPerCy │
│                  │      │   gap = gapPositions[cycle]   │
│ currentSample    │◄─────│   offset = pos - gapOffset   │
│   Position       │      │   if |offset| < window:      │
│   (render clock) │      │     playImmediateNote()      │
└──────────────────┘      └──────────────────────────────┘
```

All timing decisions use `samplePosition` — no `Date`, no `CACurrentMediaTime()`, no `ProcessInfo.processInfo.systemUptime`. The audio clock is the single source of truth.

**Note on `mHostTime` jitter:** Kymatica's documentation notes that on 32-bit devices, there is jitter between `mSampleTime` and `mHostTime`. Since Peach uses `samplePosition` (tracking `mSampleTime` via frame counts) rather than `mHostTime`, this jitter does not affect Peach's architecture.

_Source: [Kymatica - iOS Audio Sync](https://devnotes.kymatica.com/ios_audio_sync.html), [Apple QA1643 - Audio Host Time on iOS](https://developer.apple.com/library/archive/qa/qa1643/_index.html)_

---

### Architectural Assessment Summary

| Aspect | Current State | Assessment |
|--------|--------------|------------|
| Audio engine core | Render-thread MIDI scheduling | Correct |
| Event buffer management | Pre-allocated, lock-synchronized | Correct |
| Lock strategy | Try-lock on render, block on main | Correct |
| Batch scheduling | 500 cycles pre-scheduled | Correct |
| Touch event integration | SwiftUI Button (touch-up) | **Wrong** |
| Timing model | Dual clock domains | **Wrong** |
| Audio session config | Buffer pref after activation | **Wrong** |
| Audio session category | `.playback` | Questionable |
| Immediate note dispatch | `startNote()` from main thread | Acceptable |

**The engine is good. The plumbing between UI and engine is the problem.**

---

## Implementation Approaches and Verification

### Implementation Strategy: Incremental Verification

Each fix should be implemented and verified independently, measuring before and after. The fixes are designed to be independent — each can be landed as a separate commit/story.

**Recommended implementation order:**

```
Fix 2 (audio session config order) ─── trivial, immediate ───┐
                                                               ├── measure baseline
Fix 1 (touch-down trigger) ──── small, highest impact ────────┤
                                                               ├── measure again
Fix 3 (clock domain unification) ─── medium, eliminates jitter┘
```

---

### Verification: How to Measure Tap-to-Sound Latency

#### Method 1: Instrumentation Logging (Quick, Approximate)

Add `os_signpost` instrumentation to measure the time from touch event to `startNote()`:

```swift
import os

private let signposter = OSSignposter(subsystem: "com.peach.app", category: "TapLatency")

// In the DragGesture.onChanged handler:
let id = signposter.makeSignpostID()
let state = signposter.beginInterval("tap-to-sound", id: id)

session.handleTap()

// In immediateNoteOn():
signposter.endInterval("tap-to-sound", state)
```

View results in Instruments → os_signpost. This measures the software path only (touch event to `startNote()` call), not the hardware output latency.

**Target:** < 2ms for the software path (all the real latency is in the hardware buffer).

#### Method 2: Audio Loopback (Precise, Total Latency)

Use a physical loopback cable or the device's speaker-to-microphone path:

1. Start recording via `AVAudioEngine` input node
2. Tap the button (generates a click sound)
3. Detect the tap impact (accelerometer or touch timestamp) and the click arrival in the recording
4. The difference is the total end-to-end latency

Apps like [Round Trip Latency Meter](https://apps.apple.com/us/app/round-trip-latency-meter/id1427507645) and [Superpowered Latency Test](https://superpowered.com/latency) can measure this. **Target for professional audio: < 10ms round-trip.** For a rhythm training app, < 25ms total (touch-to-ear) is acceptable.

_Source: [Round Trip Audio Latency Meter](https://onyx3.com/LatencyMeter/), [Superpowered Latency Test](https://superpowered.com/latency)_

#### Method 3: Buffer Duration Verification (Essential Diagnostic)

After implementing Fix 2, verify the actual buffer duration:

```swift
let session = AVAudioSession.sharedInstance()
let actualMs = session.ioBufferDuration * 1000
logger.info("IO buffer duration: \(actualMs, format: .fixed(precision: 1))ms")
```

If this reports ~20ms instead of ~5ms, the buffer preference is not being honored and Fix 2 needs further investigation (e.g., another app or system service overriding the preference).

**iOS 18 caveat:** There are reports of iOS 18 not honoring `setPreferredIOBufferDuration` in some configurations, with buffer sizes being larger than requested. If this affects Peach, the workaround is to set the preference again after each audio session interruption/reactivation.

_Source: [Apple Developer Forums - Increased and Mismatched Audio Buffer Sizes on iOS 18](https://developer.apple.com/forums/thread/769245)_

---

### Testing Strategy

#### Unit Tests (Existing Tests Should Still Pass)

The clock domain unification (Fix 3) changes `handleTap()`'s timing model. Existing tests that mock `currentTime()` will need to be updated to mock `currentSamplePosition` instead. The test structure remains the same — only the clock source changes.

#### Manual Perceptual Test

The ultimate test: tap along continuously to every 16th note (not just the gap). If the tapped notes sound "in time" with the sequenced notes — as if you were tapping on a table — the latency is acceptable. If there's a perceptible delay between your finger hitting the screen and the sound, more work is needed.

**Before/after comparison:** Record a screen capture (with audio) of tapping along before and after the fixes. The waveform in the recording will show the time between the tap impact sound (from the screen) and the synthesized click.

#### Automated Latency Regression Test

Consider adding a test that verifies the software path latency:

```swift
func testTapToNoteOnLatency() {
    // Arrange: set up engine and sequencer
    let engine = MockStepSequencerEngine()
    let sequencer = SoundFontStepSequencer(engine: engine, ...)

    // Act: simulate tap and measure time to immediateNoteOn
    let start = CACurrentMediaTime()
    sequencer.playImmediateNote(velocity: .init(100))
    let elapsed = CACurrentMediaTime() - start

    // Assert: software path should be < 1ms
    XCTAssertLessThan(elapsed, 0.001)
}
```

This won't catch hardware latency but will detect regressions in the software path.

---

### Risk Assessment and Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| DragGesture fires multiple times per touch | HIGH | LOW | Debounce with `isTouchActive` flag (already in Fix 1 code) |
| 5ms buffer not honored on some devices | MEDIUM | MEDIUM | Log actual `ioBufferDuration`, fall back gracefully |
| Clock unification breaks existing tests | HIGH | LOW | Update mocks to use sample position instead of wall clock |
| `.playAndRecord` triggers mic permission | HIGH | MEDIUM | Don't use unless `.playback` proves insufficient |
| iOS 18 buffer size regression | LOW | HIGH | Re-set preference after interruptions, log actual values |
| DragGesture conflicts with ScrollView | LOW | LOW | Tap button is not inside a ScrollView |

---

### Implementation Roadmap

| Phase | Fix | Files Changed | Testing |
|-------|-----|--------------|---------|
| **Phase 1** | Fix 2: Audio session config order | `SoundFontEngine.swift` | Log `ioBufferDuration`, verify 5ms |
| **Phase 2** | Fix 1: Touch-down trigger | `ContinuousRhythmMatchingScreen.swift` | Manual perceptual test |
| **Phase 3** | Fix 3: Clock domain unification | `ContinuousRhythmMatchingSession.swift`, `SoundFontStepSequencer.swift` | Update unit tests, verify offset accuracy |
| **Phase 4** | Optional: Fix 4 (session category) | `SoundFontEngine.swift` | Only if phases 1-3 insufficient |

**Success metric:** Tapping along to every 16th note at 120 BPM should sound indistinguishable from the sequenced notes — no perceptible delay or jitter.

---

## Research Synthesis and Conclusion

### Root Cause Summary

The continuous rhythm match discipline's latency problem has three independent root causes, all in the integration layer between the UI and the audio engine:

| Root Cause | Location | Impact | Fix |
|-----------|----------|--------|-----|
| SwiftUI Button fires on touch-up | `ContinuousRhythmMatchingScreen.swift:105` | 50-200ms added latency | `DragGesture(minimumDistance: 0)` |
| Dual clock domains (wall-clock vs. audio samples) | `ContinuousRhythmMatchingSession.swift:61, 147, 162` | 10-30ms jitter + systematic offset | Use `currentSamplePosition` for all timing |
| Buffer preference set after session activation | `SoundFontEngine.swift:111-113` | Possibly 15ms extra (20ms vs. 5ms buffer) | Reorder `configureAudioSession()` |

### What Does NOT Need to Change

- `SoundFontEngine` — The render-thread MIDI scheduling, pre-allocated buffer, and `OSAllocatedUnfairLock` try-lock pattern are all correct.
- `SoundFontStepSequencer` — The batch scheduling and `playImmediateNote()` → `startNote()` path are efficient.
- `AVAudioUnitSampler` usage — This is the correct API level for Peach's needs (not too low-level, not too high-level).
- Audio session category `.playback` — Likely sufficient; only change to `.playAndRecord` if empirical testing after fixes 1-3 shows it matters.

### Confidence Assessment

| Claim | Confidence | Basis |
|-------|-----------|-------|
| SwiftUI Button fires on touch-up, not touch-down | HIGH | Well-documented UIKit/SwiftUI behavior |
| `DragGesture(minimumDistance: 0)` fires on touch-down | HIGH | Apple documentation, multiple community confirmations |
| Buffer preference should be set before `setActive` | HIGH | Apple QA1631, Apple Developer Forums |
| Dual clock domains cause timing jitter | HIGH | Kymatica iOS Audio Sync, Apple Developer Forums on clock drift |
| Fixes will achieve 13-27ms total latency | MEDIUM | Based on theoretical analysis; needs empirical verification |
| `.playAndRecord` improves latency over `.playback` | LOW | Undocumented; anecdotal developer reports conflict |

### iOS 26 Considerations

- No new touch-down-specific gesture API was introduced in iOS 26. `DragGesture(minimumDistance: 0)` remains the correct pattern.
- No breaking changes to `AVAudioEngine`, `AVAudioSession`, or `AVAudioUnitSampler` APIs in iOS 26.
- iOS 26 introduces Bluetooth high-quality recording options (irrelevant to this use case).
- The iOS 18 buffer size regression (reports of `setPreferredIOBufferDuration` being ignored) should be verified on iOS 26 by logging `ioBufferDuration` after activation.

### Next Steps

1. Create implementation stories for the three fixes (can be done as a single story or three separate ones)
2. Implement Fix 2 first (trivial, provides diagnostic data via buffer duration logging)
3. Implement Fix 1 (highest user-facing impact)
4. Implement Fix 3 (eliminates jitter, requires test updates)
5. Verify with manual perceptual test: tap along to every 16th note at 120 BPM

---

## Sources

### Apple Documentation
- [setPreferredIOBufferDuration](https://developer.apple.com/documentation/avfaudio/avaudiosession/1616589-setpreferrediobufferduration)
- [ioBufferDuration](https://developer.apple.com/documentation/avfaudio/avaudiosession/1616498-iobufferduration)
- [AVAudioUnitSampler](https://developer.apple.com/documentation/avfaudio/avaudiounitsampler)
- [AVAudioSourceNode](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode)
- [OSAllocatedUnfairLock](https://developer.apple.com/documentation/os/osallocatedunfairlock)
- [DragGesture - minimumDistance](https://developer.apple.com/documentation/swiftui/draggesture/minimumdistance)
- [touchesBegan](https://developer.apple.com/documentation/uikit/uiresponder/1621142-touchesbegan)
- [Technical Q&A QA1631 - Requesting Audio Session Preferences](https://developer.apple.com/library/archive/qa/qa1631/_index.html)
- [Technical Q&A QA1643 - Audio Host Time on iOS](https://developer.apple.com/library/archive/qa/qa1643/_index.html)
- [Audio Session Categories and Modes](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionCategoriesandModes/AudioSessionCategoriesandModes.html)
- [Core Audio Overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/WhatisCoreAudio/WhatisCoreAudio.html)

### Apple Developer Forums
- [AVAudioSession understanding](https://developer.apple.com/forums/thread/25197)
- [Low latency host code for AU v3](https://developer.apple.com/forums/thread/65675)
- [Clock drift](https://developer.apple.com/forums/thread/103550)
- [Is 48kHz audio always in sync with mach_absolute_time?](https://developer.apple.com/forums/thread/91205)
- [Increased and Mismatched Audio Buffer Sizes on iOS 18](https://developer.apple.com/forums/thread/769245)

### Community & Technical Sources
- [objc.io - Audio API Overview](https://www.objc.io/issues/24-audio/audio-api-overview/)
- [mikeash.com - Why CoreAudio is Hard](https://www.mikeash.com/pyblog/why-coreaudio-is-hard.html)
- [A Tasty Pixel - Four Common Mistakes in Audio Development](https://atastypixel.com/four-common-mistakes-in-audio-development/)
- [Kymatica - iOS Audio Sync](https://devnotes.kymatica.com/ios_audio_sync.html)
- [WWDC 2014 Session 502 - AVAudioEngine in Practice](https://asciiwwdc.com/2014/sessions/502)
- [Making Sense of Time in AVAudioPlayerNode](https://medium.com/@mehsamadi/making-sense-of-time-in-avaudioplayernode-475853f84eb6)
- [SwiftUI Gestures - Handle Press and Release Events](https://serialcoder.dev/text-tutorials/swiftui/handle-press-and-release-events-in-swiftui/)
- [AUM Users Guide](https://www.kymatica.com/aum/help)

### Measurement Tools
- [Round Trip Audio Latency Meter](https://onyx3.com/LatencyMeter/)
- [Superpowered Latency Test](https://superpowered.com/latency)

---

**Research completed:** 2026-03-24
**Source verification:** All technical claims cited with current sources
**Confidence level:** High for root cause identification; medium for predicted post-fix latency (requires empirical verification)

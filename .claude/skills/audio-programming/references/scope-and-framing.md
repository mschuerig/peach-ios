# Scope and Framing: Which Audio Problem Is This?

The biggest waste of time in audio bug-hunting is **applying the wrong scale of solution**. The canonical SPSC-FIFO refactor (Bencina/Doumler/Tyson) is correct, important, well-documented — and it is the wrong answer for most audio bugs you'll actually meet in an app on Apple platforms.

This file is the decision tree to use *before* reaching into the rest of this skill.

## The Six Scopes

### 1. Buffer-fill / DSP (the classical RT-audio problem)

You are filling a sample buffer at audio rate. The render thread runs on a system-owned, real-time-priority pthread. If it misses a deadline you get a glitch or dropout.

**Signals you're here:**
- You wrote a render callback, `AVAudioSourceNode` block, `AURenderBlock`, `AVAudioSinkNode` block, or `AUAudioUnit.internalRenderBlock`.
- You're computing DSP (oscillators, filters, mixers, granular synthesis, convolution).
- Symptoms: audible glitches, dropouts, clicks under CPU load, "I can hear it when scrolling Safari" complaints.

**Right answers live in:** the canonical Bencina/Doumler/Tyson literature. Lock-free SPSC FIFOs for parameter and event delivery; pre-allocated scratch memory; atomic swap for parameter snapshots; the four cardinal rules. If one render thread isn't enough, the answer may also involve audio workgroups.

### 2. Control-plane ordering (most "MIDI race" bugs)

You're submitting MIDI events or control changes to an Audio Unit (Apple's or someone else's). The AU does the DSP; you don't. Your problem is that *event A* and *event B* arrived in the wrong order at the AU's input — or in the right order but with the wrong timing relative to each other.

**Signals you're here:**
- You call `sampler.startNote / stopNote / sendController / sendPitchBend` or `auAudioUnit.scheduleMIDIEventBlock`.
- Multiple dispatch paths converge on the same AU (main-thread direct calls, plus a sequencer, plus a flag-driven cleanup, plus an external MIDI source).
- Symptoms: stuck notes, first note after a stop is silent, panic ineffective, stop-then-play interleaves wrongly.

**Right answers:** Almost always *remove* a dispatch path before *adding* a queue. If unification really is required, the right shape is one ordered SPSC queue drained on the render thread via `AUScheduleMIDIEventBlock` (or `AUMIDIEventListBlock` for MIDI 2.0) with `AUEventSampleTimeImmediate + offsetFrames`. Detail in `inter-thread-patterns.md`.

### 3. Session and lifecycle (the iOS/macOS host layer)

You're not racing yourself; you're racing the system. Phone rings. Siri triggers. User unplugs headphones. App backgrounds. CarPlay connects. Sample rate changes because someone plugged in an external interface at a different rate. The audio server (`mediaserverd`) crashes — rare but catastrophic.

**Signals you're here:**
- Audio cuts at a predictable user action (call, alarm, route change).
- Engine produces silence after recovery.
- Sample-rate change crashes or distorts.
- Symptoms reported as "doesn't work after I do X" where X is an OS-level event.

**Right answers:** `AVAudioSession.interruptionNotification` with `.shouldResume` discipline; `AVAudioSession.routeChangeNotification` with `.oldDeviceUnavailable` pause-on-unplug; `AVAudioEngineConfigurationChangeNotification` graph rebuild; `AVAudioSession.mediaServicesWereResetNotification` complete-rebuild. Detail in `avaudiosession.md` and `avaudio-engine.md`.

### 4. AU-specific semantics (the closed-source layer)

The Audio Unit you're calling doesn't behave the way the MIDI spec or its docs suggest. There's a voice you can't kill, a CC that lingers, a `reset()` that crashes, a polyphony budget you can't observe, a parameter you can ramp but not set instantaneously without an audible zipper, an input format the unit silently coerces.

**Signals you're here:**
- "I sent a noteOff and the voice still rings."
- "I called reset() and the app crashed."
- "stopNote(N_A) seems to affect N_B's envelope."
- The same code on a different AU works.

**Right answers:** Empirical. Investigate before pattern-matching. Document what the AU *actually* does, separate from what it should do. Workarounds are usually correct; "fixing" a closed AU is rarely possible. For your own AUv3, `auval` is the validator — failures here usually point to a specification bug, not an OS bug. Detail in `audio-units.md`.

### 5. Format / topology

The graph doesn't even glue together. `connect(_:to:format:)` throws. Output is silent. Capture is the wrong rate. The mixer "auto-converts" at a cost you didn't intend.

**Signals you're here:**
- Exception on `engine.connect` or `engine.start`.
- Silent output that doesn't error.
- Wrong pitch / pitch shift / chipmunked playback.
- Crackle that goes away when you change the buffer size.

**Right answers:** Read `node.outputFormat(forBus: 0)` *after* the session is active. Never hardcode sample rate. Pass an explicit `AVAudioFormat` when bridging mismatches; let the `AVAudioMixerNode` do SRC when that's the cheaper option. Detail in `avaudio-engine.md`.

### 6. Permissions / capabilities

You can't even reach the hardware.

**Signals you're here:**
- Mic permission dialog never appears; recording is silent.
- Background audio stops the moment the screen locks.
- `setActive` throws with no useful info.

**Right answers:** Info.plist (`NSMicrophoneUsageDescription`, `NSCameraUsageDescription` for video+audio), Signing & Capabilities ("Audio, AirPlay, Picture in Picture" enables `audio` in `UIBackgroundModes`), App Group entitlement for AUv3 sharing data with the container app. Detail in `avaudiosession.md` and `audio-units.md`.

## Decision Tree

```
Is the render thread itself misbehaving (glitching, dropping samples,
overrunning deadlines)?
├── yes → buffer-fill scope. Use realtime-rules.md + inter-thread-patterns.md.
│         For multi-core DSP: audio-workgroups.md.
└── no
    │
    Did the build succeed but produce silence / wrong format / format
    exception?
    ├── yes → format/topology scope. avaudio-engine.md.
    └── no
        │
        Does the symptom track an OS event (call, route change, screen lock,
        backgrounding, sample-rate change)?
        ├── yes → session/lifecycle scope. avaudiosession.md.
        └── no
            │
            Is permission missing or background incapable?
            ├── yes → permissions scope. Check Info.plist + entitlements.
            └── no
                │
                Is the symptom about WHEN events fire or about WHICH events
                fire (including missing/extra)?
                ├── yes
                │   ├── Multiple paths submit to the same consumer?
                │   │   ├── yes → control-plane scope. inter-thread-patterns.md.
                │   │   │         FIRST simplify the dispatch topology;
                │   │   │         THEN consider unifying.
                │   │   └── no  → AU-semantics scope. audio-units.md +
                │   │             empirical investigation.
                │   └── (continue)
                └── no → re-classify; insufficient information. Reproduce
                         deterministically. Add logging at the boundary.
                         For glitches, capture Audio System Trace.
```

## Worked Example: Stop-then-play silence (control-plane)

**Symptom:** After cancelling an in-flight playback during a cleanup window, the first note of the next playback is sometimes silent.

**Wrong framing:** "Race between multiple dispatch paths into the AU. The canonical answer is a unified SPSC FIFO drained on the render thread. Refactor everything."

**Why that framing is wrong-scoped:** The render thread is not glitching. There's no DSP race. The "race" is between a deferred cleanup CC#123 (path A) and a subsequent noteOn (path B). Both arrive at the AU's MIDI input. Both run on or near the main thread. This is *control-plane ordering*, not *buffer-fill ordering*.

**The right approach:** Enumerate the dispatch paths. If there are multiple cleanup paths reaching the same consumer, removing the redundant ones is usually a sufficient fix — submission order from a single canonical path is preserved on its own. Only if there are multiple structurally-distinct producers (real ones, not cleanup multiplexes) do you need the SPSC-FIFO unification.

**The lesson:** The Bencina/Doumler/Tyson pattern is correct. It answers a different question than this one. Recognizing the scope before reaching for the canonical answer saves days of investigation.

## When IS SPSC-FIFO the Right Answer?

You're justified in introducing a lock-free FIFO when **all** of these are true:

1. **The render thread itself needs to receive events** that come from non-realtime code, *and you can't pre-prepare them at construction time*.
2. **No single existing dispatch path can serve as the canonical one** — the multiplex is structural, not a cleanup multiplex you can collapse.
3. **The producer side genuinely cannot block** — running on the main actor where any delay hurts UX, or another real-time thread that has its own deadline.
4. **You have measured ordering matters** — reproducible interleaving wrongly under the current arrangement, not just "I think this could race".

If any of those is false, prefer the smaller fix: collapse paths, document the ordering contract, or move the work fully onto one side of the boundary.

## When IS atomic-swap the Right Answer?

For Pattern 2 (whole-state replacement):

- The state object is large or complex and an event-stream representation would be inefficient.
- The consumer reads the state on every render cycle (or near it).
- Updates are relatively infrequent — a few times per second at most.
- The receiver doesn't need a sequence; the latest state is enough.

Examples: preset switch in a synth, swapping a tuning table, replacing a convolution impulse response, switching the active patch on a sampler.

Counter-examples: per-note pitch bend updates (those are events, use the FIFO); parameter automation curves (the host provides those via `AURenderEvent`); MIDI dispatch (events, FIFO).

## Authority Discipline

When citing a pattern as "the correct approach":

- **Bencina/Doumler/Tyson/Liljedahl** are the named primary practitioners. Their patterns are community consensus, not Apple-documented.
- **Apple docs and WWDC** describe API surfaces; they are usually silent on threading semantics.
- **AudioKit** source shows what the community has settled on for Swift integration. Absence of a pattern in AudioKit is informative but not prescriptive.
- **JUCE** encodes battle-tested cross-platform patterns; many translate directly to Apple AUv3.

Defend recommendations by naming the practitioner. Don't conflate community-consensus with Apple authority.

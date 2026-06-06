---
name: audio-programming
description: 'Real-time, lifecycle, and Apple-platform audio reference for iOS / macOS / tvOS / visionOS / Swift. Use when touching AVAudioEngine, AVAudioUnit*, AVAudioSession, AVAudioSourceNode/SinkNode, AVAudioFile, AVAudioRecorder, AVAudioConverter, AVAudioSequencer, AVAudioEnvironmentNode, PHASE, CoreMIDI (MIDIEventList / MIDIPacketList), AUAudioUnit (AUv2/AUv3), AudioToolbox, AudioHAL, MusicSequence, audio render callbacks, sample buffers, DSP, audio file I/O, recording, spatial audio, audio workgroups, or writing an Audio Unit Extension. Triggers include: "audio thread", "render callback", "render block", "audio glitch", "dropout", "stuck note", "MIDI ordering", "AVAudioEngine race", "AVAudioSession interruption", "route change", "sample-accurate scheduling", "lock-free queue for audio", "realtime safe", "AUv3 extension", "auval", "AVAudioPCMBuffer", "AVAudioFormat", "AVAudio3D / spatial audio", "PHASE engine", "os_workgroup", "MIDI 2.0 / UMP", "AudioUnit / AudioComponent", "Core Audio", "ExtAudioFile", "AudioBufferList", "AudioStreamBasicDescription", "Accelerate / vDSP audio", any change to a file under SoundFont*, *Sampler*, *AudioEngine*, *MIDI*, *Sequencer*, *Recorder*, *Spatial*, *Voice*, *Synth*, *DSP*, or *.au extension targets.'
---

# Audio Programming (iOS / macOS / Swift)

A reference for writing correct audio code on Apple platforms. Covers real-time DSP, the AVFoundation and AudioToolbox API surfaces, MIDI, audio session lifecycle, spatial audio, recording and file I/O, Audio Unit hosting and development, performance work, and the boundary with Swift Concurrency.

This skill is meant to be **portable across projects**. Where worked examples appear, they are illustrative — not anchored to any one codebase.

## When to use this skill

Use any time the work touches:

- Real-time audio code (render blocks, render callbacks, audio taps, `AVAudioSourceNode`/`AVAudioSinkNode`)
- The audio engine graph (`AVAudioEngine`, nodes, formats, connections)
- Audio I/O lifecycle (`AVAudioSession` on iOS; Core Audio device events on macOS)
- MIDI dispatch — `CoreMIDI`, `AUMIDIEventListBlock`, `MusicSequence`, `AVAudioSequencer`, MIDI 1.0 byte streams, MIDI 2.0 / Universal MIDI Packet (UMP)
- Audio Unit hosting (loading AUv3 extensions, parameter trees, presets) or **writing** an AUv3 / AUv2
- Recording, file I/O, format conversion (`AVAudioFile`, `AVAudioConverter`, `ExtAudioFile`, codec choices)
- Spatial / 3D audio (`AVAudioEnvironmentNode`, PHASE, AirPods head tracking)
- Audio performance work (Instruments, `os_workgroup`, latency budgets, glitch hunting)
- DSP — even reviewing third-party DSP code, choosing buffer sizes, picking sample rates

## The First Question — What kind of audio problem is this?

Before reaching for any pattern, **classify the problem**. The expensive class of mistake is solving the wrong scale of question — most often, reaching for a canonical lock-free SPSC-FIFO refactor when the actual bug lives in control-plane ordering or session lifecycle.

| Class | Symptom | Where the fix lives |
|---|---|---|
| **Buffer-fill / DSP** | Audio glitches, clicks, dropouts under CPU load; per-sample artefacts; render-callback overrun | RT-safe DSP, lock-free SPSC ring buffer, pre-allocated scratch, possibly audio workgroups |
| **Control-plane ordering** | Stuck notes, "stop didn't take effect", out-of-order MIDI, first note after a stop is silent | Unify the dispatch path; remove redundant cleanup paths; serialize at the right boundary |
| **Session / lifecycle** | Audio cuts when phone rings; doesn't resume after Siri; silent after headphones unplug; engine crashes on backgrounding | `AVAudioSession` notification handling, engine restart, configuration-change observers, media-server-reset recovery |
| **AU / sampler semantics** | Single voice misbehaves; `stopNote` affects other notes; `reset()` crashes; voice steal misfires | AU-specific. Often undocumented. Investigate empirically; document what the AU *actually* does |
| **Format / topology** | Silence; wrong pitch; crackle on connect; "AVAudioFormat does not match" thrown | Read `node.outputFormat(forBus:)` after session activation; never hardcode rates; use the mixer for SR conversion |
| **Permissions / capabilities** | Recording silent; background audio drops; mic permission dialog never appears | Info.plist (`NSMicrophoneUsageDescription`), `UIBackgroundModes`, signing & capabilities |

See `references/scope-and-framing.md` for the decision tree and a worked example.

## Fast Path

When handed an audio bug or task:

1. **Identify the scope.** Use the table above. If you're tempted to introduce a lock-free FIFO, first prove the problem isn't a control-plane multiplex or a session-lifecycle gap you can close more cheaply.
2. **Map the dispatch topology.** List every path that submits work to the engine / AU / queue under scrutiny. Most stop-then-play races come from multiple uncoordinated paths converging on one consumer.
3. **Locate the boundary.** Where does non-realtime code (main thread, Swift Task, dispatch queue) hand work to the render thread? Every such boundary needs an explicit ordering and a non-blocking submission primitive.
4. **Check what the AU actually does.** Closed-source Audio Units (notably `AVAudioUnitSampler`, third-party AUv3s) have undocumented voice / CC behaviour. Treat MIDI-spec semantics as a hypothesis, verify empirically.
5. **Prefer the smallest fix that closes the issue.** Removing a redundant dispatch path beats a dispatch unification. Unifying beats spinning up a new threading primitive. Use the smallest tool that resolves the actual symptom.

## Cardinal Rules of the Render Thread

The audio render thread runs at real-time priority on a system-owned pthread (time-constraint policy). The OS schedules it deterministically against a deadline tied to the I/O buffer size and sample rate. Miss the deadline → glitch. Cause a priority inversion → stall.

Anything called on the render thread (a render callback, an `AURenderBlock`, an `AVAudioSourceNode` block, an `AVAudioSinkNode` block, an audio tap block, or a thread you joined to the audio workgroup) **must not**:

1. **Allocate or free heap memory.** No `malloc`/`free`, no `new`/`delete`, no Swift class allocation, no `Array.append` past capacity, no `String` construction, no implicit boxing, no autorelease pool growth. Pre-allocate at setup.
2. **Hold a contended lock.** Blocking acquisition causes priority inversion. `try_lock` with a defined fallback is acceptable; `lock`/`pthread_mutex_lock` from the render thread is not.
3. **Call Objective-C/Swift runtime services that can lock or allocate.** ARC retain/release on non-trivially-immortal references contends `swift_retain`'s global table; `os_log` with formatted args allocates; KVO posts notifications; closures capturing class references retain on entry.
4. **Do I/O.** No file access, no network, no `print`, no syscalls that may block. This includes accessing a memory-mapped buffer whose pages aren't yet resident — touch the pages at setup.

Apple states the contract directly on `AVAudioSourceNode`:

> The code in the block must be realtime-safe. Don't make any blocking calls (including allocation, locks, file I/O, or Objective-C messaging) from within the render block.

Detail: `references/realtime-rules.md`. Swift-specific traps: same file. Audit checklist: same file.

## Common Diagnostics

| Symptom | First check | Smallest safe fix | Reference |
|---|---|---|---|
| First note after a stop is silent | Are multiple cleanup paths racing the noteOn? | Remove the redundant cleanup; keep one canonical path | `scope-and-framing.md`, `inter-thread-patterns.md` |
| Stuck note (won't stop) | Was noteOff dispatched on the same channel/key? Did it get dropped during a session interruption? | Track outstanding noteOns; flush on stop/cancel/interruption with CC#123 + CC#120 per channel | `midi.md` |
| Audio glitch / dropout | Is anything on the render path allocating, locking, or doing I/O? | Audit the render block; move offending work off-thread | `realtime-rules.md`, `performance-and-debugging.md` |
| Silent after headphones unplug | Are you observing `routeChangeNotification` with reason `.oldDeviceUnavailable`? | Pause engine on that reason (Apple HIG) | `avaudiosession.md` |
| Silent after phone call / Siri | Are you observing `interruptionNotification` and honoring `.shouldResume` on `.ended`? | Standard interruption handler | `avaudiosession.md` |
| Engine crash on configuration change | Are you rebuilding the graph on `configurationChangeNotification`? | Reconnect with the new hardware format; restart engine | `avaudio-engine.md` |
| MIDI events arrive at wrong time | Are you scheduling with `AUEventSampleTimeImmediate + offsetFrames` from the render thread? | Switch to the Liljedahl pattern; ban absolute `mSampleTime` | `midi.md` |
| Wrong pitch / crackle on capture | Did you assume 44.1 kHz when the input node is 48 kHz (or BT HFP 16 kHz)? | Read `inputNode.inputFormat(forBus: 0)` after activation; convert if needed | `avaudio-engine.md`, `file-io-and-recording.md` |
| Sampler crashes on `reset()` | Empirically reported under load. | Avoid `reset()`; issue CC#123 + CC#120 panic per used channel instead | `midi.md` |
| `auval` rejects my AUv3 | Format negotiation, parameter ranges, state save/restore, or `maximumFramesToRender` | Fix the validator's specific complaint before resubmitting to Logic | `audio-units.md`, `performance-and-debugging.md` |
| Spatial source not localizing | Is the source mono? Are you routing through `AVAudioEnvironmentNode`? Updating listener orientation? | Mono buffer + environment node + write `listenerAngularOrientation` on motion updates | `spatial-audio.md` |
| Background audio stops | Capability "Audio, AirPlay, Picture in Picture" enabled? Session active during background? | Add capability; keep session active | `avaudiosession.md` |
| Worker thread for parallel DSP stalls or runs on E-cores | Did you join the audio workgroup? Holding membership across sleeps? | Join the host's `os_workgroup`; leave before exit; respect the work interval | `audio-workgroups.md` |
| `auval -v aufx XXXX YYYY` fails on format/MIDI | Misconfigured `inputBusses`/`outputBusses`, missing `AUMIDIEventListBlock`, or non-RT-safe render block | Walk the failed test; check `internalRenderBlock` contract | `audio-units.md` |

## Topic Map

Open the smallest reference that matches the question.

- **Scope and framing** — `references/scope-and-framing.md` — control-plane vs buffer-fill vs lifecycle vs AU-semantics; when SPSC-FIFO is right vs overkill; the decision tree.
- **Real-time rules** — `references/realtime-rules.md` — the four rules; Swift/ARC traps; auditing a render block; Swift Concurrency vs the render thread.
- **Inter-thread patterns** — `references/inter-thread-patterns.md` — SPSC FIFO, atomic swap, second-queue acknowledgement, atomic flag anti-pattern.
- **AVAudioEngine** — `references/avaudio-engine.md` — engine, nodes, formats, connections, lifecycle, manual rendering, configuration changes.
- **Audio Units (AUv2 / AUv3)** — `references/audio-units.md` — hosting installed AUs, writing an AUv3 extension, `AUAudioUnit` contract, parameters, presets, MIDI in/out, `auval`.
- **Low-level Core Audio / AudioToolbox** — `references/core-audio-low-level.md` — when to drop below AVAudioEngine; `AudioStreamBasicDescription`, `AudioBufferList`, HAL on macOS, `AudioServerPlugIn`, AudioDriverKit, ExtAudioFile.
- **CoreMIDI and MIDI** — `references/midi.md` — MIDI 1.0 vs 2.0 / UMP, `MIDIEventList` vs `MIDIPacketList`, virtual sources/destinations, scheduling MIDI into AUs, panic, MusicSequence vs AVAudioSequencer.
- **AVAudioSession (iOS lifecycle)** — `references/avaudiosession.md` — categories, modes, options, activation, interruption, route change, media-server reset, macOS equivalents.
- **Spatial / 3D audio** — `references/spatial-audio.md` — `AVAudioEnvironmentNode`, PHASE, HRTF rendering, AirPods head tracking, Atmos channel layouts.
- **Audio workgroups** — `references/audio-workgroups.md` — `os_workgroup`, joining the host's workgroup from parallel DSP threads, work intervals; advanced topic.
- **File I/O and recording** — `references/file-io-and-recording.md` — formats (PCM/AAC/ALAC/FLAC/CAF), `AVAudioFile`, `ExtAudioFile`, recording paths, mic permission, tap-on-bus, format conversion.
- **Performance and debugging** — `references/performance-and-debugging.md` — Instruments templates (Audio System Trace, Time Profiler with waiting threads), `auval`, `os_signpost` with RT caveat, reproducing dropouts.
- **DSP fundamentals** — `references/dsp-fundamentals.md` — Nyquist, PCM formats, latency math, block processing, biquads, FFT, dBFS, gain staging, denormals, Accelerate/vDSP.
- **Cross-platform context** — `references/cross-platform.md` — VST3 / AU / AAX / CLAP / LV2; JUCE; DAW hosting matrix; ADC and the broader audio-developer community.
- **Sources** — `references/sources.md` — annotated reading list; what each authority does and doesn't say.

## Authority Discipline

Cite responsibly. The real-time audio canon is *community-consensus*, not *Apple-documented*. Defend recommendations by naming the practitioner.

- **Ross Bencina** (rossbencina.com) — canonical for the foundational rules and the why-not. The "Real-time audio programming 101: time waits for nothing" essay is the universal starting point. QueueWorld provides reference C++ SPSC primitives.
- **Timur Doumler** (timur.audio, ADC and CppCon talks) — clarifies what real-time safety actually means; "Using locks in real-time audio processing, safely" is the canonical reading on `try_lock` discipline. RCU swap pattern in "Thread Synchronisation in Real-Time Audio Processing With RCU".
- **Michael Tyson** (atastypixel.com, A Tasty Pixel) — practical iOS-shipped patterns: TPCircularBuffer, AEManagedValue, AEMessageQueue. "Four common mistakes in audio development" is the canonical iOS-practitioner essay.
- **Joel Liljedahl** (devnotes.kymatica.com, author of AUM) — empirical findings on sample-accurate MIDI dispatch into Audio Units, particularly the `AUEventSampleTimeImmediate + offsetFrames` pattern. His finding that absolute `mSampleTime` is unreliable is from iOS 11 (2018), never publicly re-verified, never publicly contradicted.
- **JUCE** (juce.com, docs.juce.com) — the cross-platform plugin reference. `AudioProcessor::processBlock`, `AudioProcessorValueTreeState`, `AbstractFifo`. The JUCE community forum and docs encode RT-safety conventions for plugin code that map directly to Apple platforms.
- **ADC — Audio Developer Conference** (audio.dev, YouTube `@audiodevcon`) — best single archive for RT-audio, DSP, plugin design talks. Doumler, Bencina, Vinnie Falco, Geraint Luff, Will Pirkle.
- **Apple Developer Documentation** (developer.apple.com/documentation) — authoritative for API surface; **often silent on threading semantics**. WWDC sessions sometimes fill the gap; sample code occasionally contradicts the docs.
- **Apple Developer Forums** — anecdotal. Verify the actual thread content before citing. Frequently-cited "thread-safety" threads turn out to be about something else.
- **AudioKit** (github.com/AudioKit/AudioKit) — the reference Swift integration. What's in the source *is* the community pattern; what's *missing* is informative but not prescriptive.

When defending an architectural recommendation, name the practitioner. Don't promote community-consensus to Apple authority.

## When You Need an Expert in the Loop

- **Music domain** (tuning, intervals, scales, rhythmic notation, instrument idiomatics, voice leading) — invoke `agent-music-domain-expert` when the audio code encodes musical assumptions that need cross-checking before they ossify.
- **Swift Concurrency** (`async`/`await`, actor isolation, Sendable on non-realtime side) — invoke `swift-concurrency` or `swift-concurrency-expert` for *non-realtime coordination*. They are not the right consult for render-thread questions; those belong here.
- **DSP algorithm design** (filter design, custom oscillator algorithms, novel reverb structures, ML-DSP) — beyond app-developer scope. Consult a DSP engineer; this skill makes you literate, not expert.
- **Apple platform-specific audio routing oddities** that don't appear in docs — search developer forums by symptom string and verify with `auval` / device testing. Several known oddities are catalogued in `references/sources.md`.

## Anti-Patterns

1. **"Add a lock-free FIFO"** as a reflexive fix for any audio race. First classify the bug. If it's control-plane or lifecycle, the fix is usually elsewhere — and cheaper.
2. **An atomic flag in parallel with an in-band event path** targeting the same consumer. The flag has no ordering relationship with events submitted via the in-band path. Either unify (put the trigger event in the queue), or carefully document why they can't conflict.
3. **Polling render-thread state from the main thread.** The canonical pattern is push, not pull. If the main thread needs to know "did it happen yet", the render thread posts back via a second queue.
4. **Assuming MIDI-spec semantics from a closed AU.** Especially `AVAudioUnitSampler`. Verify empirically; don't reason purely from the MIDI 1.0 spec.
5. **Calling `engine.reset()` or `auAudioUnit.reset()` to "clean up".** Has crashed in shipping apps. Prefer per-channel panic.
6. **Wrapping render-thread state in an `actor`.** Actors are non-realtime. The render thread cannot await.
7. **`Task { @MainActor in ... }` inside a render block.** Render blocks have no Swift Task and no actor isolation.
8. **Hardcoding 44.1 kHz** in connection formats. The hardware format is whatever the session negotiated; on iPhone it's typically 48 kHz, on Bluetooth HFP it can be 16 kHz mono.
9. **Touching `engine.start()` from a background queue without serializing graph mutations.** `attach`/`connect` are documented as safe from any thread but only one in flight at a time. Use a dedicated queue or `@MainActor`.
10. **`AUv3` without `auval`.** Logic and MainStage will refuse to load an AU that fails `auval`. Run it after every signing or Info.plist change.

## Verification Checklist

Before declaring an audio change correct:

1. The render thread does no allocation, no locking, no Obj-C/Swift messaging that can lock or allocate, no I/O.
2. Every main → render handoff has an explicit ordering and a non-blocking submission primitive.
3. Every cleanup path is enumerated; you can name the one canonical path.
4. Interruption is tested with airplane-mode toggle, incoming call, Siri, and route change (headphones unplug).
5. Stop-then-play in rapid succession (≥10 cycles) yields a consistently audible first note after each stop.
6. The engine survives a `configurationChangeNotification` (e.g., sample-rate change from an external interface or BT switch).
7. Background audio (if applicable) actually continues with the screen locked.
8. For an AUv3: `auval -v <type> <subtype> <manufacturer>` passes.
9. If you added a lock-free primitive, you justified why a simpler control-plane or lifecycle fix doesn't suffice.
10. Formats are read from the nodes, not hardcoded; sample-rate conversions go through `AVAudioConverter` or the mixer.

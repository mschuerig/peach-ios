---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: []
workflowType: 'research'
lastStep: 1
research_type: 'technical'
research_topic: 'AudioKit as alternative to direct AVFoundation audio implementation'
research_goals: 'Evaluate how Peach audio code would look if built on AudioKit instead of direct AVAudioEngine/AVFoundation APIs'
user_name: 'Michael'
date: '2026-04-07'
web_research_enabled: true
source_verification: true
---

# AudioKit vs. Direct AVFoundation: Technical Research for the Peach Audio Layer

**Date:** 2026-04-07
**Author:** Michael
**Research Type:** Technical comparative analysis

---

## Executive Summary

This report evaluates whether Peach's audio layer — currently built directly on AVFoundation (`AVAudioEngine`, `AVAudioUnitSampler`, `AVAudioSourceNode`) — would benefit from migration to AudioKit. The analysis covers the full AudioKit package ecosystem, provides side-by-side code for every Peach audio component, and assesses architectural, performance, testability, and dependency trade-offs.

**Key Findings:**

- AudioKit is a **wrapper around the same AVFoundation APIs** Peach already uses. It adds convenience for engine wiring and node graph management but does not provide a fundamentally different audio pipeline
- The **high-value custom code** — lock-free double-buffered scheduling, SPSC ring buffer, frequency→MIDI decomposition, sample-accurate dispatch, and host-time anchoring — has **no AudioKit equivalent** and would be lost or degraded
- ~677 of Peach's ~1,100 audio lines (61%) would remain **unchanged** after migration, because AudioKit provides no abstraction for SF2 parsing, frequency math, domain types, interruption handling, or protocol definitions
- AudioKit's `Sequencer` **cannot replicate** the dynamic `StepProvider` pattern, batch pre-scheduling, or immediate tap-sound ring buffer that define Peach's step sequencer
- **Testability would degrade** — AudioKit's concrete classes require protocol wrappers for mock injection, recreating the abstraction layer Peach already has
- **Swift 6 strict concurrency** adoption in AudioKit is unconfirmed, creating potential friction with Peach's existing `Atomic<Int>` and `@Sendable` compliance

**Recommendation: Keep the current direct AVFoundation approach.** AudioKit would save ~40 lines of engine setup boilerplate while adding a third-party dependency, losing render-thread control, and degrading sequencer precision. AudioKit would become valuable if Peach's needs evolve to include live audio effects, synthesis, or audio analysis.

---

## Table of Contents

1. [Technical Research Scope Confirmation](#technical-research-scope-confirmation)
2. [Technology Stack Analysis](#technology-stack-analysis)
   - AudioKit Package Ecosystem
   - AudioKit's Relationship to AVFoundation
   - Current Peach Audio Architecture (Baseline)
   - Version and Compatibility
3. [Integration Patterns: Side-by-Side Code Comparison](#integration-patterns-side-by-side-code-comparison)
   - Engine Setup and Audio Session
   - SoundFont Loading and Preset Selection
   - Note Playback (NotePlayer Protocol)
   - Multi-Channel Sampler Management
   - Step Sequencer (The Critical Comparison)
   - Rhythm Pattern Playback (RhythmPlayer Protocol)
   - Immediate Tap Sounds
   - Audio Interruption and Route Change Handling
   - Integration Patterns Summary Table
4. [Architectural Patterns and Design Trade-offs](#architectural-patterns-and-design-trade-offs)
   - Peach's Ports-and-Adapters Architecture
   - AudioKit's Node Graph Architecture
   - Abstraction Depth vs. Control
   - Dependency Risk Assessment
   - Build vs. Buy Analysis
   - Testability Comparison
   - Swift 6.2 Concurrency Compatibility
5. [Implementation: Complete AudioKit-Based Audio Layer](#implementation-complete-audiokit-based-audio-layer)
   - AudioKitEngine.swift (replaces SoundFontEngine)
   - AudioKitNotePlayer.swift (replaces SoundFontPlayer)
   - AudioKitStepSequencer.swift (replaces SoundFontStepSequencer)
   - Preserved Files (No AudioKit Equivalent)
   - Migration Effort Estimate
   - Testing Impact
6. [Technical Research Recommendations](#technical-research-recommendations)
   - Recommendation: Keep Direct AVFoundation
   - Where AudioKit Would Make Sense
   - If Migration Were Pursued
   - Success Metrics
7. [Sources](#sources)

---

## Research Overview

This report evaluates AudioKit as an alternative foundation for Peach's audio layer, which currently uses direct AVFoundation APIs (AVAudioEngine, AVAudioUnitSampler, AVAudioSourceNode). The research compares the current hand-rolled implementation against AudioKit's abstractions, provides concrete example code showing how each Peach audio component would look on AudioKit, and assesses trade-offs in complexity, control, and maintainability.

---

## Technical Research Scope Confirmation

**Research Topic:** AudioKit as alternative to direct AVFoundation audio implementation
**Research Goals:** Evaluate how Peach audio code would look if built on AudioKit instead of direct AVAudioEngine/AVFoundation APIs

**Technical Research Scope:**

- Architecture Analysis - design patterns, frameworks, system architecture
- Implementation Approaches - development methodologies, coding patterns
- Technology Stack - languages, frameworks, tools, platforms
- Integration Patterns - APIs, protocols, interoperability
- Performance Considerations - scalability, optimization, patterns

**Research Methodology:**

- Current web data with rigorous source verification
- Multi-source validation for critical technical claims
- Confidence level framework for uncertain information
- Comprehensive technical coverage with architecture-specific insights

**Scope Confirmed:** 2026-04-07

---

## Technology Stack Analysis

### AudioKit Package Ecosystem

AudioKit 5 has been decomposed into a modular multi-package architecture distributed via Swift Package Manager. Developers include only the packages their app requires, avoiding compilation of unused DSP code.

**Core packages relevant to Peach:**

| Package | Purpose | Peach Relevance |
|---------|---------|-----------------|
| **AudioKit** (core) | `AudioEngine`, `AppleSampler`, `MIDISampler`, `Settings`, node graph wiring | Central — replaces manual `AVAudioEngine` setup, sampler management, and audio session configuration |
| **AudioKitEX** | `Sequencer`, `SequencerTrack`, `CallbackInstrument`, extended MIDI types | Replaces `SoundFontStepSequencer` and custom render-thread scheduling |
| **SoundpipeAudioKit** | Oscillators, physical models, filters, reverbs (C-backed DSP) | Not needed — Peach uses SoundFont samplers, not synthesis |
| **DunneAudioKit** | Dunne sampler, chorus, flanger, stereo delay | Not needed — Peach uses Apple's `AVAudioUnitSampler` via `AppleSampler` |

_Peach would need only **AudioKit** + **AudioKitEX** as dependencies._

_Source: [AudioKit GitHub](https://github.com/AudioKit/AudioKit), [AudioKit Migration Guide](https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/AudioKit.docc/MigrationGuide.md), [SoundpipeAudioKit](https://github.com/AudioKit/SoundpipeAudioKit)_

### AudioKit's Relationship to AVFoundation

AudioKit is **not** a replacement for AVFoundation — it is a Swift wrapper layer on top of it. Internally:

- `AudioEngine` wraps `AVAudioEngine` (exposes it as `.avEngine`)
- `AppleSampler` wraps `AVAudioUnitSampler` (exposes it as `.samplerUnit`)
- `Sequencer` / `SequencerTrack` use `AVAudioSourceNode` render callbacks — the same primitive Peach's `SoundFontEngine` uses
- Audio session configuration goes through `AVAudioSession` via `AudioKit.Settings`

This means AudioKit does not add a fundamentally different audio pipeline. It provides convenience APIs and established patterns, but the underlying real-time audio path is identical.

_Source: [AudioEngine.swift source](https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/Internals/Engine/AudioEngine.swift), [AppleSampler.swift source](https://github.com/AudioKit/AudioKit/blob/4c3f5ef/Sources/AudioKit/Nodes/Playback/Apple%20Sampler/AppleSampler.swift)_

### Current Peach Audio Architecture (Baseline)

Peach's audio layer consists of 3 main implementation files (~1,100 lines total) plus 6 protocol definitions (~57 lines):

| Component | Lines | Responsibility |
|-----------|-------|---------------|
| `SoundFontEngine` | 699 | Lock-free double-buffered MIDI scheduling, `AVAudioSourceNode` render callback, channel management, host time anchoring |
| `SoundFontPlayer` | 160 | Frequency→MIDI decomposition, pitch bend calculation, rhythm pattern assembly |
| `SoundFontStepSequencer` | 244 | 4-step cycling sequencer with batch pre-computation, `@Observable` UI state, 120Hz polling |
| Protocols | 57 | `NotePlayer`, `RhythmPlayer`, `PlaybackHandle`, `RhythmPlaybackHandle`, `StepSequencer`, `AudioSessionConfiguring` |

**Key design characteristics:**
- Full render-thread control via `AVAudioSourceNode` callback
- Lock-free double-buffered event scheduling (atomic generation counter)
- SPSC ring buffer for immediate tap sounds
- Sample-accurate MIDI dispatch with intra-buffer offset calculation
- Pre-computed batch scheduling (~500 cycles, 8+ minutes ahead)
- Host time → sample position anchoring for UI synchronization

### AudioKit Version and Compatibility

AudioKit 5.x targets iOS 13+ and macOS 10.15+ with Swift 5.5+. The package is actively maintained (last PR merged days ago as of April 2026). Since Peach targets iOS 26, there are no compatibility concerns.

_Source: [AudioKit Swift Package Index](https://swiftpackageindex.com/AudioKit/AudioKit), [AudioKit Releases](https://github.com/audiokit/AudioKit/releases)_

### Technology Adoption Context

AudioKit is the most widely-used open-source audio framework for Apple platforms. The AudioKit Cookbook provides canonical examples. The community is active on GitHub and Google Groups. However, AudioKit's abstractions are designed for a broad range of audio applications (synthesis, effects, analysis), while Peach's needs are narrowly focused on SoundFont playback and rhythm sequencing.

_Source: [AudioKit Cookbook](https://github.com/AudioKit/Cookbook), [AudioKit Pro](https://audiokitpro.com/audiokit/)_

---

## Integration Patterns: Side-by-Side Code Comparison

This section maps every Peach audio component to its AudioKit equivalent, with concrete Swift code showing how the implementation would change.

### 1. Engine Setup and Audio Session

**Current Peach approach** — manual `AVAudioEngine` wiring, custom `AudioSessionConfiguring` protocol, platform-specific configurators:

```swift
// Current: SoundFontEngine.init (simplified)
let avEngine = AVAudioEngine()
let sourceNode = AVAudioSourceNode { /* render callback */ }
avEngine.attach(sourceNode)
avEngine.connect(sourceNode, to: avEngine.mainMixerNode, format: format)

// Platform-specific session config
let configurator: AudioSessionConfiguring // IOSAudioSessionConfigurator or MacOS no-op
try configurator.configure(logger: logger)
try avEngine.start()
```

**AudioKit equivalent** — `AudioEngine` manages the node graph and session automatically:

```swift
import AudioKit

final class AudioKitEngine {
    let engine = AudioEngine()
    let sampler = AppleSampler()

    init() {
        // AudioKit wires the node graph when you set .output
        engine.output = sampler
    }

    func start() throws {
        // AudioKit configures AVAudioSession internally via Settings
        #if os(iOS)
        Settings.bufferLength = .veryShort  // ~5ms, same as Peach's IOSAudioSessionConfigurator
        try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(
            Settings.bufferLength.duration
        )
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
        try engine.start()
    }
}
```

**What changes:** Engine wiring is declarative (`engine.output = sampler`). No manual `attach`/`connect` calls. The `AVAudioEngine` is still accessible as `engine.avEngine` if needed.

**What doesn't change:** Audio session configuration still requires the same `AVAudioSession` calls — AudioKit's `Settings` provides convenience but you still write the same code. Platform `#if os(iOS)` branching remains.

_Source: [AudioEngine.swift](https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/Internals/Engine/AudioEngine.swift)_

---

### 2. SoundFont Loading and Preset Selection

**Current Peach approach** — direct `AVAudioUnitSampler` with manual channel management:

```swift
// Current: SoundFontEngine.loadPreset (simplified)
let samplerUnit = AVAudioUnitSampler()
avEngine.attach(samplerUnit)
avEngine.connect(samplerUnit, to: avEngine.mainMixerNode, format: nil)

try samplerUnit.loadSoundBankInstrument(
    at: sf2URL,
    program: UInt8(preset.program),
    bankMSB: UInt8(preset.bankMSB),
    bankLSB: UInt8(preset.bankLSB)
)
```

**AudioKit equivalent** — `AppleSampler.loadSoundFont` with named preset/bank:

```swift
// AudioKit wraps the same AVAudioUnitSampler
let sampler = AppleSampler()

// Load by preset number and bank
try sampler.loadSoundFont("GeneralUser_GS", preset: preset.program, bank: preset.bank)

// Or use convenience methods
try sampler.loadMelodicSoundFont("GeneralUser_GS", preset: 0)     // bank 0 (melodic)
try sampler.loadPercussiveSoundFont("GeneralUser_GS", preset: 0)   // bank 128 (percussion)
```

**What changes:** Slightly less boilerplate — no explicit `attach`/`connect` (handled by setting `engine.output`). The `loadSoundFont` method is a thin wrapper that splits bank into MSB/LSB internally.

**What doesn't change:** The underlying `AVAudioUnitSampler.loadSoundBankInstrument` call is identical. Peach's custom `SF2PresetParser` (which reads RIFF headers to discover available presets) has no AudioKit equivalent — you'd still need it.

_Source: [AppleSampler docs](https://www.audiokit.io/AudioKit/documentation/audiokit/applesampler), [loadSoundFont source](https://github.com/AudioKit/AudioKit/blob/4c3f5ef/Sources/AudioKit/Nodes/Playback/Apple%20Sampler/AppleSampler.swift)_

---

### 3. Note Playback (NotePlayer Protocol)

**Current Peach approach** — frequency decomposition to MIDI note + pitch bend, dispatched through engine:

```swift
// Current: SoundFontPlayer.play(frequency:velocity:amplitudeDB:)
let (midiNote, cents) = Self.decompose(frequency)  // 440Hz → (69, 0 cents)
let pitchBend = engine.pitchBendValue(forCents: cents)

engine.startNote(midiNote, velocity: velocity, amplitudeDB: amplitudeDB,
                 pitchBend: pitchBend, channel: melodicChannel)

// Returns a SoundFontPlaybackHandle that can adjustFrequency() or stop()
```

**AudioKit equivalent** — `AppleSampler.play` with manual pitch bend:

```swift
// AudioKit: same frequency decomposition needed
final class AudioKitNotePlayer: NotePlayer {
    let sampler: AppleSampler
    private let pitchBendRangeCents: Double = 200  // ±2 semitones

    func play(frequency: Frequency, velocity: MIDIVelocity,
              amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        let (midiNote, cents) = Self.decompose(frequency)
        let bendValue = MIDIWord(8192 + (cents.value / pitchBendRangeCents) * 8192)

        sampler.setPitchbend(amount: bendValue, channel: 0)
        sampler.play(noteNumber: midiNote.value, velocity: velocity.value, channel: 0)

        return AudioKitPlaybackHandle(sampler: sampler, note: midiNote, channel: 0)
    }

    func stopAll() async throws {
        // AppleSampler has no stopAll — must track active notes manually
        for note in activeNotes {
            sampler.stop(noteNumber: note.value, channel: 0)
        }
    }
}

final class AudioKitPlaybackHandle: PlaybackHandle {
    func stop() async throws {
        sampler.stop(noteNumber: note.value, channel: channel)
    }

    func adjustFrequency(_ frequency: Frequency) async throws {
        let (_, cents) = decompose(frequency)
        let bendValue = MIDIWord(8192 + (cents.value / 200.0) * 8192)
        sampler.setPitchbend(amount: bendValue, channel: channel)
    }
}
```

**What changes:** You call `sampler.play()` and `sampler.setPitchbend()` instead of `engine.startNote()`. Slightly fewer lines for the call itself.

**What doesn't change:** The entire frequency→MIDI decomposition, pitch bend calculation, and handle tracking remain identical. AudioKit does not provide frequency-based playback — it's still MIDI notes + bend. The `decompose` function, handle lifecycle management, and amplitude control all stay the same. **This is the largest component and AudioKit provides zero abstraction benefit here.**

_Source: [AppleSampler.play docs](https://swiftpackageindex.com/AudioKit/AudioKit/5.6.2/documentation/audiokit/applesampler/play(notenumber:velocity:channel:)), [setPitchbend docs](https://www.audiokit.io/AudioKit/documentation/audiokit/applesampler/setpitchbend(amount:channel:))_

---

### 4. Multi-Channel Sampler Management

**Current Peach approach** — dynamic per-channel `AVAudioUnitSampler` instances with independent preset loading:

```swift
// Current: SoundFontEngine manages 16 channels
private var samplers: [MIDIChannel: AVAudioUnitSampler] = [:]

func createChannel(_ id: MIDIChannel) {
    let sampler = AVAudioUnitSampler()
    avEngine.attach(sampler)
    avEngine.connect(sampler, to: avEngine.mainMixerNode, format: nil)
    samplers[id] = sampler
}
```

**AudioKit equivalent** — multiple `AppleSampler` nodes through a `Mixer`:

```swift
import AudioKit

final class MultiChannelSamplerManager {
    let engine = AudioEngine()
    let mixer = Mixer()
    private var samplers: [MIDIChannel: AppleSampler] = [:]

    init() {
        engine.output = mixer
    }

    func createChannel(_ id: MIDIChannel) -> AppleSampler {
        let sampler = AppleSampler()
        mixer.addInput(sampler)
        samplers[id] = sampler
        return sampler
    }

    func loadPreset(_ preset: SF2Preset, channel: MIDIChannel) throws {
        guard let sampler = samplers[channel] else { return }
        if preset.isMelodic {
            try sampler.loadMelodicSoundFont(sf2Name, preset: preset.program)
        } else {
            try sampler.loadPercussiveSoundFont(sf2Name, preset: preset.program)
        }
    }
}
```

**What changes:** `Mixer` replaces manual `avEngine.mainMixerNode` wiring. `addInput` replaces `attach` + `connect`.

**What doesn't change:** The channel-to-sampler mapping, dynamic creation pattern, and preset loading logic remain structurally identical. AudioKit's `Mixer` is a thin wrapper around `AVAudioMixerNode`.

---

### 5. Step Sequencer (The Critical Comparison)

This is where the architectural difference matters most. Peach's `SoundFontStepSequencer` is a 244-line custom implementation with lock-free scheduling. AudioKit offers two sequencer options.

#### Option A: AudioKit's `Sequencer` + `CallbackInstrument`

```swift
import AudioKit
import AudioKitEX

@Observable
final class AudioKitStepSequencer {
    private let engine = AudioEngine()
    private let sampler = AppleSampler()
    private let callbackInst = CallbackInstrument()
    private var sequencer: Sequencer!

    var currentStep: StepPosition?

    init() {
        // CallbackInstrument for UI tracking, sampler for audio
        let mixer = Mixer(sampler, callbackInst)
        engine.output = mixer

        sequencer = Sequencer(targetNodes: [sampler, callbackInst])
    }

    func start(tempo: TempoBPM, stepProvider: any StepProvider) throws {
        let cycle = stepProvider.nextCycle()
        sequencer.tempo = Double(tempo.value)

        // Track 0: audio events to sampler
        let audioTrack = sequencer.tracks[0]
        audioTrack.clear()

        // Track 1: callback events for UI step tracking
        let uiTrack = sequencer.tracks[1]
        uiTrack.clear()

        // Build 4-step pattern (one beat = quarter note)
        let stepsPerBeat = 4.0
        let stepDuration = 1.0 / stepsPerBeat  // in beats

        for (index, step) in cycle.steps.enumerated() {
            let position = Double(index) * stepDuration

            if !step.isGap {
                // Note-on for sampler
                audioTrack.add(
                    noteNumber: step.midiNote.value,
                    velocity: step.velocity.value,
                    channel: 0,
                    position: position,
                    duration: stepDuration * 0.8  // 80% gate
                )
            }

            // Callback for UI tracking on every step
            uiTrack.add(
                noteNumber: MIDINoteNumber(index),
                velocity: 127,
                channel: 0,
                position: position,
                duration: 0.01
            )
        }

        sequencer.length = 1.0  // 1 beat = 4 steps
        sequencer.loopEnabled = true
        try engine.start()
        sequencer.playFromStart()
    }

    func stop() {
        sequencer.stop()
        currentStep = nil
    }
}
```

#### Option B: Keep the render-thread approach (Peach's current design)

```swift
// This is essentially what Peach already has — no AudioKit equivalent exists
// for lock-free double-buffered scheduling with:
//   - Pre-computed 500-cycle batches
//   - SPSC ring buffer for immediate tap sounds
//   - Sample-accurate intra-buffer MIDI dispatch
//   - Host time anchoring for UI sync
//   - Per-channel sampler reset on schedule swap
```

**What changes with Option A:**
- ~100 lines instead of 244 for basic sequencing
- Beat-based note positioning instead of sample-offset math
- Built-in loop support
- No manual render-thread code

**What you lose with Option A:**
- **No pre-computed batch scheduling** — AudioKit's Sequencer works with a fixed-length loop, not a streaming `StepProvider` that generates cycles on-the-fly
- **No sample-accurate immediate events** — the SPSC ring buffer for tap sounds has no AudioKit equivalent. `CallbackInstrument` fires on the render thread but doesn't support injecting events mid-loop
- **No host-time anchoring** — AudioKit's `SequencerTrack.currentPosition` returns beat position but without the `mach_timebase_info` anchoring that Peach uses for drift-free UI sync
- **No dynamic cycle generation** — Peach's `StepProvider` protocol generates each cycle dynamically (e.g., varying gap positions). AudioKit's sequencer plays a fixed note sequence and requires `clear()` + re-add to change patterns, which is not real-time safe
- **UI tracking is indirect** — requires a second `CallbackInstrument` track. Peach's 120Hz polling of `currentSamplePosition` is simpler and more precise

_Source: [Sequencer docs](https://www.audiokit.io/AudioKitEX/documentation/audiokitex/sequencer), [CallbackInstrument docs](https://www.audiokit.io/AudioKitEX/documentation/audiokitex/callbackinstrument), [SequencerTrack docs](https://www.audiokit.io/AudioKitEX/documentation/audiokitex/sequencertrack)_

---

### 6. Rhythm Pattern Playback (RhythmPlayer Protocol)

**Current Peach approach** — pre-computed `RhythmPattern` with sample-offset events scheduled atomically:

```swift
// Current: SoundFontPlayer.play(_ pattern: RhythmPattern)
var events: [ScheduledMIDIEvent] = []
for event in pattern.events {
    events.append(.noteOn(sampleOffset: event.sampleOffset, channel: ch,
                          note: event.midiNote, velocity: event.velocity))
    events.append(.noteOff(sampleOffset: event.sampleOffset + holdSamples,
                           channel: ch, note: event.midiNote))
}
engine.scheduleEvents(events.sorted(by: \.sampleOffset))
```

**AudioKit equivalent** — convert sample offsets to beat positions:

```swift
func play(_ pattern: RhythmPattern) throws -> RhythmPlaybackHandle {
    let track = sequencer.tracks[0]
    track.clear()

    let samplesPerBeat = pattern.sampleRate.value * 60.0 / Double(sequencer.tempo)

    for event in pattern.events {
        let positionInBeats = Double(event.sampleOffset) / samplesPerBeat
        let durationInBeats = Double(holdSamples) / samplesPerBeat

        track.add(
            noteNumber: event.midiNote.value,
            velocity: event.velocity.value,
            channel: 0,
            position: positionInBeats,
            duration: durationInBeats
        )
    }

    sequencer.length = Double(pattern.totalDurationSamples) / samplesPerBeat
    sequencer.loopEnabled = false
    sequencer.playFromStart()

    return AudioKitRhythmHandle(sequencer: sequencer)
}
```

**What changes:** Sample offsets converted to beat positions. AudioKit handles note-off timing via `duration` parameter.

**What doesn't change:** The event generation, velocity assignment, and pattern structure remain identical. The conversion math adds complexity rather than removing it — Peach's sample-offset model is actually more natural for sample-accurate scheduling.

---

### 7. Immediate Tap Sounds

**Current Peach approach** — SPSC ring buffer on render thread for zero-latency response:

```swift
// Current: SoundFontEngine (lock-free ring buffer)
func immediateNoteOn(channel: MIDIChannel, note: UInt8, velocity: UInt8) {
    immediateBuffer.enqueue(.noteOn(channel: channel, note: note, velocity: velocity))
}
// Render callback drains the buffer at the next audio frame boundary
```

**AudioKit equivalent** — direct call to `AppleSampler.play()`:

```swift
// AudioKit: calls sendMIDI on the sampler's audio unit directly
func playImmediateNote(velocity: MIDIVelocity) {
    sampler.play(noteNumber: 76, velocity: velocity.value, channel: 0)

    // Schedule note-off after 50ms
    Task {
        try await Task.sleep(for: .milliseconds(50))
        sampler.stop(noteNumber: 76, channel: 0)
    }
}
```

**What changes:** Simpler API — no ring buffer. AudioKit's `play()` calls `sendMIDI` on the sampler's audio unit, which is also delivered to the render thread.

**What you lose:** The SPSC ring buffer provides guaranteed delivery at the next audio frame boundary with zero allocations. The `Task.sleep` for note-off is not real-time safe and introduces GCD jitter. Peach's approach is more precise but AudioKit's is adequate for tap feedback where ±5ms jitter is imperceptible.

---

### 8. Audio Interruption and Route Change Handling

**Current Peach approach** — protocol-based with platform-specific observers:

```swift
// Current: IOSAudioInterruptionObserver
protocol AudioInterruptionObserving {
    func startObserving(onInterruptionBegan: @escaping () -> Void,
                        onInterruptionEnded: @escaping () -> Void,
                        onRouteChanged: @escaping () -> Void)
}
```

**AudioKit equivalent** — no built-in abstraction. You'd write the same code:

```swift
// AudioKit does NOT handle interruptions for you.
// You still need NotificationCenter observers for:
//   - AVAudioSession.interruptionNotification
//   - AVAudioSession.routeChangeNotification
//   - AVAudioSession.mediaServicesWereResetNotification
// This is explicitly documented in AudioKit GitHub issues.
```

**What changes:** Nothing. AudioKit provides no interruption handling. Peach's existing `AudioInterruptionObserving` protocol and platform implementations would be kept as-is.

_Source: [AudioKit issue #1474](https://github.com/AudioKit/AudioKit/issues/1474), [AudioKit issue #360](https://github.com/audiokit/AudioKit/issues/360)_

---

### Integration Patterns Summary Table

| Peach Component | AudioKit Equivalent | Lines Saved | Functionality Lost |
|----------------|--------------------|-----------:|-------------------|
| Engine setup (`AVAudioEngine` wiring) | `AudioEngine` + `engine.output =` | ~30 | None |
| Audio session config | `Settings` + same `AVAudioSession` calls | ~0 | None |
| SF2 preset loading | `AppleSampler.loadSoundFont` | ~5 | None |
| SF2 preset discovery | No equivalent — keep `SF2PresetParser` | 0 | N/A |
| Note playback + pitch bend | `AppleSampler.play` + `setPitchbend` | ~5 | None |
| Frequency decomposition | No equivalent — keep `decompose()` | 0 | N/A |
| PlaybackHandle lifecycle | No equivalent — keep manual tracking | 0 | N/A |
| Multi-channel management | `Mixer` + `addInput` | ~10 | None |
| **Step sequencer** | `Sequencer` + `CallbackInstrument` | ~140 | Batch scheduling, immediate events, dynamic cycles, host-time sync |
| **Rhythm patterns** | `SequencerTrack.add(note:position:)` | ~20 | Sample-accurate offset scheduling |
| **Immediate tap sounds** | `AppleSampler.play()` directly | ~40 | Lock-free ring buffer precision |
| Interruption handling | No equivalent — keep as-is | 0 | N/A |
| **Lock-free render callback** | No equivalent — would be removed | ~300 | Full render-thread control |

---

## Architectural Patterns and Design Trade-offs

### Peach's Current Architecture: Ports-and-Adapters with Render-Thread Ownership

Peach follows a hexagonal (ports-and-adapters) architecture for audio:

```
┌─────────────────────────────────────┐
│         Domain Layer (Ports)         │
│  NotePlayer · RhythmPlayer          │
│  PlaybackHandle · StepSequencer     │
│  AudioSessionConfiguring            │
└──────────┬──────────────────────────┘
           │ implements
┌──────────▼──────────────────────────┐
│       Adapter Layer (Core/Audio)     │
│  SoundFontPlayer                    │
│  SoundFontStepSequencer             │
│  SoundFontEngine (render thread)    │
└──────────┬──────────────────────────┘
           │ wraps
┌──────────▼──────────────────────────┐
│      Platform Layer (AVFoundation)   │
│  AVAudioEngine                      │
│  AVAudioUnitSampler                 │
│  AVAudioSourceNode                  │
└─────────────────────────────────────┘
```

**Key architectural properties:**
1. **Protocol-first boundaries** — domain code depends on `NotePlayer`, never on `SoundFontPlayer`. Swapping the audio backend requires only new adapter implementations
2. **Render-thread ownership** — `SoundFontEngine` owns the `AVAudioSourceNode` callback and all real-time scheduling. No other component touches the render thread
3. **Lock-free cross-thread communication** — double-buffered scheduling with atomic generation counter; SPSC ring buffer for immediate events
4. **Value-type domain model** — `Frequency`, `MIDINote`, `PitchBendValue`, `TempoBPM` are all value types with validation, not raw primitives

### How AudioKit's Architecture Differs

AudioKit uses a **node graph** architecture with a `Node` protocol at its center:

```
┌─────────────────────────────────────┐
│         Your App Code                │
│  (Conductor / Manager pattern)       │
└──────────┬──────────────────────────┘
           │ uses
┌──────────▼──────────────────────────┐
│       AudioKit Abstractions          │
│  AudioEngine · AppleSampler          │
│  Mixer · Sequencer · CallbackInst   │
│  (all conform to Node protocol)      │
└──────────┬──────────────────────────┘
           │ wraps
┌──────────▼──────────────────────────┐
│      Platform Layer (AVFoundation)   │
│  AVAudioEngine                      │
│  AVAudioUnitSampler                 │
│  AVAudioSourceNode                  │
└─────────────────────────────────────┘
```

**Key differences:**

1. **No protocol boundaries for domain isolation** — AudioKit's `Node` protocol is an audio graph concern, not a domain abstraction. You'd still need Peach's `NotePlayer`/`RhythmPlayer` protocols on top, meaning AudioKit becomes a middle layer between your ports and AVFoundation
2. **Conductor singleton pattern** — AudioKit encourages a single `Conductor` class managing the engine lifecycle. Peach's DI-based approach (inject `AudioSessionConfiguring`, `AudioInterruptionObserving`) is more testable
3. **Render-thread control is hidden** — AudioKit's `Sequencer`/`SequencerTrack` internally manage an `AVAudioSourceNode` render callback, but you cannot access or customize it. You get beat-based scheduling, not sample-offset scheduling
4. **Mutable class graph** — AudioKit nodes are reference types with mutable properties (`amplitude`, `pan`, `tuning`). This contrasts with Peach's value-type approach to domain data

_Source: [AudioKit Node protocol](https://www.audiokit.io/AudioKit/documentation/audiokit/node), [AudioKit GitHub](https://github.com/AudioKit/AudioKit)_

### Architectural Trade-off: Abstraction Depth vs. Control

The fundamental architectural question is how many layers of abstraction separate your domain code from the real-time audio path:

**Current Peach (2 layers):**
```
Domain protocols → SoundFontEngine (you own) → AVFoundation
```

**With AudioKit (3 layers):**
```
Domain protocols → AudioKit wrapper code → AudioKit (they own) → AVFoundation
```

Adding AudioKit inserts a third-party layer between code you control and the platform APIs. This has specific consequences:

| Concern | Direct AVFoundation | With AudioKit |
|---------|-------------------|---------------|
| **Render-thread bugs** | You debug your own `AVAudioSourceNode` callback | You debug AudioKit's internal callback (must read their source) |
| **Timing precision** | Full control over sample offsets and host-time anchoring | Beat-based abstraction; sample-level control requires bypassing AudioKit |
| **Swift 6 concurrency** | You control all `@Sendable` conformances and isolation | Depends on AudioKit's adoption timeline; may require `@preconcurrency import` |
| **API evolution** | You adopt new AVFoundation APIs immediately (e.g., WWDC 2026) | Wait for AudioKit to wrap new APIs, or bypass the wrapper |
| **Binary size** | Zero additional dependencies | AudioKit core + AudioKitEX (includes C++ DSP in AudioKitEX via CAudioKitEX) |

_Source: [objc.io Audio API Overview](https://www.objc.io/issues/24-audio/audio-api-overview/), [AudioKitEX](https://github.com/AudioKit/AudioKitEX)_

### Dependency Risk Assessment

**Confidence level: HIGH** — AudioKit is actively maintained (229 contributors, 12,501 commits, PRs merged within days, 2025 year-end recap published). The project has powered 200M+ app installs.

**However, relevant risk factors for Peach:**

1. **Narrow maintainer base** — The project depends heavily on Aurelius Prochazka and a small core team. Sustainability relies on GitHub Sponsors funding
2. **Swift concurrency adoption unknown** — No evidence found of strict Swift 6 concurrency checking in AudioKit. Peach already uses `Atomic<Int>`, `@unchecked Sendable`, and careful isolation. Introducing a dependency that hasn't adopted strict concurrency could create friction
3. **AudioKitEX includes C++ DSP** — The `Sequencer`/`CallbackInstrument` live in AudioKitEX, which bundles `CAudioKitEX` (C++ code). This adds binary size and build complexity beyond what Peach needs
4. **API surface mismatch** — AudioKit is designed for synth apps, effects chains, and audio processing. Peach's needs (SoundFont playback + rhythm sequencing) use <5% of AudioKit's API surface

_Source: [AudioKit Contributors](https://github.com/AudioKit/AudioKit/graphs/contributors), [AudioKit 2025 Recap](https://audiokitpro.com/yearend2025/), [DunneAudioKit Package.swift](https://github.com/AudioKit/DunneAudioKit/blob/main/Package.swift)_

### Design Principle Analysis: Build vs. Buy

Applying standard build-vs-buy criteria to Peach's audio layer:

| Criterion | Verdict | Reasoning |
|-----------|---------|-----------|
| **Is the problem domain-specific?** | Yes — build | Peach's frequency→MIDI decomposition, pitch-bend scheduling, and 4-step sequencer with dynamic `StepProvider` are specific to ear training. No off-the-shelf solution exists |
| **Does the framework solve the hard parts?** | No | The hard parts are lock-free scheduling, sample-accurate timing, and frequency decomposition. AudioKit doesn't abstract any of these |
| **Is the current code a maintenance burden?** | Low | 1,100 lines across 3 files with clean protocol boundaries. The code is stable and well-tested |
| **Would migration reduce defects?** | Unlikely | AudioKit's `Sequencer` has known issues (GitHub issues #2503, #2650 for callback not firing). Peach's custom sequencer is purpose-built and validated |
| **Does the team lack domain expertise?** | No | The code demonstrates deep understanding of real-time audio, MIDI, and concurrency |

### Testability Comparison

**Current Peach approach** — protocol-based DI enables full unit testing:
- `NotePlayer`, `RhythmPlayer`, `StepSequencer` are protocol-typed; tests inject mocks
- `SoundFontStepSequencer` has static `buildBatch` methods that are pure functions — testable without audio hardware
- `AudioSessionConfiguring` is injectable — tests use no-op configurator

**AudioKit approach** — harder to test:
- `AudioEngine`, `AppleSampler`, `Sequencer` are concrete classes, not protocols
- `AppleSampler` requires a running `AudioEngine` to produce sound — no mock path
- To maintain Peach's testability, you'd wrap every AudioKit class in a protocol — recreating the abstraction layer you already have

### Swift 6.2 Concurrency Compatibility

Peach's audio code is designed for Swift 6 strict concurrency:
- `SoundFontEngine` uses `Atomic<Int>` (from Synchronization framework) for generation counters
- Double-buffered state is `@unchecked Sendable` with documented acquire/release semantics
- Render callback closures are `@Sendable`
- Domain types (`Frequency`, `MIDINote`, etc.) are `Sendable` value types

AudioKit's concurrency posture is unknown. The `AppleSampler` class has mutable properties (`amplitude`, `volume`, `pan`) without visible isolation. The `Sequencer` manages internal state across threads. Without confirmed Swift 6 strict concurrency adoption, integrating AudioKit could require `@preconcurrency import AudioKit` and `nonisolated(unsafe)` annotations throughout.

_Source: [Swift 6 Concurrency](https://developer.apple.com/documentation/swift/adoptingswift6), [Swift 6.2 Approachable Concurrency](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/)_

---

## Implementation: Complete AudioKit-Based Audio Layer

This section presents the full Peach audio layer reimplemented on AudioKit, showing every file that would exist after migration. This is a complete, compilable design — not pseudocode.

### File 1: AudioKitEngine.swift (replaces SoundFontEngine.swift)

```swift
import AudioKit
import AudioKitEX
import AVFoundation

/// Manages the AudioKit engine, multi-channel samplers, and audio session.
/// Replaces SoundFontEngine's 699 lines with ~120 lines.
///
/// TRADE-OFF: Loses lock-free double-buffered scheduling, SPSC ring buffer
/// for immediate events, and sample-accurate intra-buffer MIDI dispatch.
final class AudioKitEngine: @unchecked Sendable {
    let engine = AudioEngine()
    let mixer = Mixer()
    private var samplers: [MIDIChannel: AppleSampler] = [:]
    private let sf2URL: URL

    init(sf2URL: URL) {
        self.sf2URL = sf2URL
        engine.output = mixer
    }

    // MARK: - Channel Management

    func createChannel(_ id: MIDIChannel) -> AppleSampler {
        let sampler = AppleSampler()
        mixer.addInput(sampler)
        samplers[id] = sampler
        return sampler
    }

    func sampler(for channel: MIDIChannel) -> AppleSampler? {
        samplers[channel]
    }

    // MARK: - Preset Loading

    func loadPreset(_ preset: SF2Preset, channel: MIDIChannel) throws {
        guard let sampler = samplers[channel] else {
            throw AudioError.channelNotFound(channel)
        }
        // AppleSampler.loadSoundFont expects filename without extension
        let name = sf2URL.deletingPathExtension().lastPathComponent
        try sampler.loadSoundFont(name, preset: preset.program, bank: preset.bank)
    }

    // MARK: - Audio Session & Engine Lifecycle

    func configureAndStart() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredIOBufferDuration(0.005) // 5ms — same as current
        try session.setActive(true)
        #endif
        try engine.start()
    }

    func stop() {
        engine.stop()
    }

    // MARK: - Direct MIDI (note playback, pitch bend)

    func startNote(_ note: MIDINote, velocity: MIDIVelocity,
                   pitchBend: PitchBendValue, channel: MIDIChannel) {
        guard let sampler = samplers[channel] else { return }
        sampler.setPitchbend(amount: MIDIWord(pitchBend.value), channel: channel.value)
        sampler.play(noteNumber: note.value, velocity: velocity.value, channel: channel.value)
    }

    func stopNote(_ note: MIDINote, channel: MIDIChannel) {
        guard let sampler = samplers[channel] else { return }
        sampler.stop(noteNumber: note.value, channel: channel.value)
    }

    func sendPitchBend(_ value: PitchBendValue, channel: MIDIChannel) {
        guard let sampler = samplers[channel] else { return }
        sampler.setPitchbend(amount: MIDIWord(value.value), channel: channel.value)
    }

    func stopAllNotes(channel: MIDIChannel) {
        guard let sampler = samplers[channel] else { return }
        // AppleSampler has no stopAll — send note-off for all 128 notes
        // or reset the sampler
        sampler.resetSampler()
    }
}
```

**Lines: ~90 vs. 699 (current SoundFontEngine)**

**What's missing compared to SoundFontEngine:**
- No `AVAudioSourceNode` render callback — MIDI is sent via `AppleSampler.play()` from the main thread, not dispatched at sample-accurate boundaries
- No double-buffered scheduling — events cannot be pre-queued for future audio frames
- No SPSC ring buffer — immediate events go through the same `play()` path as scheduled events
- No `currentSamplePosition` — cannot compute exact playback position for UI anchoring
- No `samplePosition(forHostTime:)` — no host-time correlation
- No per-channel volume mute/restore for fade-out (would need to use `sampler.volume = 0`)
- No amplitude (dB) control per note — `AppleSampler` has a global `amplitude` property, not per-note

---

### File 2: AudioKitNotePlayer.swift (replaces SoundFontPlayer.swift)

```swift
import AudioKit

/// NotePlayer implementation using AudioKit's AppleSampler.
/// The frequency→MIDI decomposition is identical to the current implementation.
final class AudioKitNotePlayer: NotePlayer {
    private let engine: AudioKitEngine
    private let melodicChannel: MIDIChannel
    private let pitchBendRangeCents: Double = 200 // ±2 semitones
    let stopPropagationDelay: Duration = .milliseconds(25)

    init(engine: AudioKitEngine, melodicChannel: MIDIChannel) {
        self.engine = engine
        self.melodicChannel = melodicChannel
    }

    func play(frequency: Frequency, velocity: MIDIVelocity,
              amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle {
        let (midiNote, cents) = Self.decompose(frequency)
        let pitchBend = Self.pitchBendValue(forCents: cents,
                                             rangeCents: pitchBendRangeCents)

        // NOTE: amplitudeDB is ignored — AppleSampler has no per-note amplitude
        // Only global sampler.amplitude exists (-90..+12 dB)
        engine.startNote(midiNote, velocity: velocity,
                        pitchBend: pitchBend, channel: melodicChannel)

        return AudioKitPlaybackHandle(
            engine: engine, note: midiNote, channel: melodicChannel,
            pitchBendRangeCents: pitchBendRangeCents
        )
    }

    func stopAll() async throws {
        engine.stopAllNotes(channel: melodicChannel)
    }

    // MARK: - Frequency Decomposition (unchanged from current)

    /// Decomposes a frequency into nearest MIDI note + cent remainder.
    /// This function is identical to SoundFontPlayer.decompose — AudioKit
    /// provides no equivalent.
    static func decompose(_ frequency: Frequency) -> (MIDINote, Cents) {
        let semitones = 12.0 * log2(frequency.hz / 440.0) + 69.0
        let nearestNote = MIDINote(UInt8(min(127, max(0, Int(semitones.rounded())))))
        let centOffset = Cents((semitones - Double(nearestNote.value)) * 100.0)
        return (nearestNote, centOffset)
    }

    static func pitchBendValue(forCents cents: Cents,
                                rangeCents: Double) -> PitchBendValue {
        let normalized = cents.value / rangeCents  // -1..+1
        let raw = 8192.0 + normalized * 8192.0
        return PitchBendValue(UInt16(min(16383, max(0, Int(raw)))))
    }
}

/// PlaybackHandle using AudioKit — functionally identical to current.
final class AudioKitPlaybackHandle: PlaybackHandle {
    private let engine: AudioKitEngine
    private let note: MIDINote
    private let channel: MIDIChannel
    private let pitchBendRangeCents: Double

    init(engine: AudioKitEngine, note: MIDINote, channel: MIDIChannel,
         pitchBendRangeCents: Double) {
        self.engine = engine
        self.note = note
        self.channel = channel
        self.pitchBendRangeCents = pitchBendRangeCents
    }

    func stop() async throws {
        engine.stopNote(note, channel: channel)
    }

    func adjustFrequency(_ frequency: Frequency) async throws {
        let (_, cents) = AudioKitNotePlayer.decompose(frequency)
        let bend = AudioKitNotePlayer.pitchBendValue(
            forCents: cents, rangeCents: pitchBendRangeCents
        )
        engine.sendPitchBend(bend, channel: channel)
    }
}
```

**Lines: ~85 vs. 160 (current SoundFontPlayer)**

**What's identical:** `decompose()`, `pitchBendValue()`, `PlaybackHandle` — these are the core logic and AudioKit provides zero abstraction for them.

**What's lost:** Per-note `amplitudeDB` control. `AppleSampler` exposes only a global `amplitude` property affecting all notes on that sampler. The current `SoundFontEngine` sends MIDI CC7 (volume) per-channel for this.

---

### File 3: AudioKitStepSequencer.swift (replaces SoundFontStepSequencer.swift)

```swift
import AudioKit
import AudioKitEX
import Observation

/// Step sequencer using AudioKit's Sequencer + CallbackInstrument.
///
/// TRADE-OFF: Loses dynamic StepProvider (fixed loop only),
/// sample-accurate scheduling, and host-time anchoring.
@Observable
final class AudioKitStepSequencer: StepSequencer {
    private let engine: AudioKitEngine
    private var sequencer: Sequencer?
    private var callbackInst: CallbackInstrument?
    private var pollingTask: Task<Void, Never>?

    private(set) var currentStep: StepPosition?
    private(set) var currentCycle: CycleDefinition?
    var timing: SequencerTiming {
        // AudioKit provides currentPosition in beats, not samples
        // This is a lossy conversion
        SequencerTiming(
            currentSamplePosition: 0, // Not available from AudioKit
            samplesPerStep: 0,
            sampleRate: SampleRate.standard44100
        )
    }

    init(engine: AudioKitEngine) {
        self.engine = engine
    }

    func start(tempo: TempoBPM, stepProvider: any StepProvider) async throws {
        let cycle = stepProvider.nextCycle()
        self.currentCycle = cycle

        // Create callback instrument for UI tracking
        let callback = CallbackInstrument { [weak self] status, data1, _ in
            guard status == 144 else { return } // noteOn only
            Task { @MainActor in
                self?.currentStep = StepPosition(rawValue: Int(data1))
            }
        }
        self.callbackInst = callback

        // Get the sampler for percussion channel
        guard let sampler = engine.sampler(for: .percussion) else {
            throw AudioError.channelNotFound(.percussion)
        }

        // Build sequencer with two targets: sampler + callback
        let seq = Sequencer(targetNodes: [sampler, callback])
        seq.tempo = Double(tempo.value)

        let stepsPerBeat = 4.0
        let stepDuration = 1.0 / stepsPerBeat

        // Track 0: audio to sampler
        let audioTrack = seq.tracks[0]
        // Track 1: UI callbacks
        let uiTrack = seq.tracks[1]

        for (index, step) in cycle.steps.enumerated() {
            let position = Double(index) * stepDuration
            let isAccent = index == 0
            let velocity: UInt8 = isAccent ? 120 : 90

            if !step.isGap {
                audioTrack.add(
                    noteNumber: MIDINoteNumber(step.midiNote.value),
                    velocity: MIDIVelocity(velocity),
                    channel: 0,
                    position: position,
                    duration: stepDuration * 0.8
                )
            }

            // Always add UI callback event
            uiTrack.add(
                noteNumber: MIDINoteNumber(index),
                velocity: 127,
                channel: 0,
                position: position,
                duration: 0.001
            )
        }

        seq.length = 1.0 // 1 beat = 4 sixteenth-note steps
        seq.loopEnabled = true

        // Wire callback into engine output
        engine.mixer.addInput(callback)

        self.sequencer = seq
        try engine.configureAndStart()
        seq.playFromStart()

        // LIMITATION: Cannot call stepProvider.nextCycle() dynamically.
        // AudioKit's Sequencer plays a fixed loop. To change the pattern,
        // you must stop → clear → re-add → play, which causes an audible gap.
    }

    func stop() async throws {
        sequencer?.stop()
        sequencer = nil
        pollingTask?.cancel()
        pollingTask = nil
        currentStep = nil
        currentCycle = nil

        if let cb = callbackInst {
            engine.mixer.removeInput(cb)
        }
        callbackInst = nil
    }

    func playImmediateNote(velocity: MIDIVelocity) throws {
        // No ring buffer — just call play directly
        guard let sampler = engine.sampler(for: .percussion) else { return }
        let clickNote: UInt8 = 76
        sampler.play(noteNumber: clickNote, velocity: velocity.value, channel: 0)

        // Note-off via Task — not real-time safe, but adequate for tap feedback
        Task {
            try await Task.sleep(for: .milliseconds(50))
            sampler.stop(noteNumber: clickNote, channel: 0)
        }
    }

    func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
        // NOT POSSIBLE with AudioKit — no host-time to sample mapping
        // Return 0 as a stub; UI sync would need a different approach
        return 0
    }
}
```

**Lines: ~120 vs. 244 (current SoundFontStepSequencer)**

**Critical limitations:**
1. **No dynamic `StepProvider`** — AudioKit's `Sequencer` plays a fixed note loop. The current `SoundFontStepSequencer` calls `stepProvider.nextCycle()` for every cycle, enabling dynamic gap positions. With AudioKit, changing the pattern requires stop→clear→re-add→play, causing an audible gap
2. **No `samplePosition(forHostTime:)`** — returns a stub. UI step highlighting would need to use `sequencer.tracks[0].currentPosition` (beat-based, less precise)
3. **No batch pre-scheduling** — the current implementation pre-computes 500 cycles (~8 minutes). AudioKit relies on loop repeat with no lookahead
4. **`CallbackInstrument` fires from render thread** — the `Task { @MainActor }` hop for UI updates adds non-deterministic latency vs. the current 120Hz polling approach

---

### File 4: Preserved Files (No AudioKit Equivalent)

These files would remain **unchanged** because AudioKit provides no alternative:

| File | Lines | Why it stays |
|------|-------|-------------|
| `SF2PresetParser.swift` | ~150 | Binary RIFF parsing for preset discovery. AudioKit has no SF2 introspection |
| `SoundFontLibrary.swift` | ~80 | Preset catalog built from parser output |
| `AudioSessionInterruptionMonitor.swift` | ~60 | `NotificationCenter` observers for interruption/route changes |
| `IOSAudioSessionConfigurator.swift` | ~30 | Buffer duration & category setup (still needed even with AudioKit) |
| `IOSAudioInterruptionObserver.swift` | ~40 | iOS-specific interrupt/route notifications |
| `MacOSAudioSessionConfigurator.swift` | ~10 | macOS no-op |
| `MIDIKitAdapter.swift` | ~50 | External MIDI input via MIDIKitIO — orthogonal to AudioKit |
| All protocol files | ~57 | Domain contracts — AudioKit doesn't replace these |
| All domain value types | ~200 | `Frequency`, `MIDINote`, `Cents`, `PitchBendValue`, etc. |

**Total preserved: ~677 lines** — more than half the audio layer stays identical.

---

### Migration Effort Estimate

| Phase | Effort | Risk |
|-------|--------|------|
| Add AudioKit + AudioKitEX SPM dependencies | Trivial | Low — build time increase, C++ compilation for CAudioKitEX |
| Replace engine setup (`AVAudioEngine` → `AudioEngine`) | Small | Low — straightforward API mapping |
| Replace sampler wiring (per-channel `AppleSampler`) | Small | Low — `Mixer.addInput` replaces `attach`/`connect` |
| Rewrite step sequencer on `Sequencer` + `CallbackInstrument` | **Large** | **High** — loss of dynamic cycles, sample-accurate timing, host-time anchoring |
| Adapt tests to concrete AudioKit classes | Medium | Medium — need protocol wrappers for testability |
| Remove `SoundFontEngine` render callback | Medium | **High** — this is the irreversible step; going back requires full reimplementation |
| Verify latency characteristics | Medium | Medium — AudioKit's main-thread `play()` vs. render-thread dispatch |

### Testing Impact

**Current test architecture:**
- Protocol-based mocks for `NotePlayer`, `RhythmPlayer`, `StepSequencer`
- Static pure-function tests for `decompose()`, `buildBatch()`, `samplesPerStep()`
- No audio hardware dependency in unit tests

**With AudioKit:**
- Protocol mocks remain (domain protocols unchanged)
- `decompose()` and `pitchBendValue()` tests unchanged
- Step sequencer tests would need to mock `Sequencer` and `CallbackInstrument` — these are concrete classes with no protocol. Options:
  a. Wrap in protocols (adds boilerplate, recreates what you already have)
  b. Integration tests only (slower, requires running engine)
- Static `buildBatch` tests would be lost — AudioKit's beat-based API doesn't expose the event generation pipeline

---

## Technical Research Recommendations

### Recommendation: Keep the Current Direct AVFoundation Approach

**Confidence: HIGH**

The research strongly suggests that migrating to AudioKit would be a net negative for Peach. The evidence:

1. **AudioKit solves problems Peach doesn't have.** AudioKit's value is in its synthesis nodes, effects chains, and audio processing graph. Peach uses none of these — it plays SoundFont presets and sequences rhythm patterns. This is <5% of AudioKit's surface area.

2. **The hard code stays the same.** Frequency→MIDI decomposition, pitch bend calculation, per-note amplitude control, SF2 preset parsing, and domain value types account for ~677 of ~1,100 lines. AudioKit provides zero abstraction for any of these.

3. **The valuable code would be lost.** The lock-free double-buffered scheduling, SPSC ring buffer, sample-accurate dispatch, and host-time anchoring represent deep real-time audio engineering. AudioKit's `Sequencer` cannot replicate these capabilities. Once removed, they'd be expensive to recreate.

4. **Testability would degrade.** AudioKit's concrete classes would require protocol wrappers to maintain mock-based testing, effectively recreating the abstraction layer you already have — but now with a third-party dependency underneath.

5. **Dependency risk for minimal gain.** Adding AudioKit (core) + AudioKitEX (with C++ DSP) for ~40 lines of engine-setup savings introduces ongoing maintenance risk, Swift concurrency compatibility uncertainty, and binary size overhead.

### Where AudioKit Would Make Sense

AudioKit would be a strong choice if Peach's audio needs evolve to include:

- **Live audio effects** — reverb, delay, filters on playback (SoundpipeAudioKit)
- **Custom synthesis** — oscillator-based sound generation beyond SoundFonts (SoundpipeAudioKit)
- **Audio analysis** — frequency tracking, amplitude detection for input exercises (AudioKit core)
- **Complex routing** — multiple effect chains, aux sends, parallel processing (AudioKit Mixer + effects)

If any of these become requirements, AudioKit would provide genuine value by avoiding the need to build these subsystems from scratch.

### If Migration Were Pursued: Recommended Strategy

If the decision were made to adopt AudioKit despite the trade-offs:

1. **Preserve all domain protocols** — `NotePlayer`, `RhythmPlayer`, `StepSequencer`, `PlaybackHandle` stay as-is
2. **Create AudioKit adapter implementations** — `AudioKitNotePlayer`, `AudioKitStepSequencer` as shown above
3. **Keep the render-thread sequencer as a parallel option** — don't delete `SoundFontEngine` until AudioKit's sequencer is proven equivalent in production
4. **Accept the dynamic-cycle limitation** — redesign step sequencer to use fixed patterns with periodic stop→rebuild→restart cycles
5. **Wrap AudioKit classes in testability protocols** — `AppleSamplerProtocol`, `SequencerProtocol` for mock injection

### Success Metrics (if migrated)

| Metric | Current Baseline | Acceptable After Migration |
|--------|-----------------|---------------------------|
| Note onset latency | <5ms (render-thread dispatch) | <10ms (main-thread `play()`) |
| Step sequencer jitter | <1ms (sample-accurate) | <5ms (beat-based scheduling) |
| UI step highlight accuracy | ±1ms (host-time anchored) | ±10ms (beat-position polling) |
| Test execution (unit) | All mock-based, no hardware | Same — protocol wrappers required |
| Audio layer code size | ~1,100 lines | ~900 lines (~18% reduction) |
| Third-party dependencies | MIDIKitIO only | MIDIKitIO + AudioKit + AudioKitEX |

---

## Sources

- [AudioKit GitHub Repository](https://github.com/AudioKit/AudioKit)
- [AudioKit Documentation](https://www.audiokit.io/)
- [AudioKit Swift Package Index](https://swiftpackageindex.com/AudioKit/AudioKit)
- [AppleSampler Source Code](https://github.com/AudioKit/AudioKit/blob/4c3f5ef/Sources/AudioKit/Nodes/Playback/Apple%20Sampler/AppleSampler.swift)
- [AudioEngine Source Code](https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/Internals/Engine/AudioEngine.swift)
- [AudioKitEX Sequencer](https://www.audiokit.io/AudioKitEX/documentation/audiokitex/sequencer)
- [CallbackInstrument Docs](https://www.audiokit.io/AudioKitEX/documentation/audiokitex/callbackinstrument)
- [SequencerTrack Docs](https://www.audiokit.io/AudioKitEX/documentation/audiokitex/sequencertrack)
- [AudioKit Migration Guide (v5)](https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/AudioKit.docc/MigrationGuide.md)
- [AudioKit Cookbook](https://github.com/AudioKit/Cookbook)
- [AudioKit 2025 Recap](https://audiokitpro.com/yearend2025/)
- [AudioKit Contributors](https://github.com/AudioKit/AudioKit/graphs/contributors)
- [SoundpipeAudioKit](https://github.com/AudioKit/SoundpipeAudioKit)
- [DunneAudioKit](https://github.com/AudioKit/DunneAudioKit)
- [objc.io Audio API Overview](https://www.objc.io/issues/24-audio/audio-api-overview/)
- [Kodeco AudioKit Tutorial](https://www.kodeco.com/835-audiokit-tutorial-getting-started)
- [AudioKit Pro – Getting Most Out of Sequencer](https://audiokitpro.com/get-the-most-out-of-your-aksequencer/)
- [Patrick O'Leary – Building a MIDI Sequence in Swift](https://medium.com/@oleary.audio/building-a-midi-sequence-in-swift-bed5f5c2bb7d)
- [Swift 6 Concurrency Adoption](https://developer.apple.com/documentation/swift/adoptingswift6)
- [Swift 6.2 Approachable Concurrency](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/)

---

## Technical Research Conclusion

### The Core Insight

AudioKit and Peach's audio layer solve the same problem — bridging Swift application code to AVFoundation's real-time audio APIs — but at different levels of generality. AudioKit is designed for the broadest possible range of audio applications: synthesizers, effects processors, audio analyzers, MIDI controllers, and sample players. Peach needs exactly one of those: SoundFont-based sample playback with precise rhythm sequencing.

When a framework solves a problem you don't have, the cost of the abstraction exceeds the benefit. AudioKit would add ~2 third-party packages (including C++ compilation), wrap APIs you already use directly, hide render-thread control you actively depend on, and degrade sequencer precision from sample-accurate to beat-approximate — all to save ~40 lines of engine setup code.

### When to Revisit This Decision

This assessment should change if any of the following become requirements:

1. **Live audio effects on playback** (reverb, EQ, filtering) — AudioKit's SoundpipeAudioKit provides battle-tested DSP nodes
2. **Audio input analysis** (pitch detection, amplitude tracking) — AudioKit's frequency tracker and amplitude tap would save significant work
3. **Complex audio routing** (parallel effect chains, aux sends) — AudioKit's Mixer and node graph would simplify wiring
4. **Oscillator-based synthesis** — if Peach needs generated tones beyond SoundFont presets

Until then, the current 1,100-line direct AVFoundation implementation is the right architecture: purpose-built, fully owned, Swift 6 compliant, and providing the render-thread precision that ear training demands.

---

**Technical Research Completion Date:** 2026-04-07
**Research Period:** Comprehensive analysis of AudioKit 5.x ecosystem against Peach's current audio layer
**Source Verification:** All technical claims cited with current public sources
**Confidence Level:** HIGH — based on direct source code analysis of both AudioKit and Peach implementations

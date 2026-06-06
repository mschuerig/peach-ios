# AVAudioEngine

`AVAudioEngine` is the modern Swift/Obj-C entry point to Apple's audio graph. It replaces `AUGraph` (deprecated since macOS 10.14 / iOS 12, WWDC19 Session 508). New code should use it.

## Mental model

`AVAudioEngine` owns a **directed graph of `AVAudioNode`s** connected by typed **buses** that carry a specific `AVAudioFormat`.

- You **`attach(node)`** to give a node lifetime and engine context.
- You **`connect(source, to: dest, format: fmt)`** to wire buses.
- Three nodes exist on demand: `inputNode` (mic / first AU input), `outputNode` (DAC / first AU output), `mainMixerNode` (lazily connected to `outputNode` the first time you touch it).
- The graph is **pull-driven** from the output node: in real-time mode the OS audio I/O thread asks `outputNode` for N frames; the request recursively pulls upstream until a source (player, sampler, source node, input node) produces samples.
- There is no Swift "tick". Code runs only when the audio thread pulls, when a tap fires, or when you explicitly schedule a buffer/note.

## Nodes — one paragraph each

- **`AVAudioInputNode`** — captures mic / aggregate device input. On iOS requires an active `AVAudioSession` with a record-capable category and microphone permission. Format is fixed by hardware; install taps to record. macOS uses the default input device unless aggregated.
- **`AVAudioOutputNode`** — terminal sink to hardware. Its `outputFormat(forBus: 0)` is the device's hardware format; do not try to change it.
- **`AVAudioMixerNode` / `mainMixerNode`** — multi-input → single-output mixer with per-bus volume/pan and automatic sample-rate conversion. Each input bus may have a *different* format; the mixer SRCs as needed but at CPU cost.
- **`AVAudioPlayerNode`** — schedules `AVAudioPCMBuffer`s, `AVAudioFile`s, or file segments for playback. Sample-accurate via `AVAudioTime`. Common gotcha: `play()` is a no-op if the engine isn't running; scheduling before `play()` is fine.
- **`AVAudioUnitSampler`** — SoundFont / DLS / EXS / Aiff-sample-driven sampler. `startNote(_:withVelocity:onChannel:)` / `stopNote` / `sendController` are MIDI-thread-safe. Gotcha: `loadInstrument` is synchronous and can take hundreds of ms; preload off the audio path. Voice/CC behaviour is largely undocumented; test empirically.
- **`AVAudioUnitEQ`** — parametric EQ with N bands; mutate band params from any thread.
- **`AVAudioUnitReverb`** — preset reverb (`loadFactoryPreset`) with `wetDryMix`.
- **`AVAudioUnitTimePitch`** — independent time stretch + pitch shift. CPU-heavy; adds latency.
- **`AVAudioUnitDelay`** — feedback delay with `delayTime`, `feedback`, `lowPassCutoff`, `wetDryMix`.
- **`AVAudioUnitDistortion`** — preset distortion.
- **`AVAudioSourceNode`** — user-supplied render-block source. See "Source / sink nodes" below.
- **`AVAudioSinkNode`** — user-supplied receiver block. Only connectable *from* `inputNode`.
- **`AVAudioUnit*` (third-party)** — `AVAudioUnit` is the base class; wraps `AUAudioUnit`. Use to connect third-party AUv3s. See `audio-units.md`.

## Source / sink nodes (your render code)

`AVAudioSourceNode(format:renderBlock:)` (iOS 13+ / macOS 10.15+). The block runs on the audio render thread:

```swift
let sourceNode = AVAudioSourceNode(format: format) {
    isSilence, timestamp, frameCount, outputData -> OSStatus in
    // Fill outputData. RT-safe only.
    isSilence.pointee = false
    return noErr
}
```

Set `isSilence.pointee = true` if you produce silence (lets the engine skip downstream work). Use lock-free SPSC to feed data in; the four cardinal rules apply.

`AVAudioSinkNode(receiverBlock:)` (iOS 13+ / macOS 10.15+). Only connectable *from* `inputNode`. Same real-time contract. Preferred over taps for low-latency input processing because it runs in the I/O cycle, not on a separate queue.

## RT-safety summary by API

Safe to call **from the audio render thread** or a MIDI callback:

- `AVAudioPlayerNode.scheduleBuffer/scheduleFile/scheduleSegment` — documented thread-safe; uses an internal lock-free queue.
- `AVAudioUnitSampler.startNote/stopNote/sendController/sendMIDIEvent` — documented thread-safe.
- `AUParameter.value =` on `AVAudioUnit*` parameters — atomic; ramps applied on the audio thread.

**Never** call from a render block / tap / receiver block: `engine.attach / detach / connect / disconnect`, `engine.start / stop / pause`, `installTap / removeTap`, `loadInstrument`, Swift `print`, `os_log` with formatted args, `DispatchQueue.sync`, `NSLock`, `Mutex`, ObjC `+alloc` / retain paths, Swift array growth or string allocation, `@MainActor` hops, `await`.

Taps run on a dedicated high-priority queue (not the audio render thread), and are not sample-accurate — they have latency. They should still avoid heavy work and locks shared with the render thread.

## Lifecycle

- `prepare()` — allocates resources, validates the graph. Optional; `start()` calls it implicitly. Use to pre-warm.
- `start() throws` — begins pulling on output. Required before audible output. Players' `play()` is a no-op until the engine runs.
- `pause()` — stops I/O but **retains** scheduled state and connections; cheap to resume with `start()`.
- `stop()` — stops I/O. **Does not flush** player schedules or sequencer position; **does not detach** nodes.
- `reset()` — clears DSP state (delay lines, reverb tails) on every attached node; player schedule queues are cleared.

**`stop()` does not flush.** Call `playerNode.stop()` (clears queue) before `engine.stop()` if you want a clean restart.

## Configuration change

When the I/O unit observes a hardware sample-rate or channel-count change (route change, AirPods connect, AVAudioSession activation), the engine **stops itself and uninitializes**, then posts `AVAudioEngineConfigurationChangeNotification`. Handler must:

1. Read the current `inputNode.inputFormat(forBus: 0)` / `outputNode.outputFormat(forBus: 0)`.
2. Reconnect any explicit formats that depended on the hardware format.
3. Call `start()` again.

The notification can fire on a background thread; bounce to main before mutating the engine.

## Format negotiation traps

- **Standard format** — `AVAudioFormat(standardFormatWithSampleRate:channels:)` → 32-bit float, **deinterleaved**, native endian. The canonical internal format; most nodes prefer it.
- **Hardware (canonical) format** — `inputNode` / `outputNode` use whatever the session negotiated. Commonly 48 kHz on modern iPhones, 44.1 kHz with some BT codecs, 16 kHz mono on a Bluetooth HFP mic. **Always read `node.outputFormat(forBus: 0)` after the session is active — never hardcode.**
- **`connect(_:to:format:nil)`** lets the engine pick. Explicit format is required when bridging mismatched SR/channel counts; the mixer SRCs at the boundary it owns.
- **Input format = output format on every node** except `AVAudioMixerNode` (sums mismatched inputs) and `AVAudioUnitTimePitch` (rate change). Wrong format throws on `connect` or `start`.
- **Channel layouts beyond stereo** require `AVAudioChannelLayout`. Constructing a format with just `channels: 6` produces a discrete layout that some AUs reject.

## AVAudioSequencer

Modern MIDI-sequence playback inside `AVAudioEngine`. Init with `AVAudioSequencer(audioEngine: engine)` — it auto-attaches. Load with `load(from: url, options: [.smfChannelsToTracks])`. Iterate `seq.tracks` (`AVMusicTrack`) and set `track.destinationAudioUnit = sampler` (or `destinationMIDIEndpoint` for external). Then `try seq.start()` after `engine.start()`. Properties: `currentPositionInBeats`, `currentPositionInSeconds`, `rate`, `isPlaying`.

It is the modern Obj-C/Swift wrapper over the AudioToolbox `MusicSequence`/`MusicPlayer` pair; tempo track lives at `track[0]` per SMF convention.

The sequencer does **not** mix audio itself; it generates MIDI events that drive your destination audio units inside the engine. Detail in `midi.md`.

## Offline / manual rendering

`engine.enableManualRenderingMode(.offline, format: outFormat, maximumFrameCount: 4096)` — engine must be stopped first. Then `start()`, schedule sources, and pull frames:

```swift
let status = try engine.renderOffline(frameCount, to: outputBuffer)
```

Loop until your source is exhausted and write to `AVAudioFile`. Use `.realtime` mode to test code that respects realtime constraints without the device. Disable with `disableManualRenderingMode()`. This is the supported path for unit tests (no audio hardware), export-to-file, and CI; taps and `AVAudioSession` are bypassed.

## Common pitfalls

- **`engine.stop()` doesn't flush** — see Lifecycle above.
- **Reconnecting nodes at runtime** while running is allowed but causes a brief glitch and may throw if formats are incompatible; prefer `pause()` → reconfigure → `start()`. Disconnects on the active output bus have crashed on older OS versions.
- **Mutating the graph from background threads** — `attach / detach / connect / disconnect` are documented as safe from any thread, but only one such call may be in flight at a time. Serialize through a dedicated queue or `@MainActor`.
- **`mainMixerNode` lazy connect** — touching it auto-connects to `outputNode` with the hardware format; if you intended a custom topology, build it before reading `mainMixerNode`.
- **Player completion handlers** run on an internal queue, not main. Hop explicitly if you need UI work.
- **AVAudioSession interruptions silently stop the engine.** Observe `AVAudioSession.interruptionNotification` and restart on `.ended` with `.shouldResume`. See `avaudiosession.md`.
- **Sampler `loadInstrument` is blocking** and may take hundreds of ms — never on the main thread during UI, never on the audio thread.
- **Configuration change notification can fire on a background thread** — capture state and bounce to main before touching the engine.

## Authoritative sources

- AVAudioEngine — https://developer.apple.com/documentation/avfaudio/avaudioengine
- AVAudioNode — https://developer.apple.com/documentation/avfaudio/avaudionode
- AVAudioPlayerNode — https://developer.apple.com/documentation/avfaudio/avaudioplayernode
- AVAudioUnitSampler — https://developer.apple.com/documentation/avfaudio/avaudiounitsampler
- AVAudioSourceNode — https://developer.apple.com/documentation/avfaudio/avaudiosourcenode
- AVAudioSinkNode — https://developer.apple.com/documentation/avfaudio/avaudiosinknode
- AVAudioSequencer — https://developer.apple.com/documentation/avfaudio/avaudiosequencer
- AVAudioFormat — https://developer.apple.com/documentation/avfaudio/avaudioformat
- AVAudioPCMBuffer — https://developer.apple.com/documentation/avfaudio/avaudiopcmbuffer
- AVAudioConverter — https://developer.apple.com/documentation/avfaudio/avaudioconverter
- `enableManualRenderingMode` — https://developer.apple.com/documentation/avfaudio/avaudioengine/enablemanualrenderingmode(_:format:maximumframecount:)
- Configuration change notification — https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
- WWDC14 Session 502 — "AVAudioEngine in Practice" — foundational tour.
- WWDC15 Session 507 — "What's New in Core Audio" — manual rendering origins.
- WWDC19 Session 510 — "What's New in AVAudioEngine" — `AVAudioSourceNode` / `AVAudioSinkNode` introduction.
- WWDC20 Session 10224 — "Meet Audio Workgroups" — coordinated audio-thread scheduling.

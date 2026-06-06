# Audio Units (AUv2 / AUv3) — Hosting and Writing

Audio Units (AUs) are Apple's plugin format for real-time audio processing on macOS / iOS / tvOS / visionOS.

## Architecture

- **AUv2** — legacy C-based API (`AudioComponent`, function pointers, in-process). Still loaded by macOS DAWs (Logic, Pro Tools via wrappers, MainStage) for compatibility. **Not permitted on iOS.** Apple maintains it for compat hosting; new code targets AUv3.
- **AUv3** — modern App Extension model. Sandboxed `.appex` bundle hosting an `AUAudioUnit` subclass. The only modern path. Runs on iOS / iPadOS / macOS / tvOS / visionOS. On macOS, can opt into in-process loading via `kAudioComponentFlag_CanLoadInProcess`.
- **`AUAudioUnit`** — the Obj-C / Swift base class. Identity is an `AudioComponentDescription { componentType, componentSubType, componentManufacturer, componentFlags, componentFlagsMask }`.
- **`AVAudioUnit`** — `AVAudioNode` subclass that wraps an `AUAudioUnit` (`.auAudioUnit` property) and lets `AVAudioEngine` `attach` / `connect` it. Subclasses: `AVAudioUnitEffect`, `AVAudioUnitMIDIInstrument`, `AVAudioUnitSampler`, `AVAudioUnitTimeEffect`.

Component types:

| `componentType` | Meaning | Examples |
|---|---|---|
| `kAudioUnitType_Effect` (`aufx`) | Audio-in → audio-out | EQ, reverb, compressor |
| `kAudioUnitType_MusicEffect` (`aumf`) | Audio-in + MIDI-in → audio-out | MIDI-controlled effects |
| `kAudioUnitType_MusicDevice` (`aumu`) | MIDI-in → audio-out | Synthesizer, sampler |
| `kAudioUnitType_Generator` (`augn`) | No input → audio-out | Tone generator, file player |
| `kAudioUnitType_MIDIProcessor` (`aumi`) | MIDI-in → MIDI-out | Arpeggiator, MIDI FX |
| `kAudioUnitType_Mixer` (`aumx`) | Multiple audio-in → audio-out | Mixers |

## Hosting Audio Units

**Discovery.** Use `AVAudioUnitComponentManager` to find installed components:

```swift
let desc = AudioComponentDescription(
    componentType: kAudioUnitType_Effect, componentSubType: 0,
    componentManufacturer: 0, componentFlags: 0, componentFlagsMask: 0)
let comps = AVAudioUnitComponentManager.shared().components(matching: desc)
// .name, .manufacturerName, .versionString, .iconImage, .hasMIDIInput, ...
```

A wildcard description (zeros) enumerates all of a type; filter the results.

**Instantiation** (async; required for AUv3 sandbox):

```swift
AVAudioUnit.instantiate(with: desc, options: []) { unit, error in
    guard let unit else { return }
    engine.attach(unit)
    engine.connect(prev, to: unit, format: fmt)
    engine.connect(unit, to: engine.mainMixerNode, format: fmt)
}
```

Or directly `AUAudioUnit.instantiate(with: desc) { au, err in … }`.

**Parameters.** Walk `auUnit.parameterTree?.allParameters`. Read/write `param.value`. Observe via `parameterTree.token(byAddingParameterObserver:)` (UI side) or `token(byAddingParameterRecordingObserver:)` (automation capture). Schedule ramped automation via `auUnit.scheduleParameterBlock`.

**Presets.** `auUnit.factoryPresets` for built-ins (read-only); assign `auUnit.currentPreset = preset`. User presets via `saveUserPreset(_:)` / `presetState(for:)` / `userPresets`. Opaque full state via `fullState` (Dictionary) — what you persist to keep an arbitrary plug-in's state.

**UI.** Request the extension's view controller asynchronously:

```swift
auUnit.requestViewController { vc in /* AUViewController? */ }
```

Embed `vc.view` in your host UI (sandbox-bridged remote view on iOS, XPC on macOS).

## Writing an AUv3 — minimum viable

**Project setup.** Add an **Audio Unit Extension** target (Xcode template). The extension `Info.plist`:

```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key><string>com.apple.AudioUnit-UI</string>
  <key>NSExtensionPrincipalClass</key><string>$(PRODUCT_MODULE_NAME).MyAUViewController</string>
  <key>NSExtensionAttributes</key>
  <dict>
    <key>AudioComponents</key>
    <array><dict>
      <key>type</key><string>aufx</string>
      <key>subtype</key><string>Xmpl</string>
      <key>manufacturer</key><string>ACME</string>
      <key>name</key><string>ACME: Example</string>
      <key>factoryFunction</key><string>$(PRODUCT_MODULE_NAME).MyAUViewController</string>
      <key>sandboxSafe</key><true/>
      <key>tags</key><array><string>Effects</string></array>
      <key>version</key><integer>65536</integer>
    </dict></array>
  </dict>
</dict>
```

Subclass `AUAudioUnit`; override `init(componentDescription:options:)`, configure `inputBusses` / `outputBusses` (`AUAudioUnitBusArray` of `AUAudioUnitBus` with `AVAudioFormat`).

**Resource lifecycle.** Host calls `allocateRenderResources()` after format negotiation — allocate DSP buffers here, release in `deallocateRenderResources()`. Respect `maximumFramesToRender` (host sets before `allocate`); render block must handle up to that.

**Render contract.** Override the `internalRenderBlock` *getter* and return an `AUInternalRenderBlock`:

```
^AUAudioUnitStatus(AudioUnitRenderActionFlags *flags,
                   const AudioTimeStamp *timestamp,
                   AVAudioFrameCount frameCount,
                   NSInteger outputBusNumber,
                   AudioBufferList *outputData,
                   const AURenderEvent *realtimeEventListHead,
                   AURenderPullInputBlock pullInputBlock)
```

Inside the block: pull upstream via `pullInputBlock`, walk `realtimeEventListHead` (parameter ramps + MIDI events) in sample order, write output samples. The render block runs on a high-priority audio I/O thread; the four cardinal rules apply (no allocation, no locks, no Obj-C/Swift runtime, no I/O).

**Critical:** capture only an immutable pointer to a C++ / struct DSP kernel in the render block. **Never capture `self`** — that would imply ARC retain/release on the render thread.

**Parameters.** Build `AUParameterTree.createTree(withChildren:)` from `AUParameterTree.createParameter(...)`. Set:

- `parameterTree.implementorValueObserver` — non-RT setter; push to a lock-free SPSC.
- `parameterTree.implementorValueProvider` — read current value.
- `implementorStringFromValueCallback` / `implementorValueFromStringCallback` — UI formatting.

**View controller.** Subclass `AUViewController` (AudioToolbox; UIKit/AppKit-friendly). Implement `createAudioUnit(with:) throws -> AUAudioUnit`. The host loads your view through XPC.

**Factory presets.** Return `[AUAudioUnitPreset]` from `factoryPresets`. Respond to `currentPreset` setter by hydrating parameter values from your serialized state.

## RT safety inside the render block

The four cardinal rules (see `realtime-rules.md`) apply directly:

1. No locks.
2. No allocation (no `malloc`, no `new`, no ARC retain/release on non-immortal references).
3. No Obj-C/Swift dynamic dispatch.
4. No syscalls or unbounded waits.

**Parameter flush.** UI thread writes proposed values into an atomic slot or SPSC ring; at the top of each render call, snapshot (relaxed atomic load) and apply ramps inline using the `AUParameterEvent` list the host already supplies.

**Control → render messaging.** Single-producer/single-consumer lock-free ring buffer for anything larger than a parameter scalar. See `inter-thread-patterns.md`.

## MIDI in / out

- **MIDI in (host → AU).** Host calls `auUnit.scheduleMIDIEventBlock(timestamp, cable, length, bytes)` for MIDI 1.0, or `auUnit.scheduleMIDIEventListBlock` for MIDI 2.0 / UMP. Inside the render block, MIDI arrives in the `AURenderEvent` linked list (`AURenderEventMIDI`, `AURenderEventMIDIEventList`).
- **MIDI out (AU → host).** Set `auUnit.midiOutputNames` (advertise ports) and call the host-provided `MIDIOutputEventBlock` (MIDI 1.0) or `MIDIOutputEventListBlock` (UMP) from your render block.
- **Opt into MIDI 2.0** by setting `audioUnitMIDIProtocol = kMIDIProtocol_2_0`.

AUv3 of type `aumi` (MIDI processor) produces MIDI only — no audio output.

Detail in `midi.md`.

## Common traps

- **Sandbox.** Extensions have no network or arbitrary file access by default. Share data with the container app through an App Group + `UserDefaults(suiteName:)` or a shared container URL.
- **Audio session (iOS).** The *host* owns `AVAudioSession`; the extension inherits it. Don't try to set the category. Handle interruptions in your host app if you also have one.
- **State changes.** `allocateRenderResources` can be called repeatedly on sample-rate or maximumFrames changes. Be idempotent.
- **`auval` / `auvaltool`.** macOS validator: `auval -v aufx Xmpl ACME`. **Failing `auval` means Logic, GarageBand, and MainStage will refuse to load the unit.** Run after every signing or Info.plist change. Tests cover format negotiation, parameter ranges, render correctness, MIDI, state save/restore, offline rendering.
- **DAW quirks:**
  - **GarageBand / Logic** require a 60×60 icon and accurate `tags`.
  - **AUM / Cubasis / Loopy Pro** (iOS) expect `sandboxSafe=true` and async instantiation.
  - **Cubase / Nuendo** (macOS) often need an in-process AUv2 wrapper through Steinberg's bridge.
  - **Pro Tools** uses AAX only — no AU support.
- **`MaximumFramesPerSlice`** must be set before `AudioUnitInitialize` (AUv2) or your render block can be torn down when the host requests a larger slice (e.g., screen-locked iOS background audio).
- **Never reference `self` in the render block.** Idiomatic pattern: C++ kernel struct with raw pointer captured into the block.

## Hosting Audio Unit Extensions vs in-process

On macOS, AUv3 can run in the host's process (`kAudioComponentFlag_CanLoadInProcess` + `RequiresAsyncInstantiation`). Logic and Final Cut prefer in-process. iOS always uses out-of-process XPC.

In-process is faster (no XPC marshalling), but a crash brings down the host. Out-of-process is isolated but adds latency for parameter automation and view updates.

## Cross-platform note

If shipping cross-platform plugins (VST3 / AAX / CLAP / LV2 in addition to AU), JUCE is the de-facto framework. Its `AudioProcessor::processBlock` contract maps onto AUv3's `internalRenderBlock` directly. See `cross-platform.md`.

## Authoritative sources

- AUAudioUnit — https://developer.apple.com/documentation/audiotoolbox/auaudiounit
- internalRenderBlock — https://developer.apple.com/documentation/audiotoolbox/auaudiounit/internalrenderblock
- AUParameterTree — https://developer.apple.com/documentation/audiotoolbox/auparametertree
- AVAudioUnit — https://developer.apple.com/documentation/avfaudio/avaudiounit
- AVAudioUnitComponentManager — https://developer.apple.com/documentation/avfaudio/avaudiounitcomponentmanager
- NSExtensionAttributes — https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSExtension/NSExtensionAttributes
- Hosting AUv2 (compat) — https://developer.apple.com/documentation/audiotoolbox/hosting-audio-unit-extensions-using-the-auv2-api
- WWDC sessions: "Bring your App to Life with AU Extensions" (WWDC21 #10036), "Creating Custom Audio Effects" (WWDC17 #501), "Audio Unit Extensions" (WWDC15 #508), "What's New in Audio" (WWDC22 #10058)
- Apple samples — *AUv3FilterDemo*, *AUv3InstrumentDemo* on developer.apple.com sample code
- Chris Adamson — "Brain Dump: v3 Audio Units" (subfurther.com)
- Music Hackspace AUv3 courses (musichackspace.org)
- AudioKit AUv3 MIDI tutorial (audiokitpro.com)

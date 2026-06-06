# Spatial / 3D Audio

Apple offers two spatial-audio stacks: `AVAudioEnvironmentNode` (inside `AVAudioEngine`) and **PHASE** (a standalone scene-graph engine, iOS 15+ / macOS 12+).

## Mental model

A spatial mix consists of:

- **Sources** with 3D positions.
- A **listener** with a position and orientation (yaw/pitch/roll or forward/up vectors).
- An **environment** that contributes distance attenuation, occlusion, and reverb.

The renderer convolves source signals with HRTFs (Head-Related Transfer Functions) based on the relative geometry. Headphones (especially AirPods) get binaural output; speakers get amplitude panning across channels.

Choose `AVAudioEnvironmentNode` for point-source 3D panning inside an existing `AVAudioEngine` graph. Choose PHASE for geometry-aware audio with occluders, materials, and event-driven assets.

## AVAudioEnvironmentNode

`AVAudioEnvironmentNode` (AVFAudio, iOS 8 / macOS 10.10+) is an `AVAudioMixing` + `AVAudioNode` that simulates 3D positional audio.

```swift
engine.attach(environment)
engine.connect(player, to: environment, format: monoBuffer.format)
engine.connect(environment, to: engine.mainMixerNode, format: outputFormat)
```

**The connection format from each player should be mono** for canonical point-source spatialization. Multichannel input is allowed (iOS 13+) with `sourceMode = .pointSource` to sum to mono or `.ambienceBed` for world-anchored multichannel.

### Listener properties

- `listenerPosition` — `AVAudio3DPoint`.
- `listenerVectorOrientation` — `AVAudio3DVectorOrientation` (forward, up).
- `listenerAngularOrientation` — `AVAudio3DAngularOrientation` (yaw, pitch, roll).

### Per-source properties (on `AVAudioPlayerNode` via the `AVAudio3DMixing` protocol)

- `position` — `AVAudio3DPoint`.
- `renderingAlgorithm`.
- `sourceMode` — `.pointSource`, `.ambienceBed`, `.bypass`.
- `pointSourceInHeadMode`.
- `obstruction`, `occlusion`.
- `reverbBlend`.
- `rate`.

### Environment-wide properties

- `distanceAttenuationParameters` — model (`inverse`, `linear`, `exponential`), `referenceDistance`, `maximumDistance`, `rolloffFactor`.
- `reverbParameters` — `enable`, `level`, `filterParameters`, `loadFactoryReverbPreset(_:)`.
- `outputType` — `auto`, `headphones`, `builtInSpeakers`, `externalSpeakers`. Affects HRTF binauralization. `.auto` requires real-time render mode (not manual rendering).

### Rendering algorithms (CPU vs quality)

- `HRTFHQ` (iOS 14.5+) — highest quality, highest CPU.
- `HRTF` — good quality, moderate CPU.
- `sphericalHead` — simpler binaural approximation.
- `equalPowerPanning` — amplitude panning across stereo, no HRTF.
- `stereoPassThrough` — no spatialization.
- `auto` (iOS 13+) — picks based on the current route.

Prefer `.auto` unless you have a specific reason to pin.

## PHASE — Physical Audio Spatialization Engine

PHASE (iOS 15 / macOS 12 / tvOS 15+) introduced at WWDC21 session 10079. A standalone scene-graph spatial-audio engine; not a node inside `AVAudioEngine`.

Use PHASE when you need:

- Volumetric sources (not just points)
- Occluders with acoustic materials (cardboard, glass, brick)
- Geometric reverb (physically modeled, not preset-only)
- Parameterized sound-event trees (random, switch, blend, container)

Core types:

- `PHASEEngine(updateMode: .automatic | .manual)` — owns asset registry, scene graph, I/O. `start()` / `stop()`.
- `PHASEListener` — position/orientation via `simd_float4x4` transform; sets default reverb preset.
- `PHASESource` — point or volumetric (built from `PHASEShape` + `MDLMesh`).
- `PHASEOccluder` — geometry that attenuates / filters transmission per `PHASEMaterial` preset.
- Mixers: `PHASEChannelMixer` (no spatialization), `PHASEAmbientMixer` (externalized, no distance), `PHASESpatialMixer` (full spatial pipeline with direct path / early reflections / late reverb).
- Sound events: assets built from generator (`PHASESamplerNodeDefinition`) and control nodes (`Random`, `Switch`, `Blend`, `Container`), parameterized by `PHASEMetaParameter`, registered, then triggered via `PHASESoundEvent`.

Distance models: `PHASEGeometricSpreadingDistanceModelParameters` with `rolloffFactor` and `fadeOutParameters.cullDistance`.

PHASE handles AirPods spatial-audio routing automatically.

## Head-tracked spatial audio

AirPods Pro / Max / 3rd gen+ (H1 / H2 chips) expose head-pose data via `CMHeadphoneMotionManager` (CoreMotion, iOS 14+).

```swift
let motion = CMHeadphoneMotionManager()
motion.startDeviceMotionUpdates(to: .main) { dm, _ in
    guard let dm else { return }
    let yaw   = Float(dm.attitude.yaw)   * (180 / .pi)
    let pitch = Float(dm.attitude.pitch) * (180 / .pi)
    let roll  = Float(dm.attitude.roll)  * (180 / .pi)
    environment.listenerAngularOrientation = .init(yaw: yaw, pitch: pitch, roll: roll)
}
```

**Neither `AVAudioEnvironmentNode` nor PHASE auto-routes head tracking.** The app must read motion and update the listener orientation. Update at UI / display rate (60–120 Hz is fine; audio rate is too fast and unnecessary).

Requires `NSMotionUsageDescription` in Info.plist.

visionOS handles head-tracked spatial audio system-wide for spatialized sources.

## Channel layouts and Atmos

Spatial multichannel formats use `AVAudioFormat` + `AVAudioChannelLayout(layoutTag:)`. Tags live in `CoreAudioTypes`:

- `kAudioChannelLayoutTag_MPEG_5_1_C`, `_MPEG_7_1_A`
- `kAudioChannelLayoutTag_AAC_5_1`, `_AAC_7_1`
- Object-based Atmos: `kAudioChannelLayoutTag_Atmos_5_1_2`, `_Atmos_5_1_4`, `_Atmos_7_1_2`, `_Atmos_7_1_4`, `_Atmos_9_1_6`

For `AVAudioEnvironmentNode` multichannel output (e.g., `kAudioChannelLayoutTag_AudioUnit_5_0` / `6_0` / `7_0`), the node renders directly to surround.

**Authoring Atmos in-app is rare**; the common case is **playback** of tagged AAC/ALAC content via `AVPlayer` or `AVAudioFile`. The OS renders to AirPods, HomePod, or built-in speakers.

Apple Music's Dolby Atmos uses the same object-based layouts.

## Pitfalls

- **CPU**: `HRTFHQ` ≫ `HRTF` ≫ `sphericalHead` ≫ `equalPowerPanning` ≫ `stereoPassThrough`. Budget accordingly. Use `.auto` unless you measured otherwise.
- **Mono sources** are required for proper spatialization with `AVAudioPlayerNode` → `AVAudioEnvironmentNode`. Stereo/multichannel sources need `sourceMode = .pointSource` (sum to mono) or `.ambienceBed`.
- **Position updates from the render thread** are forbidden. Update from main / motion-callback context only.
- **Routing**: route all spatial sources through `AVAudioEnvironmentNode` — never into `mainMixerNode` directly, or they bypass HRTF.
- **`outputType = .auto`** is unavailable in manual rendering mode.
- **AirPods head tracking is not automatic** — you must read motion and write the listener orientation.
- **Don't mix PHASE and `AVAudioEngine` outputs into the same physical route** without explicit session coordination.
- **Spatial sources on speakers** (not headphones) use amplitude panning unless `outputType` is forced to `.headphones`. Test on the route you ship for.

## Authoritative sources

- AVAudioEnvironmentNode — https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode
- AVAudio3DMixing — https://developer.apple.com/documentation/avfaudio/avaudio3dmixing
- AVAudio3DMixingRenderingAlgorithm — https://developer.apple.com/documentation/avfaudio/avaudio3dmixingrenderingalgorithm
- AVAudio3DMixing.sourceMode — https://developer.apple.com/documentation/avfaudio/avaudio3dmixing/sourcemode
- AVAudioEnvironmentNode.outputType — https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode/outputtype
- PHASE framework — https://developer.apple.com/documentation/phase
- PHASEEngine — https://developer.apple.com/documentation/phase/phaseengine
- PHASEListener — https://developer.apple.com/documentation/phase/phaselistener
- PHASESource — https://developer.apple.com/documentation/phase/phasesource
- WWDC21 — "Discover geometry-aware audio with PHASE" — https://developer.apple.com/videos/play/wwdc2021/10079/
- WWDC19 — "What's New in AVAudioEngine" (multichannel + sourceMode) — https://developer.apple.com/videos/play/wwdc2019/510/
- AVAEGamingExample sample — https://developer.apple.com/library/archive/samplecode/AVAEGamingExample/Introduction/Intro.html
- CMHeadphoneMotionManager — https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager
- AVAudioChannelLayout — https://developer.apple.com/documentation/avfaudio/avaudiochannellayout
- Audio Channel Layout Tags — https://developer.apple.com/documentation/coreaudiotypes/1572101-audio_channel_layout_tags

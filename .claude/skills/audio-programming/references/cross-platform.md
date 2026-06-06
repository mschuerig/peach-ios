# Cross-Platform Audio Context

This reference exists to make you aware of the broader audio-plugin and audio-app ecosystem. Even when shipping only Apple-native code, the patterns and authorities from cross-platform development inform Apple-platform choices.

## Plugin formats

| Format | Owner | Platforms | Status | Notes |
|---|---|---|---|---|
| **VST2** | Steinberg | Win/macOS/Linux | **Deprecated** | SDK distribution stopped Oct 2018; no new licenses. Existing binaries still load. |
| **VST3** | Steinberg | Win/macOS/Linux | Current (3.7.x) | Dual License (proprietary or GPLv3). Hosted at github.com/steinbergmedia/vst3sdk. |
| **AUv2** | Apple | macOS only | Soft-deprecated | Still ubiquitous in Logic and older DAWs. New code targets AUv3. |
| **AUv3** | Apple | macOS, iOS, tvOS, visionOS | Current | App Extension model. Only Apple plugin format on iOS. |
| **AAX** | Avid | Win/macOS | Current | Pro Tools exclusive. NDA-gated SDK. |
| **CLAP** | u-he + Bitwig | Win/macOS/Linux | Current (since 2022) | MIT-licensed open standard. Adopted by Bitwig, Reaper, FL Studio, Studio One, Cubase. |
| **LV2** | Linux community | mostly Linux | Current | RDF-described extensions. JUCE 7+ ships an LV2 target. |
| **IAA** (Inter-App Audio) | Apple | iOS | **Deprecated** iOS 13 | Replaced by AUv3. |
| **Audiobus** | Third-party (audiob.us) | iOS | Active | Pre-dated IAA; still widely used as a session host alongside AUM. |

## JUCE — the cross-platform reference

[JUCE](https://juce.com) is the de-facto cross-platform C++ framework for audio plugin and app development. Created by Jules Storer, now owned by PACE Anti-Piracy (acquired from ROLI in 2020). Dual-licensed: GPLv3 for open-source, paid commercial tiers otherwise.

- Source: https://github.com/juce-framework/JUCE
- Docs: https://docs.juce.com/master/index.html

JUCE compiles a single codebase to **VST3, AU (v2 and v3), AAX, LV2, standalone app, and CLAP** (via the third-party `clap-juce-extensions`).

For an Apple-shop developer, JUCE is the obvious answer when scope expands to Windows/Linux DAWs or Pro Tools/AAX.

The central contract is `juce::AudioProcessor::processBlock(AudioBuffer&, MidiBuffer&)`, called on the host's audio thread. Same RT rules apply: no allocation, no locks, no syscalls, no Obj-C/Swift runtime calls, no `std::cout`. JUCE encodes this via lock-free FIFOs (`AbstractFifo`), `SpinLock` for last-resort short critical sections, and conventions around realtime-safe parameter updates.

Parameters use **`AudioProcessorValueTreeState`** (APVTS): a thread-safe parameter tree where UI and audio thread communicate via `std::atomic<float>*` pointers obtained once during `prepareToPlay`. The audio thread reads atomically; the UI writes through the host's automation pipeline. This mirrors Apple's `AUParameterTree` model.

### When to reach for JUCE from Apple-native code

- You need to ship a VST3 or AAX build alongside the AUv3.
- You want one codebase across Logic / Live / Pro Tools / Reaper.
- You want faster plugin scaffolding than raw `AUAudioUnit`.

### When to stay native AUv3

- iOS-first product.
- SwiftUI views.
- Deep `AVAudioEngine` integration.
- App Store distribution as the primary channel.

## DAW hosting matrix

### macOS hosts

| DAW | AU | VST2 | VST3 | AAX | CLAP | LV2 |
|---|---|---|---|---|---|---|
| Logic Pro | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| GarageBand | ✓ (AUv3) | ✗ | ✗ | ✗ | ✗ | ✗ |
| Pro Tools | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |
| Ableton Live | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| Reaper | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
| Cubase / Nuendo | ✓ | ✗ (dropped in C14) | ✓ | ✗ | ✗ | ✗ |
| Studio One | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ |
| Bitwig Studio | ✗ | ✗ | ✓ | ✗ | ✓ | ✗ |
| FL Studio | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ |

### iOS hosts (AUv3 only)

- **GarageBand** — Apple's free DAW.
- **Logic Pro for iPad** — full Logic on iPad.
- **AUM** (Kymatica) — modular AUv3 mixer / host.
- **Cubasis** (Steinberg) — full DAW.
- **Loopy Pro** (Tasty Pixel) — live looping host.
- **drambo** — modular.

## Why testing in multiple hosts matters

Each host has its own model. A plugin clean in Logic can:

- **Stall AUM** if it allocates on its first `internalRenderBlock` (AUM's audio thread has tighter deadlines).
- **Glitch in Ableton Live** if it assumes a stable buffer size (Live changes it on transport state).
- **Misroute MIDI in Pro Tools** if it relies on a coalescing behavior different from other DAWs.
- **Fail to load in Logic** if `auval` fails.

Test matrices for shipping plugins typically include at least:
- Logic + Reaper + Live on desktop
- AUM + GarageBand on iOS

## Audio Developer Conference (ADC)

The single best community for audio devs.

- Annual conference, run by JUCE/PACE. Bristol is the flagship. Also ADCx India and ADC Japan.
- All talks published free at https://www.youtube.com/@audiodevcon
- Best archive for RT-audio, DSP, plugin design, modern C++/Rust audio.

**Speakers worth following** (most have ADC talks, blogs, books):

- **Timur Doumler** (timur.audio) — RT-safety, C++ standardization (audio working group).
- **Ross Bencina** (rossbencina.com) — "Real-time audio programming 101", QueueWorld.
- **Michael Tyson** (atastypixel.com) — TPCircularBuffer, AEManagedValue.
- **Vinnie Falco** — Boost author; plugin architecture.
- **Geraint Luff** — DSP, polyphase filters.
- **Robin Schmidt** — analog modeling.
- **Will Pirkle** — synth/effect design textbooks.
- **Phil Burk** — JSyn, PortAudio co-author.
- **Joel Liljedahl** (devnotes.kymatica.com) — AUM author, iOS-specific audio.

## Communities

- **KVR Audio** — https://www.kvraudio.com — DAW/plugin user + dev forums.
- **DSPRelated** — https://www.dsprelated.com — DSP theory.
- **The Audio Programmer** — https://theaudioprogrammer.com — tutorials and Discord community.
- **JUCE forum** — https://forum.juce.com — JUCE-specific but deep RT-safety threads.

## Authoritative URLs

- JUCE — https://github.com/juce-framework/JUCE — docs https://docs.juce.com/master/index.html
- VST3 SDK — https://github.com/steinbergmedia/vst3sdk — portal https://steinbergmedia.github.io/vst3_dev_portal/
- CLAP spec — https://github.com/free-audio/clap — site https://cleveraudio.org/
- AAX SDK — https://developer.avid.com/aax (NDA registration required)
- LV2 — https://lv2plug.in (source https://gitlab.com/lv2/lv2)
- Apple AUv3 — https://developer.apple.com/documentation/audiotoolbox/audio-unit-v3-plug-ins
- ADC YouTube — https://www.youtube.com/@audiodevcon
- ADC conference — https://audio.dev

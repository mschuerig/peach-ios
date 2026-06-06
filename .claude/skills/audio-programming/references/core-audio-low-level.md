# Low-Level Core Audio (AudioToolbox / HAL)

`AVAudioEngine` covers most app needs. This reference is for the cases where you need to drop below it: HAL device control, virtual audio devices, ExtAudioFile for streaming I/O, bit-perfect output, or maintaining AUv2 hosting.

## API status (2026)

| API | Status | Notes |
|---|---|---|
| **AUGraph** | **Deprecated** (macOS 10.14 / iOS 12, WWDC19 #508). Headers ship for legacy. | Use `AVAudioEngine`. |
| **Audio Queue Services** | Not formally deprecated. Soft-legacy. | Use only for narrow streaming-decoder cases where AQ's packet-based callback is genuinely simpler. |
| **AudioUnit C API (AUv2 hosting)** | Soft-deprecated for new hosts. | Apple maintains "Hosting AUv2 Using the AUv2 API" for compat. |
| **AVAudioEngine + AUAudioUnit (AUv3)** | Current preferred path. | See `avaudio-engine.md`, `audio-units.md`. |
| **AudioFile / ExtAudioFile** | Current. | `ExtAudioFile` = `AudioFile` + inline `AudioConverter`. |
| **AudioConverter** | Current. | Underpins `ExtAudioFile` and `AVAudioConverter`. |
| **CAF** (Core Audio Format) | Current. | Preferred for >4 GB or VBR with packet tables. |
| **HAL / `AudioObject*`** (macOS) | Current. | The only way to enumerate/configure devices, aggregate devices, set bit-perfect formats. |
| **AudioServerPlugIn** (macOS 10.10+) | Current. | Userspace driver model. BlackHole, Loopback, BackgroundMusic are built on it. |
| **AudioDriverKit** (macOS Monterey+) | Current. | DriverKit-based driver for real hardware; supersedes kext drivers. |

## When to drop below `AVAudioEngine`

- **Hosting AUv2 plugins** outside `AVAudioEngine`'s component-description flow, or implementing a custom AUv2 host with property listeners and offline render.
- **macOS bit-perfect output.** `AVAudioEngine` cannot set the device's hog-mode, `kAudioDevicePropertyNominalSampleRate`, or `kAudioStreamPropertyPhysicalFormat`. Use HAL via `AudioObjectSetPropertyData`.
- **`AudioServerPlugIn`** (virtual audio devices like BlackHole, Loopback, Soundflower's modern replacements) and **AudioDriverKit dexts** for real hardware. No higher-level wrapper exists.
- **Aggregate / multi-output devices** programmatic creation (`kAudioPlugInCreateAggregateDevice`).
- **Format negotiation on hardware** (`kAudioStreamPropertyAvailablePhysicalFormats`).
- **Sample-accurate offline render** of complex graphs needing full control of `AURenderActionFlags` and pull semantics.
- **Tight latency tuning.** `kAudioDevicePropertyBufferFrameSize` on the device, not the engine.
- **Custom file I/O with on-the-fly format conversion.** `ExtAudioFile` lets you read a compressed file directly as Float32 PCM at a target rate.

## Threading model

- **HAL render thread** — a kernel-scheduled real-time pthread (time-constraint policy). On iOS audio extensions and macOS HAL, your code is invoked synchronously on it.
- **`AUAudioUnit.internalRenderBlock`** is the realtime callback. Per `AUAudioUnit` header: called on a real-time thread; **no Obj-C/Swift runtime calls that may allocate, no locks, no `@objc` dispatch, no Swift class init, no file I/O, no `os_log` above signpost, no Obj-C autorelease**. Use the `AudioBufferList` you receive; if you need to pull upstream, call the supplied `AURenderPullInputBlock`.
- **`AURenderCallback`** (C, AUv2 / remote-IO) — same realtime contract.
- **Cross-thread comms** — lock-free SPSC FIFO (Bencina), `std::atomic` for scalars, RCU-style swap of immutable state for complex updates (Doumler). Never `pthread_mutex_lock` from render.

## Key types

### `AudioStreamBasicDescription` (ASBD)

Format descriptor. Fields:

```c
struct AudioStreamBasicDescription {
    Float64  mSampleRate;        // 44100.0, 48000.0, ...
    UInt32   mFormatID;          // kAudioFormatLinearPCM, kAudioFormatMPEG4AAC, ...
    UInt32   mFormatFlags;       // bitwise OR of kAudioFormatFlag*
    UInt32   mBytesPerPacket;
    UInt32   mFramesPerPacket;   // 1 for PCM; codec-specific otherwise
    UInt32   mBytesPerFrame;
    UInt32   mChannelsPerFrame;
    UInt32   mBitsPerChannel;
    UInt32   mReserved;          // must be 0
};
```

For canonical Float32 (the Apple internal default):

```c
.mFormatID    = kAudioFormatLinearPCM;
.mFormatFlags = kAudioFormatFlagIsFloat
              | kAudioFormatFlagIsPacked
              | kAudioFormatFlagIsNonInterleaved;
.mBitsPerChannel    = 32;
.mBytesPerFrame     = 4;
.mBytesPerPacket    = 4;
.mFramesPerPacket   = 1;
```

### `AudioBufferList`

Variable-length C struct:

```c
struct AudioBufferList {
    UInt32      mNumberBuffers;
    AudioBuffer mBuffers[1];  // flexible array, one or more
};

struct AudioBuffer {
    UInt32 mNumberChannels;
    UInt32 mDataByteSize;
    void  *mData;
};
```

- **Interleaved** = 1 `AudioBuffer` with `mNumberChannels = N` and interleaved `LRLRLRLR…` samples.
- **Non-interleaved** = N `AudioBuffer`s each with `mNumberChannels = 1` and contiguous samples for one channel.

Sizing trap: allocate `sizeof(AudioBufferList) + (N - 1) * sizeof(AudioBuffer)`. The struct's `mBuffers[1]` is a flexible array tail; using `sizeof(AudioBufferList)` alone truncates silently.

### `AudioTimeStamp`

```c
struct AudioTimeStamp {
    Float64           mSampleTime;   // host sample clock
    UInt64            mHostTime;     // mach_absolute_time units
    Float64           mRateScalar;
    UInt64            mWordClockTime;
    SMPTETime         mSMPTETime;
    AudioTimeStampFlags mFlags;      // which fields are valid
    UInt32            mReserved;
};
```

Always check `mFlags` to learn which fields are valid; not all callbacks populate all of them.

### `kAudioUnit*` selectors

- **Property IDs.** `kAudioUnitProperty_StreamFormat`, `kAudioOutputUnitProperty_EnableIO`, `kAudioUnitProperty_SetRenderCallback`, `kAudioUnitProperty_MaximumFramesPerSlice`, …
- **Scope.** `kAudioUnitScope_Input`, `kAudioUnitScope_Output`, `kAudioUnitScope_Global`.
- **Element/bus numbers.** 0 = output / first input; element 1 of an output unit = input scope on the input bus.

## Common traps

- **"Is big-endian" flag.** `kAudioFormatFlagIsBigEndian` absent = little-endian. Canonical Apple PCM is little-endian Float32.
- **Packed vs non-interleaved are independent flags.** Both can be on. Non-interleaved Float32 requires one `AudioBuffer` per channel.
- **Buffer ownership.** In a render callback, the `AudioBufferList*` you receive belongs to the caller; you fill `mData`. For `AudioUnitRender` pull, you may pass `mData = NULL` and the unit can give you its internal buffer.
- **`AudioConverter`.** VBR formats require `AudioConverterComplexInputDataProc` plus `AudioStreamPacketDescription[]`; CBR can use the simpler `AudioConverterConvertBuffer`. Magic cookies (`kAudioConverterDecompressionMagicCookie`) are required for AAC/ALAC.
- **`AudioFileTypeID` vs `mFormatID`** — file type (`kAudioFileCAFType`) is the container; format ID is the codec. They are independent; mismatch yields cryptic `fmt?` errors.
- **`MaximumFramesPerSlice`** must be set before `AudioUnitInitialize` or the render block will be torn down when the host requests a larger slice (screen-locked iOS background audio is a common trigger).

## ExtAudioFile

`ExtAudioFile` is the AudioToolbox C-API path for reading and writing audio files with **inline format conversion**. The client tells the framework "I want frames in this format" via `kExtAudioFileProperty_ClientDataFormat`, and reads/writes return frames already in that format.

```c
ExtAudioFileRef ref;
ExtAudioFileOpenURL((CFURLRef)fileURL, &ref);

AudioStreamBasicDescription clientFormat = /* Float32 stereo, 44100 */;
ExtAudioFileSetProperty(ref,
    kExtAudioFileProperty_ClientDataFormat,
    sizeof(clientFormat), &clientFormat);

AudioBufferList bufList;
UInt32 frames = 1024;
ExtAudioFileRead(ref, &frames, &bufList);
// bufList now contains `frames` Float32 stereo frames decoded from whatever
// codec the file actually uses.

ExtAudioFileDispose(ref);
```

`AVAudioFile` wraps this in Swift. Drop to `ExtAudioFile` directly when you need stream-time format conversion, multi-track files, or fine-grained file format control.

## AudioServerPlugIn and AudioDriverKit (macOS)

**AudioServerPlugIn** (CoreAudio `AudioServerPlugIn.h`) — userspace driver hosted by `coreaudiod`. Cannot kernel-panic; no reboot to install; appears as a normal Core Audio device. Used by BlackHole (loopback), Loopback (app routing), BackgroundMusic (per-app volume).

**AudioDriverKit** (macOS Monterey+) — DriverKit framework for real audio hardware drivers; replaces kexts. Bundled inside a Mac app as a `.dext`; the HAL talks to it directly. AudioServerPlugIn can also front a DriverKit dext for hardware.

If you're not writing a driver, you don't need either of these — you talk to whichever device is exposed via the HAL.

## `AudioToolboxCore` (umbrella)

AUv3 app extensions can't link the full AudioToolbox framework — they get `AudioToolboxCore`, the AUv3-safe subset (CoreAudio types, `AUAudioUnit`, render events). If you're writing an AUv3, you'll find some AudioToolbox functions are unavailable; that's why.

## Authoritative sources

- Audio Toolbox landing — https://developer.apple.com/documentation/audiotoolbox
- AUAudioUnit — https://developer.apple.com/documentation/audiotoolbox/auaudiounit
- Hosting AUv2 — https://developer.apple.com/documentation/audiotoolbox/hosting-audio-unit-extensions-using-the-auv2-api
- Audio Queue Services — https://developer.apple.com/documentation/audiotoolbox/audio-queue-services
- AudioStreamBasicDescription — https://developer.apple.com/documentation/coreaudiotypes/audiostreambasicdescription
- AudioBufferList — https://developer.apple.com/documentation/coreaudiotypes/audiobufferlist
- Extended Audio File Services — https://developer.apple.com/documentation/audiotoolbox/extended_audio_file_services
- CAF format spec — https://developer.apple.com/library/archive/documentation/MusicAudio/Reference/CAFSpec/CAF_intro/CAF_intro.html
- WWDC19 Session 508 — "Modernizing Your Audio App" (AUGraph deprecation): https://asciiwwdc.com/2019/sessions/508
- WWDC21 — "Create audio drivers with DriverKit": https://developer.apple.com/videos/play/wwdc2021/10190/
- Chris Adamson & Kevin Avila — *Learning Core Audio* (Addison-Wesley, 2012). Pre-AVAudioEngine but accurate for AudioConverter / ExtAudioFile / AUv2.

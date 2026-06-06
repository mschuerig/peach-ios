# Audio File I/O and Recording

## Containers vs codecs

Distinguish container from codec.

| Container | Typical codec | Notes |
|---|---|---|
| **WAV** | PCM | Ubiquitous, 4 GB max |
| **AIFF** | PCM | Older Apple format, 4 GB max |
| **CAF** (Core Audio Format) | any Core Audio codec | Apple's flexible container, no practical size limit, sample-accurate loop/marker chunks, multichannel, canonical for AU patch banks |
| **M4A** | AAC, ALAC, MP3 | MPEG-4 audio container |
| **FLAC** (`.flac`) | FLAC lossless | Apple supports decode and encode since iOS 11 / macOS 10.13 (extended in iOS 14 / macOS 11) |
| **Opus** | Opus | Some decode support in pipelines, not first-class for `AVAudioFile` writing |
| **Ogg Vorbis** | Vorbis | Third-party libraries only |

**Prefer CAF** when the file is large, multichannel, has loop points, or stays inside Apple platforms. CAF is the canonical container for sample players (e.g., AU patch banks) and supports any codec Core Audio understands.

**AAC in M4A** is the standard ubiquitous lossy format. **MP3** is decode-only on iOS — no system encoder.

## API tiers

| API | Level | Use for |
|---|---|---|
| `AVAudioFile` | High | Read/write decoded PCM, simple case |
| `AVAudioPCMBuffer` | Buffer | In-memory PCM frames |
| `AVAudioCompressedBuffer` | Buffer | Compressed packets (for `AVAudioConverter` encode) |
| `AVAudioConverter` | High | Format conversion (sample rate, channels, codec) |
| `ExtAudioFile` | Low (C) | Stream-time conversion; client format ≠ file format |
| `AudioFile` | Low (C) | Raw file packet access |

## Reading audio files

```swift
let file = try AVAudioFile(forReading: url)
let buf  = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                            frameCapacity: AVAudioFrameCount(file.length))!
try file.read(into: buf)
```

- `file.fileFormat` — what's on disk. For compressed files this is the codec format.
- `file.processingFormat` — decoded float PCM you receive in buffers. Differs from `fileFormat` for compressed files.
- `file.length` — frames, can be very large (multi-hour files exceed `Int32`; keep as `AVAudioFramePosition` / Int64).

For codec or sample-rate conversion at read time, use `ExtAudioFile` with `kExtAudioFileProperty_ClientDataFormat`; each read returns frames already in your target format.

Loop a buffer with `AVAudioPlayerNode.scheduleBuffer(buf, at: nil, options: .loops)`. For sample-accurate loop points inside a single file, use CAF + `kAudioFilePropertyMarkerList`.

## Writing audio files

```swift
let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44100,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 192_000,
]
let file = try AVAudioFile(forWriting: url, settings: settings)
try file.write(from: buf)
```

The codec is implied by `settings` + file extension. Write PCM buffers with `file.write(from:)`.

### Tap-on-bus pattern

Capture any node's output to disk by installing a tap:

```swift
node.installTap(onBus: 0, bufferSize: 4096,
                format: node.outputFormat(forBus: 0)) { buf, _ in
    try? file.write(from: buf)
}
```

Taps run on a dedicated non-RT high-priority thread; `try?` is acceptable but disk back-pressure can still stall — keep the file on fast storage. For video + audio together, use `AVAssetWriter` + `AVAssetWriterInput`.

**Format trade-off:** PCM (in WAV / CAF) is large and lossless; AAC (in M4A) is ~10× smaller and lossy but universally playable.

## Recording

Two ladders:

### 1. `AVAudioRecorder` — simple cases

Records the mic directly to a file with a settings dictionary. Includes built-in `averagePower(forChannel:)` / `peakPower(forChannel:)` after `updateMeters()`. Right choice for memos, simple capture, no processing.

```swift
let recorder = try AVAudioRecorder(url: url, settings: settings)
recorder.isMeteringEnabled = true
recorder.record()
```

### 2. `AVAudioEngine.inputNode` — full control

Install a tap to receive `AVAudioPCMBuffer`s from the mic; route through effects; monitor to output; or write via `AVAudioFile`.

```swift
let input = engine.inputNode
let format = input.inputFormat(forBus: 0)   // hardware format — do NOT assume 44.1
input.installTap(onBus: 0, bufferSize: 4096, format: format) { buf, when in
    try? file.write(from: buf)
}
try engine.start()
```

### Session

`AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])` for full duplex; `.record` if you don't need playback.

### Permission

- Info.plist: `NSMicrophoneUsageDescription`.
- Request: `AVAudioApplication.requestRecordPermission` (iOS 17+) or `AVAudioSession.sharedInstance().requestRecordPermission(_:)` (earlier).

### Echo cancellation for voice / call apps

Enable `setVoiceProcessingEnabled(true)` on the input node — routes through `kAudioUnitSubType_VoiceProcessingIO` (AEC + AGC + noise suppression). **Do not enable for music capture** — it colors the signal.

### Recording while playing

Requires `.playAndRecord` and a single `AVAudioEngine` instance. The engine's input and output share a clock so capture and playback stay aligned.

## Format conversion

`AVAudioConverter(from: srcFormat, to: dstFormat)` handles sample rate, channel count, bit depth, interleaving, and PCM ↔ AAC / ALAC / Opus.

- For 1:1 PCM conversions: `convert(to:from:)`.
- For codec encode/decode or rate changes with non-1:1 frame ratios: pull form `convert(to:error:withInputFrom:)` with an `AVAudioConverterInputBlock` that supplies input on demand.

Pre-allocate the output `AVAudioPCMBuffer` / `AVAudioCompressedBuffer` once and reuse — allocation is the RT-killer, not the conversion math itself.

For bulk offline conversions during file reads, prefer `ExtAudioFile` with a client format so the framework converts in-stream.

For deinterleave, scale, mix-to-mono, and int↔float on hot paths, **vDSP** (`vDSP_vflt16`, `vDSP_vsmul`, `vDSP_vadd`) is faster than hand-written loops.

## Common pitfalls

- **Sample-rate mismatch**: `inputNode.inputFormat` may be 48 kHz while you assumed 44.1 — connect through an `AVAudioConverter` or use the input's actual format. Wrong rate = pitch shift + crackle.
- **Channel layout**: don't assume stereo. `inputNode` is often mono; `format.channelCount` is truth.
- **FLAC / Opus surprises**: encode support varies by OS version. Check `AudioFormatGetProperty(kAudioFormatProperty_EncoderSpecificConfig, …)` before committing to a writer.
- **Buffer ownership**: `AVAudioPCMBuffer` owns its backing memory; the data pointer is valid only while the buffer is retained. Never capture raw `floatChannelData` past the tap closure.
- **`frameLength` vs `frameCapacity`**: capacity is allocated size; `frameLength` is *valid* frames. After `file.read(into:)` check `frameLength` — short reads happen at EOF. Writers consume `frameLength`, not capacity.
- **`AVAudioFile.length`**: frames, not bytes, not seconds. Keep as `AVAudioFramePosition` / Int64.
- **Tap thread**: tap blocks are not strictly RT-required but are time-sensitive. Never do disk I/O without buffering on a slow medium, and never block on a lock the audio thread also touches.
- **Bluetooth HFP input**: forces mono 16 kHz. Don't expect HiFi from a HFP route.
- **Voice Processing on music**: noticeable AGC pumping. Disable for music apps.

## Authoritative sources

- AVAudioFile — https://developer.apple.com/documentation/avfaudio/avaudiofile
- AVAudioRecorder — https://developer.apple.com/documentation/avfaudio/avaudiorecorder
- AVAudioConverter — https://developer.apple.com/documentation/avfaudio/avaudioconverter
- AVAudioEngine inputNode — https://developer.apple.com/documentation/avfaudio/avaudioengine/inputnode
- Core Audio Format spec — https://developer.apple.com/library/archive/documentation/MusicAudio/Reference/CAFSpec/CAF_intro/CAF_intro.html
- Extended Audio File Services — https://developer.apple.com/documentation/audiotoolbox/extended_audio_file_services
- Tasty Pixel — "Four common mistakes in audio development" — https://atastypixel.com/four-common-mistakes-in-audio-development/
- Mike Ash — Friday Q&A (Fourier transforms / Core Audio context) — https://www.mikeash.com/pyblog/friday-qa-2012-10-26-fourier-transforms-and-ffts.html

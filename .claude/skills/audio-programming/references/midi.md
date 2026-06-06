# MIDI on Apple Platforms

CoreMIDI underlies all MIDI on iOS / iPadOS / macOS / tvOS / visionOS. MIDI 1.0 and MIDI 2.0 (Universal MIDI Packet, UMP) coexist; CoreMIDI handles conversion between them.

## CoreMIDI architecture

- **`MIDIClientRef`** — one per process. Owns ports.
- **`MIDIInputPortRef` / `MIDIOutputPortRef`** — receive / send.
- **`MIDIEndpointRef`** — a source (emits) or destination (consumes). Belongs to an entity, which belongs to a device discoverable in Audio MIDI Setup.
- **Virtual source / destination** — your app can publish one via `MIDISourceCreateWithProtocol` / `MIDIDestinationCreateWithProtocol`. Other apps see it as a normal endpoint. This is how iOS apps expose internal MIDI to host apps.
- **MIDI Network Session (RTP-MIDI)** — `MIDINetworkSession.default()` on iOS / macOS. When enabled, network endpoints appear automatically.
- **Bluetooth LE MIDI** — on iOS, access via `CABTMIDICentralViewController` / `CABTMIDILocalPeripheralViewController` (CoreAudioKit). Once paired, the peer appears as a normal CoreMIDI endpoint; no protocol-specific code is needed.

## MIDI 1.0 vs MIDI 2.0 / UMP

**MIDI 1.0** is a byte stream:

- Status byte (high bit set) encodes message type + channel 0–15.
- 1–2 data bytes (high bit clear; 7-bit values 0–127).
- Channel voice messages: Note On `0x9n`, Note Off `0x8n`, CC `0xBn`, Program Change `0xCn`, Pitch Bend `0xEn`. Plus System Common / Real-Time / SysEx.
- 7-bit value range (0–127) is the resolution ceiling. Pitch Bend gets 14 bits via a 2-byte payload.

**MIDI 2.0** is packetized as **Universal MIDI Packets (UMP)** — native 32-bit words, 1/2/3/4 words per message:

- 4-bit **group** field × 16 channels = **256 channels** per UMP stream.
- **16-bit Note On velocity**, **32-bit CC values**, **per-note pitch bend**, **per-note controllers**, **per-note attributes**.
- Integrated SysEx-7 (legacy) and SysEx-8.
- **MIDI-CI** (Capability Inquiry) negotiates which protocol two endpoints will speak; default is MIDI 1.0 until both sides upgrade.
- CoreMIDI **automatically translates** between protocols: a UMP endpoint can receive from a MIDI 1.0 source (CoreMIDI converts to UMP) and vice versa. Pick wire protocol once with `MIDIProtocolID` (`._1_0` or `._2_0`) at endpoint creation.

**Apple availability:**

- UMP / `MIDIEventList` / `MIDISendEventList` — **macOS 11 / iOS 14**.
- Audio Unit MIDI 2 properties (`audioUnitMIDIProtocol`, `hostMIDIProtocol`, `scheduleMIDIEventListBlock`, `midiOutputEventListBlock`) — **macOS 12 / iOS 15**.
- visionOS supports all of this since 1.0.

## `MIDIEventList` vs `MIDIPacketList`

- **`MIDIPacketList` / `MIDIPacket`** — legacy. Each packet holds a raw MIDI 1.0 byte stream with a `MIDITimeStamp`. Send via `MIDISend` / `MIDIReceived`. Still works, no deprecation, but cannot represent MIDI 2.0.
- **`MIDIEventList` / `MIDIEventPacket`** — modern. `MIDIEventPacket.words` is a stream of native-endian 32-bit UMPs (up to 64 words per packet); the list carries a `MIDIProtocolID` so the receiver knows the encoding. Send via `MIDISendEventList`, receive via `MIDIReceivedEventList`. Build with `MIDIEventListInit` + `MIDIEventListAdd` (or `MIDIEventPacket.Builder` in Swift).

When targeting iOS 14 / macOS 11+: use `MIDIEventList`.

## Scheduling MIDI into an Audio Unit

`AUAudioUnit` exposes two scheduling blocks. The host fetches the property *before* rendering starts and calls the block from the audio render thread:

- **`scheduleMIDIEventBlock: AUScheduleMIDIEventBlock?`** — MIDI 1.0 bytes.
  Signature: `(AUEventSampleTime, UInt8 cable, Int length, UnsafePointer<UInt8> bytes)`.
- **`scheduleMIDIEventListBlock: AUMIDIEventListBlock?`** — UMP / MIDI 2.0 events.
  Signature takes an `UnsafePointer<MIDIEventList>`.

### The sample-time pattern (Liljedahl)

Despite what the API surface suggests, passing an absolute `mSampleTime` to these blocks does **not** reliably place events in the current cycle. The empirically-correct pattern:

```
AUEventSampleTimeImmediate + offsetFrames
```

where `offsetFrames` is in `0 ..< currentBufferSize` of the active render cycle. **Call from the render thread** (or a lock-free SPSC FIFO drained on it) so the offset stays associated with the cycle that produced it.

Source: Joel Liljedahl (AUM author), http://devnotes.kymatica.com/ios_midi_timestamps.html. The finding is from 2018 / iOS 11 and has not been publicly contradicted or publicly re-verified on iOS 18+. The offset-from-render-cycle pattern remains the de-facto consensus and is what AudioKit, Apple sample code, and shipping AUv3s use.

### MIDI out of an AU

For an AU that emits MIDI (sequencer / arpeggiator plugins), the host installs a callback into:

- **`midiOutputEventBlock: AUMIDIOutputEventBlock?`** (MIDI 1.0), or
- **`midiOutputEventListBlock: AUMIDIEventListBlock?`** (UMP).

The AU fills these from its `internalRenderBlock`; the host converts the AU's absolute timestamps back into frame offsets by subtracting the cycle's starting `mSampleTime`.

## MusicSequence / MusicPlayer

The legacy AudioToolbox playback API. Still ships on every Apple platform, **not deprecated**, but effectively legacy: opaque ref types, `MusicTrack` event editing via C functions, awkward bridging to AVAudioEngine. **`AVAudioSequencer` is the recommended replacement.**

When to still use `MusicSequence`:

- Existing code that already uses it.
- Reading/writing fine-grained MIDI tempo / time-signature / meta events that `AVAudioSequencer`'s Swift surface doesn't expose.
- Interop with `AUGraph`-era hosts.

Avoid building new playback engines on it.

## AVAudioSequencer

Modern MIDI-sequence playback inside `AVAudioEngine`. Available iOS 9 / macOS 10.11+.

```swift
let seq = AVAudioSequencer(audioEngine: engine)
try seq.load(from: url, options: [.smfChannelsToTracks])
for track in seq.tracks {
    track.destinationAudioUnit = sampler
}
try seq.start()
```

Beat ↔ host-time conversion via `hostTime(forBeats:)` / `seconds(forBeats:)`.

For sample-accurate scheduling into a running engine, combine with the AU `scheduleMIDIEventListBlock` pattern above.

## Standard MIDI 1.0 messages

| Message | Status byte | Data bytes |
|---|---|---|
| Note Off | `0x8n` (n = channel 0–F) | key, velocity |
| Note On | `0x9n` | key, velocity (velocity 0 = Note Off) |
| Polyphonic Key Pressure | `0xAn` | key, pressure |
| CC | `0xBn` | controller#, value |
| Program Change | `0xCn` | program |
| Channel Pressure (Aftertouch) | `0xDn` | pressure |
| Pitch Bend | `0xEn` | LSB, MSB (center = 0x00 0x40) |

Key CCs:

| # | Name | Notes |
|---|---|---|
| 7 | Channel Volume | Persistent gain per channel |
| 10 | Pan | 0 = hard left, 64 = center, 127 = hard right |
| 11 | Expression | Realtime swell |
| 64 | Sustain | ≥ 64 sustains released notes |
| 120 | All Sound Off | Kills sound instantly, ignores release |
| 121 | Reset All Controllers | CCs, pitch bend back to defaults |
| 123 | All Notes Off | Sends note-offs, respects release |

### Panic — flushing a channel

Sequence to send per channel 0–15 that you've used:

1. **CC#123 = 0** (All Notes Off) — sends note-offs, respects release
2. **CC#120 = 0** (All Sound Off) — kills any audio still playing instantly
3. **Pitch Bend → 0x2000** (center) — `0xEn 0x00 0x40`
4. Optionally: **CC#64 = 0** (release sustain), **CC#121 = 0** (reset controllers)

For a closed AU like `AVAudioUnitSampler`, this is the safer alternative to `reset()`, which has crashed under load in shipping AudioKit-based apps.

## Common pitfalls

- **Assuming MIDI-spec semantics from a closed AU.** Especially `AVAudioUnitSampler`: empirical voice-management quirks have been observed (stopNote affecting other voices on the same channel). Test, don't reason from spec.
- **Mixing MIDI 1.0 and MIDI 2.0 dispatch into the same AU** without setting `audioUnitMIDIProtocol`. The AU may not know which protocol you intended.
- **Stuck notes after interruption.** Track outstanding note-ons; on session interruption or cancellation, flush with panic per channel.
- **Sample-accurate scheduling with absolute `mSampleTime`.** Doesn't work reliably; use the `AUEventSampleTimeImmediate + offsetFrames` pattern.
- **Threading from CoreMIDI receive callbacks.** They run on a system-owned high-priority thread; treat them as RT-adjacent. Don't block. Push events to a lock-free queue for downstream processing.

## Authoritative sources

- MIDIEventList — https://developer.apple.com/documentation/coremidi/midieventlist
- MIDIEventPacket — https://developer.apple.com/documentation/coremidi/midieventpacket
- MIDISendEventList — https://developer.apple.com/documentation/coremidi/midisendeventlist(_:_:_:)
- Incorporating MIDI 2 into your apps — https://developer.apple.com/documentation/CoreMIDI/incorporating-midi-2-into-your-apps
- AUAudioUnit.scheduleMIDIEventBlock — https://developer.apple.com/documentation/audiotoolbox/auaudiounit/scheduledmidieventblock
- AUAudioUnit.audioUnitMIDIProtocol — https://developer.apple.com/documentation/audiotoolbox/auaudiounit/audiounitmidiprotocol
- AVAudioSequencer — https://developer.apple.com/documentation/avfaudio/avaudiosequencer
- MusicSequence — https://developer.apple.com/documentation/audiotoolbox/musicsequence
- Core MIDI updates — https://developer.apple.com/documentation/updates/coremidi
- Liljedahl — iOS MIDI timestamps — http://devnotes.kymatica.com/ios_midi_timestamps.html
- MIDI Association — https://midi.org/midi-2-0-core-specification-collection

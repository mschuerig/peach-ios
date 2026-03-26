---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: []
workflowType: 'research'
lastStep: 1
research_type: 'technical'
research_topic: 'MIDI input for timing-sensitive training on iOS'
research_goals: 'Determine what is necessary to receive MIDI note events (any note, any channel) with low latency on iOS for use in timing-sensitive training disciplines'
user_name: 'Michael'
date: '2026-03-26'
web_research_enabled: true
source_verification: true
---

# MIDI Input for Timing-Sensitive Training on iOS: Technical Research

**Date:** 2026-03-26
**Author:** Michael
**Platform Target:** iOS 26+

---

## Executive Summary

Adding MIDI input to Peach for timing-sensitive training is straightforward. CoreMIDI is the sole native framework for MIDI on iOS, and **MIDIKit** (orchetect, MIT, Swift 6) is the recommended wrapper — it eliminates C-bridging boilerplate, handles device hot-plug automatically, and dispatches events off the real-time thread for you. No entitlements, Info.plist entries, AVAudioSession configuration, or background modes are needed for foreground MIDI input.

USB MIDI delivers ~1–2 ms transport latency with sub-millisecond inter-event precision. BLE MIDI has a hard 11.25 ms floor on iOS (connection interval) with ~1 ms timestamp resolution. Both are usable; USB is significantly better for precision rhythm training. CoreMIDI's `MIDITimeStamp` (host ticks) provides the timing authority — always use timestamp deltas between events rather than wall-clock comparisons.

The integration fits cleanly into Peach's existing Core/Ports architecture: a new `MIDIInput` port protocol, an adapter wrapping MIDIKit's `MIDIManager`, wired via `@Entry` in the composition root. An `AsyncStream<MIDINoteEvent>` bridges events from MIDIKit's serial queue into Swift concurrency for training session consumption. The iOS Simulator does not support CoreMIDI, so domain logic must be tested behind the protocol boundary with mocks.

**Key Findings:**

- **Zero configuration friction** — no permissions, entitlements, or audio session needed
- **MIDIKit over raw CoreMIDI** — threading bridge, type safety, auto-reconnect, Swift 6 compliance
- **USB MIDI latency: ~1–2 ms** transport, sub-ms precision; **BLE MIDI: ~11–16 ms**, ~1 ms precision
- **Fits existing architecture** — new port protocol + adapter, no changes to existing code
- **Simulator limitation** — CoreMIDI unavailable; design around protocol boundary from day one

**Recommendations:**

1. Add `MIDIKitIO` as SPM dependency
2. Define `MIDIInput` port protocol exposing `AsyncStream<MIDINoteEvent>`
3. Implement adapter wrapping `ObservableMIDIManager` with `.allOutputs` connection mode
4. Wire into composition root via `@Entry`; integrate into first training session
5. Defer device selection, channel filtering, and BLE pairing UI to later

## Table of Contents

1. [Technology Stack Analysis](#technology-stack-analysis)
   - CoreMIDI framework and modern API surface
   - Transport types and latency characteristics
   - Timestamp behavior and threading model
   - Third-party libraries (MIDIKit, AudioKit)
2. [Integration Patterns Analysis](#integration-patterns-analysis)
   - Permissions and session requirements
   - Device lifecycle and hot-plug
   - CoreMIDI callback → application thread bridge
   - Integration with Peach's Core/Ports architecture
3. [Architectural Patterns and Design](#architectural-patterns-and-design)
   - Threading architecture: CoreMIDI → Swift concurrency
   - AsyncStream as the event bridge
   - Timestamp handling architecture
   - Port protocol design options
   - Latency budget analysis
   - MIDIKit vs raw CoreMIDI decision
4. [Implementation Approaches](#implementation-approaches)
   - Minimal MIDIKit setup code
   - SPM dependency configuration
   - Testing strategy (three-tier)
   - Implementation gotchas
   - Implementation roadmap
   - Risk assessment
5. [Research Synthesis and Conclusion](#research-synthesis-and-conclusion)
   - Source documentation
   - Confidence assessment

---

## Research Overview

**Goal:** Determine what is necessary to receive MIDI note events (any note, any channel) with low latency on iOS for use in timing-sensitive training disciplines.

**Methodology:** Web-verified research with multi-source validation for latency measurements and API claims. CoreMIDI SDK headers verified against installed Xcode. MIDIKit source code examined for threading and architecture claims. Targeting iOS 26+ exclusively (no backward compatibility).

---

## Technology Stack Analysis

### CoreMIDI — The Only Native Framework

Apple provides **no higher-level MIDI framework** beyond CoreMIDI. There is no MIDI support in AVFoundation, SwiftUI, or any other high-level framework. CoreMIDI is the sole API for all MIDI transport types (USB, BLE, Network).

_Source: [Apple CoreMIDI Documentation](https://developer.apple.com/documentation/coremidi/)_

### Modern API Surface (iOS 14+)

The recommended API chain for receiving MIDI input on iOS 26:

| API | iOS | Purpose |
|---|---|---|
| `MIDIClientCreateWithBlock` | 9.0+ | Create client (closure-based) |
| `MIDIInputPortCreateWithProtocol` | **14.0+** | Create input port (modern, UMP-based) |
| `MIDIReceiveBlock` | 14.0+ | Callback type for modern input |
| `MIDIEventListForEachEvent` | **15.0+** | Parse UMP events with visitor pattern |
| `MIDIUniversalMessage` | 15.0+ | Parsed message struct with typed fields |
| `MIDIGetNumberOfSources` / `MIDIGetSource` | 4.2+ | Enumerate MIDI sources |
| `MIDIPortConnectSource` | 4.2+ | Connect source to input port |
| `MIDIBluetoothDriverActivateAllConnections` | **16.0+** | Promote BLE connections to CoreMIDI |

**Deprecated APIs to avoid:** `MIDIInputPortCreate`, `MIDIInputPortCreateWithBlock`, `MIDIReadProc`, `MIDIReadBlock` — all replaced by `MIDIInputPortCreateWithProtocol` + `MIDIReceiveBlock`. The deprecated APIs use the old `MIDIPacketList`; the modern API uses `MIDIEventList` (Universal MIDI Packets).

**No iOS 26-specific CoreMIDI additions** were found. The framework has been stable since the iOS 14–16 modernization cycle.

_Sources: [Apple MIDIInputPortCreateWithProtocol](https://developer.apple.com/documentation/coremidi/3566488-midiinputportcreatewithprotocol), [Core MIDI Updates](https://developer.apple.com/documentation/updates/coremidi)_

### MIDI 2.0 / Universal MIDI Packets

CoreMIDI automatically converts between MIDI 1.0 and 2.0 protocols. If you create a port with `._1_0`, all incoming messages arrive as **MIDI-1UP** (MIDI 1.0 in Universal MIDI Packet format) regardless of the source device's native protocol. For receiving Note On/Off for training purposes, **MIDI 1.0 protocol is sufficient and simpler** — 7-bit velocity (0–127) is adequate when the goal is "a note was played and when."

_Source: [Incorporating MIDI 2 into your apps (Apple)](https://developer.apple.com/documentation/coremidi/midi_services/incorporating_midi_2_into_your_apps/)_

### Transport Types and Latency

| Transport | Input Latency | Jitter | Timestamp Behavior |
|-----------|--------------|--------|-------------------|
| **USB MIDI** | ~1–2 ms (USB polling) | ≤1 ms | Host arrival time (~100 µs accuracy) |
| **BLE MIDI** | 11.25–15 ms (iOS connection interval) | 4–14 ms measured | Back-dated from BLE 13-bit ms timestamps |
| **Network MIDI** | Variable (WiFi dependent) | Variable | Host arrival time |

#### USB MIDI
- No extra code needed. USB class-compliant devices appear automatically as CoreMIDI sources via Lightning/USB-C adapter.
- USB polling interval of 1 ms is protocol-specified. CoreMIDI callback overhead is ~20–70 µs on top.
- No special entitlements or permissions required.

_Sources: Stanford CCRMA tests, [Low Latency Wired MIDI with iPad](https://audiocookbook.org/low-latency-wired-midi-with-ipad-and-bitstream-3x/)_

#### Bluetooth MIDI (BLE-MIDI)
- **iOS minimum connection interval: 11.25 ms** (Apple-specified, hard platform limitation).
- Measured latency: 5–6 ms typical device-to-device, but the iOS connection interval dominates.
- BLE-MIDI spec includes a **13-bit millisecond timestamp** mechanism. CoreMIDI uses these to reconstruct original event timing, back-dating `MIDITimeStamp` values accordingly.
- **Auto-reconnect (iOS 16+):** Devices that support BLE pairing reconnect automatically.
- **Manual connection (iOS 16+):** Use CoreBluetooth scan + `MIDIBluetoothDriverActivateAllConnections()`.
- **Legacy:** `CABTMIDICentralViewController` for system pairing UI (still works, superseded).

_Sources: [Apple MIDI Bluetooth Documentation](https://developer.apple.com/documentation/coremidi/midi-bluetooth), [CME BLE-MIDI measurements](https://www.cme-pro.com/the-truth-about-bluetooth-midi/), [Gearspace BLE-MIDI measurement thread](https://gearspace.com/board/music-computers/1129003-ble-midi-bluetooth-midi-latency-measurement.html)_

#### Network MIDI (MIDINetworkSession)
- Built into CoreMIDI, uses RTP-MIDI (AppleMIDI) protocol over WiFi/Ethernet.
- **iOS limitation:** iOS devices cannot initiate sessions — they must be invited by another host.
- Available since iOS 4.2.

_Source: [MIDINetworkSession Documentation](https://developer.apple.com/documentation/coremidi/midinetworksession)_

### MIDITimeStamp Behavior

`MIDITimeStamp` is a `UInt64` in host ticks from `mach_absolute_time()`.

- **USB MIDI:** Timestamp ≈ arrival time. Difference from current host time is ~100 µs.
- **BLE MIDI:** Timestamp is **back-dated** to reconstruct original event time from BLE timestamps. Difference from current host time can be >450 ms. This is intentional — it preserves inter-event timing despite connection-interval jitter.
- For timing-sensitive training, **capture `MIDITimeStamp` inside the callback** before dispatching to another thread, to avoid scheduling jitter.

_Sources: [Kymatica iOS MIDI Timestamps](http://devnotes.kymatica.com/ios_midi_timestamps.html), [Apple MIDITimeStamp Documentation](https://developer.apple.com/documentation/coremidi/miditimestamp)_

### Threading Model

CoreMIDI creates a **dedicated high-priority receive thread** for callbacks (tagged `MIDI_REALTIME_API`).

- Callback runs on this thread, **not the main thread**.
- Real-time safety rules apply: no allocations, no ObjC messaging, no locks, no I/O.
- Must dispatch to `@MainActor` for UI updates.
- For timing measurements: capture `MIDITimeStamp` in the callback, use a **lock-free queue** (ring buffer) to pass events to the processing/UI thread.

_Sources: [Apple MIDIInputPortCreateWithProtocol docs](https://developer.apple.com/documentation/coremidi/3566488-midiinputportcreatewithprotocol), [Modern CoreMIDI Event Handling (Furnace Creek)](https://furnacecreek.org/blog/2024-04-06-modern-coremidi-event-handling-with-swift)_

### Swift Ergonomics Pain Points

Using CoreMIDI directly from Swift has friction:

1. **`MIDIEventListForEachEvent` requires a C function pointer**, not a Swift closure — cannot capture context. Requires a `withoutActuallyEscaping` + `Unmanaged` workaround.
2. Manual byte parsing for message types (checking status bytes).
3. No type safety on MIDI messages.
4. Boilerplate for endpoint enumeration and hot-plug handling.

_Source: [Modern CoreMIDI Event Handling with Swift (Furnace Creek, 2024)](https://furnacecreek.org/blog/2024-04-06-modern-coremidi-event-handling-with-swift)_

### Third-Party Libraries

#### MIDIKit (orchetect/MIDIKit) — Best Option

| Attribute | Value |
|---|---|
| **URL** | https://github.com/orchetect/MIDIKit |
| **License** | MIT |
| **Last release** | v0.11.0, February 2, 2026 (threading overhaul) |
| **Activity** | 1,751+ commits, 87+ releases, actively maintained |
| **Swift** | 6.0, strict concurrency compliant (`@Sendable`, `Mutex`) |
| **iOS minimum** | iOS 12+ |
| **MIDI 2.0 / UMP** | Full support, automatic protocol negotiation |
| **Latency overhead** | None — thin wrapper over CoreMIDI |
| **Modular** | `MIDIKitCore`, `MIDIKitIO`, `MIDIKitSMF`, `MIDIKitSync` — import only what you need |

API example for receiving notes:
```swift
try midiManager.addInput(
    name: "My Input",
    tag: "myInput",
    uniqueID: .userDefaultsManaged(key: "myInput"),
    receiver: .events(options: [.filterActiveSensingAndClock]) { events, timeStamp, source in
        for event in events {
            switch event {
            case .noteOn(let payload):  // strongly typed
            case .noteOff(let payload): // strongly typed
            default: break
            }
        }
    }
)
```

_Sources: [MIDIKit GitHub](https://github.com/orchetect/MIDIKit), [MIDIKit Documentation](https://orchetect.github.io/MIDIKit/), [Swift Package Index](https://swiftpackageindex.com/orchetect/MIDIKit)_

#### AudioKit — Not Recommended for MIDI-Only Use

| Attribute | Value |
|---|---|
| **Last release** | v5.6.5, March 2025 |
| **Swift** | 5.9, **not** Swift 6 concurrency compliant |
| **MIDI 2.0** | No — uses old `MIDIPacketList` API internally |
| **Scope** | Full audio synthesis framework; MIDI is secondary |

Heavy dependency for MIDI-only use. Delegate-based API is less ergonomic than MIDIKit.

_Source: [AudioKit GitHub](https://github.com/AudioKit/AudioKit)_

#### Others (Not Suitable)

- **MIKMIDI** — Dormant since June 2022, Objective-C based. Not suitable.
- **Gong**, **swift-midi**, **WebMIDIKit** — Abandoned/dormant. Not suitable.

### Technology Adoption Trends

- **No WWDC sessions on MIDI** from 2023–2025. The last significant CoreMIDI session was WWDC 2021 (MIDI 2.0/UMP introduction).
- The CoreMIDI API has been stable since iOS 14–16. Apple appears to consider it mature.
- MIDIKit has emerged as the de facto community standard for Swift MIDI development, filling the ergonomics gap Apple has not addressed.
- Raw CoreMIDI remains viable (~50–80 lines of setup) but MIDIKit eliminates the C-bridging boilerplate and adds type safety.

## Integration Patterns Analysis

### Permissions, Entitlements, and Session Requirements

| Concern | Required? | Notes |
|---------|-----------|-------|
| AVAudioSession | **No** (for MIDI input alone) | CoreMIDI is independent of the audio stack. Peach already has AVAudioSession for playback — no additional configuration needed for MIDI input. |
| `UIBackgroundModes: audio` | **No** for input ports | Only required if creating virtual MIDI endpoints (`MIDISourceCreate`/`MIDIDestinationCreate`). Receiving from physical devices in foreground needs nothing. |
| iOS Entitlements | **None** | macOS has `com.apple.security.device.midi` for sandbox, but iOS has no equivalent. |
| Info.plist privacy keys | **None** | No `NSMIDIUsageDescription` exists — unlike camera/microphone, no user permission prompt for MIDI. |
| Background MIDI | **Not needed** | Foreground training app. MIDI callbacks stop when app is suspended. |

_Sources: [iOS 6.0 Release Notes — CoreMIDI UIBackgroundModes](https://developer.apple.com/library/archive/releasenotes/General/RN-iOSSDK-6_0/index.html), [Apple MIDISourceCreate docs](https://developer.apple.com/documentation/coremidi/1495212-midisourcecreate)_

### Device Lifecycle and Hot-Plug

CoreMIDI provides setup change notifications through the client creation API:

```swift
MIDIClientCreateWithBlock("Peach" as CFString, &clientRef) { notification in
    switch notification.pointee.messageID {
    case .msgSetupChanged:   // catch-all for any setup change
    case .msgObjectAdded:    // new device/entity/endpoint appeared
    case .msgObjectRemoved:  // device/entity/endpoint disappeared
    case .msgIOError:        // driver I/O error
    default: break
    }
}
```

**Key notification types:**

| Case | Meaning | Cast to |
|------|---------|---------|
| `.msgSetupChanged` | Any MIDI setup change | `MIDINotification` |
| `.msgObjectAdded` | Device/endpoint appeared | `MIDIObjectAddRemoveNotification` |
| `.msgObjectRemoved` | Device/endpoint disappeared | `MIDIObjectAddRemoveNotification` |
| `.msgPropertyChanged` | Property on MIDI object changed | `MIDIObjectPropertyChangeNotification` |

**Hotplug pattern:** On `.msgSetupChanged`, re-enumerate sources via `MIDIGetNumberOfSources()` and reconnect input port to any new sources. Threading note: notification arrives on the run loop where `MIDIClientCreate` was called.

**MIDIKit simplification:** MIDIKit's managed connections (`addInputConnection`) handle reconnection automatically. When a device disappears and reappears, managed connections re-establish themselves. Endpoints are identified by `uniqueID` with display-name fallback.

_Sources: [Apple MIDINotificationMessageID docs](https://developer.apple.com/documentation/coremidi/midinotificationmessageid), [MIDIKit GitHub](https://github.com/orchetect/MIDIKit)_

### CoreMIDI Callback → Application Thread Bridge

The receive callback runs on CoreMIDI's high-priority thread (real-time constraints). For timing-sensitive training, the integration pattern is:

```
┌──────────────────────┐     lock-free      ┌──────────────────────┐
│  CoreMIDI RT Thread  │ ──── queue ──────→ │  Processing Thread   │
│  (MIDIReceiveBlock)  │  (ring buffer or   │  (MainActor or       │
│  • capture timestamp │   Mutex<[Event]>)  │   dedicated actor)   │
│  • extract note/vel  │                    │  • compare timing    │
│  • enqueue event     │                    │  • update UI         │
└──────────────────────┘                    └──────────────────────┘
```

**Rules for the callback thread:**
- No allocations, no ObjC messaging, no locks (use `OSAllocatedUnfairLock` or `Mutex` from Synchronization framework)
- No file I/O, no logging
- Capture `MIDITimeStamp` immediately — do not defer timestamp capture to another thread
- Keep callback execution under ~100 µs

**MIDIKit approach:** MIDIKit's receive handler already runs on the CoreMIDI thread. You get strongly-typed `MIDIEvent` values with the timestamp. Dispatch to `@MainActor` for UI updates.

_Sources: [Apple MIDIInputPortCreateWithProtocol docs](https://developer.apple.com/documentation/coremidi/3566488-midiinputportcreatewithprotocol), [Kymatica iOS MIDI Timestamps](http://devnotes.kymatica.com/ios_midi_timestamps.html)_

### Integration with Peach's Core/Ports Architecture

Peach uses a **pure protocol-based port pattern** where hardware dependencies are abstracted in `Core/Ports/` and wired in the composition root (`PeachApp`).

**Existing pattern summary:**

```
Core/Ports/       → Protocol definitions only (NotePlayer, RhythmPlayer, etc.)
Core/Audio/       → Implementations (SoundFontPlayer, SoundFontEngine)
App/EnvironmentKeys.swift → @Entry declarations with preview defaults
App/PeachApp.swift        → Composition root, wires production instances
```

**How MIDI input fits:**

1. **New port protocol** in `Core/Ports/` — defines what sessions need from MIDI input (note events with timestamps), using existing domain types (`MIDINote`, `MIDIVelocity`)
2. **Implementation** in `Core/Audio/` (or `Core/MIDI/`) — wraps CoreMIDI or MIDIKit, handles device enumeration and hot-plug
3. **`@Entry` in EnvironmentKeys** — optional port (`(any MIDIInput)?`) with `nil` default, since not all training disciplines need MIDI
4. **Wired in PeachApp** — production instance created in `init()`, injected via `.environment()`
5. **Sessions consume via `@Environment`** — training sessions that accept MIDI input receive the port; others ignore it
6. **Testable with mock** — `PreviewMIDIInput` or `MockMIDIInput` for tests and SwiftUI previews

**Key design consideration:** The port protocol should expose an `AsyncSequence` of note events (or a callback-based API matching the existing async/await pattern) rather than requiring the session to manage CoreMIDI lifecycle directly. This keeps the session focused on training logic.

**Existing relevant domain types** (in `Core/Music/`):
- `MIDINote` — note number wrapper
- `MIDIVelocity` — velocity wrapper
- `Frequency` — frequency value type (for pitch comparison)

_Source: Project codebase analysis (Core/Ports/, Core/Audio/, App/)_

### "Receive Any Note on Any Channel" Strategy

To receive from all connected MIDI devices on all channels:

```swift
// Connect ALL sources to the input port
let sourceCount = MIDIGetNumberOfSources()
for i in 0..<sourceCount {
    MIDIPortConnectSource(inputPort, MIDIGetSource(i), nil)
}
```

No channel filtering is applied at the CoreMIDI level. The callback receives every Note On/Off from every connected device. Channel/note filtering (if ever needed) is applied at the application layer — which aligns with the research goal of deferring settings to later.

With MIDIKit, the equivalent is `addInputConnection` with a filter criteria of `.init()` (no filter = accept all).

### Summary: What Is Actually Needed

For a minimal foreground MIDI input integration:

| Step | What | Complexity |
|------|------|-----------|
| 1 | Add MIDIKit SPM dependency (`MIDIKitIO` target only) | Trivial |
| 2 | Define `MIDIInput` port protocol in `Core/Ports/` | Small |
| 3 | Implement adapter wrapping `MIDIManager` in `Core/Audio/` | Medium |
| 4 | Wire in composition root + `@Entry` | Small |
| 5 | Handle hot-plug (MIDIKit does this automatically) | Free with MIDIKit |
| 6 | Bridge note events to training session | Medium |

No entitlements, no Info.plist changes, no AVAudioSession configuration, no background modes.

## Architectural Patterns and Design

### Threading Architecture: CoreMIDI → Swift Concurrency

The critical architectural question is how MIDI events flow from CoreMIDI's high-priority thread into Swift's structured concurrency world.

**CoreMIDI callback thread classification:** The CoreMIDI receive callback runs on a "high-priority" thread that is **not** a true real-time audio render thread. It does not have the same strict constraints as `AVAudioEngine`'s render callback. Blocking here delays MIDI delivery across all apps, but does not cause audio glitches. This distinction matters for choosing the right synchronization mechanism.

**MIDIKit's built-in threading bridge (key finding):**

MIDIKit already dispatches events off the CoreMIDI thread. Inside `MIDIInputPortCreateWithProtocol`'s callback, MIDIKit:
1. Parses packet data (lightweight struct operations, on CoreMIDI thread)
2. Dispatches via `queue.async` to a **dedicated serial DispatchQueue** per connection
3. Calls your `MIDIReceiver` handler on that serial queue

This means your handler code runs on a normal-priority serial queue, **not** on the CoreMIDI thread. You can safely do Swift allocations, call actors, use `yield`, etc.

_Sources: [MIDIKit source: MIDIInputConnection.swift](https://github.com/orchetect/MIDIKit), [Loopy Pro Forum: Is Swift enough for MIDI-based app?](https://forum.loopypro.com/discussion/47686/is-swift-enough-for-developing-midi-based-app)_

### AsyncStream as the Event Bridge

**Can AsyncStream bridge MIDI events to Swift concurrency?**

- **Not from the CoreMIDI RT thread** — `AsyncStream.Continuation.yield()` contends on an internal mutex (`__ulock_wait`), risking priority inversion.
- **Yes from MIDIKit's dispatch queue** — since MIDIKit already dispatches to a serial queue, calling `yield()` there is safe and idiomatic.

**Recommended event flow:**

```
┌─────────────────────┐
│ CoreMIDI RT Thread   │  ← MIDIKit handles this internally
│ (packet parsing)     │
└──────────┬──────────┘
           │ queue.async
┌──────────▼──────────┐
│ MIDIKit Serial Queue │  ← Your handler runs here
│ • map to domain type │
│ • yield into stream  │
└──────────┬──────────┘
           │ AsyncStream
┌──────────▼──────────┐
│ Swift Concurrency    │  ← Training session consumes here
│ • for await event    │
│ • timing analysis    │
│ • UI updates         │
└─────────────────────┘
```

**No lock-free ring buffer needed** for this use case. MIDIKit's DispatchQueue bridge is sufficient for a training app receiving note events from external controllers.

_Sources: [Performance of AsyncStream — Swift Forums](https://forums.swift.org/t/performance-of-asyncstream/63668), [MIDIKit Discussion #184](https://github.com/orchetect/MIDIKit/discussions/184)_

### Timestamp Handling Architecture

`MIDITimeStamp` is a `UInt64` identical to `mach_absolute_time()` — host clock ticks. Conversion to usable time values:

```swift
// Cache timebase info (call once at init)
var info = mach_timebase_info_data_t()
mach_timebase_info(&info)

// Convert ticks to nanoseconds
func machTicksToNanoseconds(_ ticks: UInt64) -> UInt64 {
    ticks * UInt64(info.numer) / UInt64(info.denom)
}

// Convert to Swift Duration
func machTicksToDuration(_ ticks: UInt64) -> Duration {
    .nanoseconds(machTicksToNanoseconds(ticks))
}

// Relative timing between two events
func timeBetween(_ ts1: MIDITimeStamp, _ ts2: MIDITimeStamp) -> Duration {
    let deltaTicks = ts2 > ts1 ? ts2 - ts1 : ts1 - ts2
    return machTicksToDuration(deltaTicks)
}
```

**Key facts:**
- Timebase ratio varies by hardware: 125/3 on iOS devices (~41.67 ns/tick), 1/1 on simulator
- `mach_timebase_info()` must be called once and cached
- `ContinuousClock.now` uses the same underlying clock — usable for comparison
- On iOS, `AudioGetCurrentHostTime()` is unavailable; use `mach_absolute_time()` directly

**Timestamp semantics by transport:**
- **USB MIDI:** Timestamp ≈ arrival time (~100 µs accuracy). Reliable for inter-event timing.
- **BLE MIDI:** Timestamp is **back-dated** using BLE-MIDI's 13-bit ms timestamps to reconstruct original event time. The back-dating is done by CoreMIDI automatically. Inter-event timing is preserved despite connection interval jitter.

**Architectural implication:** For timing-sensitive training (e.g., rhythm accuracy), always use `MIDITimeStamp` differences between events rather than wall-clock time. This gives sub-millisecond precision for USB and ~1 ms precision for BLE (limited by BLE-MIDI's 1 ms timestamp resolution).

_Sources: [Apple TN QA1398: Mach Absolute Time Units](https://developer.apple.com/library/archive/qa/qa1398/_index.html), [Kymatica iOS MIDI Timestamps](http://devnotes.kymatica.com/ios_midi_timestamps.html), [Precision Timing in iOS](https://kandelvijaya.com/2016/10/25/precisiontiminginios/)_

### Port Protocol Design Options

Two viable patterns for the `MIDIInput` port protocol, considering Peach's existing async/await conventions:

**Option A: AsyncSequence-based (recommended)**

```swift
protocol MIDIInput {
    /// Stream of note events from all connected MIDI devices.
    var noteEvents: AsyncStream<MIDINoteEvent> { get }

    /// Whether any MIDI source is currently connected.
    var isConnected: Bool { get }
}

struct MIDINoteEvent: Sendable {
    let note: MIDINote
    let velocity: MIDIVelocity
    let timestamp: MIDITimeStamp   // raw host ticks for precision
    let isNoteOn: Bool
}
```

- Fits naturally with `for await event in midiInput.noteEvents`
- Session controls lifetime by cancelling the consuming Task
- Testable: mock yields events on demand
- MIDIKit handler calls `continuation.yield(event)` on its serial queue

**Option B: Callback-based (simpler, mirrors existing NotePlayer pattern)**

```swift
protocol MIDIInput {
    func start(handler: @escaping @Sendable (MIDINoteEvent) -> Void) async throws
    func stop() async
    var isConnected: Bool { get }
}
```

- Closer to existing port patterns (NotePlayer uses async functions)
- Explicit lifecycle (start/stop)
- Handler called on MIDIKit's serial queue; session dispatches to @MainActor as needed

**Recommendation:** Option A (AsyncSequence) is more idiomatic for modern Swift and cleaner for consumption in training sessions. The port implementation manages MIDIKit lifecycle internally; the consuming session just iterates the stream.

### Synchronization Primitives

| Primitive | RT-Safe? | Use Case |
|-----------|----------|----------|
| `Synchronization.Mutex` (SE-0433) | No (wraps `os_unfair_lock`) | Fine for MIDIKit handler → actor bridge |
| `OSAllocatedUnfairLock` | No | Same as Mutex, existing Peach pattern |
| Lock-free SPSC ring buffer | Yes | Only needed for AUv3/audio render thread |
| `AsyncStream.Continuation` | No | Fine from MIDIKit's serial queue |
| `DispatchQueue.async` | No | MIDIKit's internal bridge pattern |

For Peach's use case (external MIDI controller → training session), **no RT-safe primitives are needed**. MIDIKit handles the RT thread internally.

_Sources: [Swift Synchronization Framework (SE-0433)](https://www.swift.org/blog/synchronization/), [timur.audio: Using locks in RT audio](https://timur.audio/using-locks-in-real-time-audio-processing-safely)_

### Latency Budget Analysis

For a timing-sensitive training discipline (e.g., rhythm accuracy assessment):

| Stage | USB MIDI | BLE MIDI |
|-------|----------|----------|
| **1. Physical transport** | ~1 ms (USB polling) | 11.25–15 ms (connection interval) |
| **2. CoreMIDI → MIDIKit dispatch** | ~0.1 ms | ~0.1 ms |
| **3. MIDIKit handler → AsyncStream** | ~0.01 ms | ~0.01 ms |
| **4. Swift Task scheduling** | ~0.1–1 ms | ~0.1–1 ms |
| **Total to training logic** | **~1.2–2.1 ms** | **~11.5–16.1 ms** |

**Timing precision** (what matters for training accuracy):
- USB: Sub-millisecond inter-event precision via `MIDITimeStamp` deltas
- BLE: ~1 ms inter-event precision (BLE-MIDI timestamp resolution)

For rhythm training where the app compares a player's timing against an expected beat, **USB MIDI provides more than adequate precision**. BLE MIDI is usable but the 1 ms timestamp resolution and higher jitter make it less ideal for precision rhythm training.

### Design Decision: MIDIKit vs Raw CoreMIDI

| Factor | MIDIKit | Raw CoreMIDI |
|--------|---------|-------------|
| **Setup code** | ~10 lines | ~50–80 lines |
| **C-bridging boilerplate** | None | `MIDIEventListForEachEvent` workaround, `Unmanaged` pointers |
| **Type safety** | Strongly-typed `MIDIEvent` enum | Manual byte parsing |
| **Hot-plug handling** | Automatic reconnection | Manual re-enumeration |
| **Threading** | Dispatches off RT thread for you | Must implement yourself |
| **Timestamp access** | Provided in handler | Available in callback |
| **Dependency cost** | ~1 SPM package (`MIDIKitIO`) | None |
| **Swift 6 concurrency** | Fully compliant | Manual compliance required |
| **Latency overhead** | None measurable | Baseline |

**Recommendation: MIDIKit.** The threading bridge alone justifies the dependency. The C-bridging boilerplate for `MIDIEventListForEachEvent` is fragile and error-prone. MIDIKit is MIT-licensed, modular (import only `MIDIKitIO`), and actively maintained with Swift 6 strict concurrency compliance.

_Sources: [MIDIKit GitHub](https://github.com/orchetect/MIDIKit), [Modern CoreMIDI Event Handling (Furnace Creek)](https://furnacecreek.org/blog/2024-04-06-modern-coremidi-event-handling-with-swift)_

## Implementation Approaches

### Minimal MIDIKit Setup: "Receive Any Note From Any Device"

```swift
import MIDIKitIO

let midiManager = ObservableMIDIManager(
    clientName: "Peach",
    model: "Peach",
    manufacturer: "Peach"
)

try midiManager.start()

try midiManager.addInputConnection(
    to: .allOutputs,  // connects to ALL MIDI outputs in the system
    tag: "main",
    filter: .default(),
    receiver: .events(options: [.filterActiveSensingAndClock]) { events, timeStamp, source in
        for event in events {
            switch event {
            case .noteOn(let payload):
                // payload.note, payload.velocity, payload.channel
            case .noteOff(let payload):
                // payload.note, payload.velocity, payload.channel
            default:
                break
            }
        }
    }
)
```

**Key API choices:**

| API | Purpose |
|-----|---------|
| `ObservableMIDIManager` | SwiftUI-observable wrapper (endpoint lists update automatically) |
| `.allOutputs` | Auto-connects to every MIDI source; handles hot-plug automatically |
| `.filterActiveSensingAndClock` | Drops high-frequency timing messages irrelevant to note input |
| `.events` receiver | Closure-based, receives strongly-typed `[MIDIEvent]` with timestamp |
| `MIDIInputConnectionMode` | Also supports `.outputs(matching:)` for specific endpoints, `.none` for manual |

**MIDIKit products to import:**
- `MIDIKitIO` — I/O only (manager, connections, virtual endpoints). This is all Peach needs.
- `MIDIKitUI` — Optional, for SwiftUI endpoint picker views

_Source: [MIDIKit EndpointPickers example](https://github.com/orchetect/MIDIKit/blob/main/Examples/SwiftUI%20Multiplatform/EndpointPickers/EndpointPickers/MIDIHelper.swift)_

### SPM Dependency

```swift
// Package.swift or Xcode "Add Package Dependencies"
.package(url: "https://github.com/orchetect/MIDIKit", from: "0.11.0")

// Target dependency
.product(name: "MIDIKitIO", package: "MIDIKit")
```

Requirements: Xcode 16+, iOS 12+ (Peach targets iOS 26, well within range).

_Source: [MIDIKit GitHub](https://github.com/orchetect/MIDIKit)_

### Testing Strategy

**Critical constraint: iOS Simulator does NOT support CoreMIDI.** MIDIKit's own test suite explicitly skips real MIDI tests on the simulator:

```swift
#if !targetEnvironment(simulator)
// integration tests here
#endif
```

Creating virtual MIDI endpoints fails with permission errors on the simulator. This is an Apple platform limitation, not a MIDIKit issue.

**Recommended three-tier testing approach for Peach:**

| Tier | Runs On | What It Tests | How |
|------|---------|---------------|-----|
| **1. Domain logic** | Simulator + Device | Training session timing logic, event processing | Mock `MIDIInput` port protocol — inject fake `MIDINoteEvent` values |
| **2. Adapter unit tests** | Simulator + Device | Event mapping, timestamp conversion, domain type bridging | Test pure functions that transform `MIDIEvent` → `MIDINoteEvent` |
| **3. Integration tests** | Device only | Real MIDIKit ↔ CoreMIDI round-trip | Virtual output → input connection loopback, gated by `#if !targetEnvironment(simulator)` |

**Tier 1 is the most important** and covers the training logic that matters. The port protocol boundary means all timing-sensitive training logic can be tested without any MIDI hardware or framework dependencies.

**Example mock for Tier 1 testing:**

```swift
struct MockMIDIInput: MIDIInput {
    let events: [MIDINoteEvent]

    var noteEvents: AsyncStream<MIDINoteEvent> {
        AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    var isConnected: Bool { true }
}
```

**Virtual MIDI for Tier 3 (device only):**

MIDIKit supports creating virtual MIDI sources for testing on real devices:

```swift
try midiManager.addOutput(
    name: "Test Source",
    tag: "testSource",
    uniqueID: .adHoc  // system-generated, no persistence
)
```

Use `.adHoc` unique IDs in tests (no UserDefaults persistence) vs `.userDefaultsManaged` in production.

_Sources: [MIDIKit Round Trip Tests](https://github.com/orchetect/MIDIKit/blob/main/Tests/MIDIKitIOTests/Integration%20Tests/Round%20Trip%20Tests.swift), [MIDIKit VirtualInput example](https://github.com/orchetect/MIDIKit/blob/main/Examples/SwiftUI%20Multiplatform/VirtualInput/VirtualInput/MIDIHelper.swift)_

### Implementation Gotchas

| Gotcha | Impact | Mitigation |
|--------|--------|-----------|
| **Simulator has no MIDI** | Cannot test real MIDI I/O in CI | Protocol boundary + mocks for domain tests; device-only integration tests |
| **CoreMIDI endpoint readiness** | Virtual endpoints need ~200 ms after creation before they're usable | MIDIKit handles this for managed connections; for tests, add warm-up phase |
| **Swift 6 `@Sendable` closures** | MIDIKit receiver closures are `@Sendable` | Dispatch to `@MainActor` via `Task { @MainActor in ... }` for UI updates |
| **UniqueID persistence** | Virtual endpoints need stable IDs across app launches | Use `.userDefaultsManaged(key:)` in production |
| **BLE MIDI back-dated timestamps** | `MIDITimeStamp` can be >400 ms in the past | Use timestamp deltas for inter-event timing, not absolute comparisons |

### Implementation Roadmap

| Phase | Scope | Deliverable |
|-------|-------|-------------|
| **1. Foundation** | Add MIDIKit SPM dependency, define `MIDIInput` port protocol, create adapter | Protocol + adapter + `@Entry` wiring |
| **2. Verification** | Integration test on device: receive notes from physical MIDI controller | Confirmed end-to-end data flow |
| **3. Training integration** | Wire `MIDIInput` into first timing-sensitive training session | Session uses `for await event in midiInput.noteEvents` |
| **4. Settings (deferred)** | Channel filter, device selection, BLE pairing UI | Future scope per research brief |

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| MIDIKit abandoned | Low (very active, 87+ releases) | High | Port protocol abstracts dependency; can swap to raw CoreMIDI |
| BLE MIDI latency too high for rhythm training | Medium | Medium | Recommend USB for precision; BLE acceptable for pitch-only |
| iOS Simulator limitation blocks CI | Medium | Low | Mock-based testing covers domain logic; integration tests on device |
| CoreMIDI API deprecation | Very Low | Low | Apple stable since iOS 14; MIDIKit tracks changes |

## Research Synthesis and Conclusion

### Answer to the Research Question

**"What is necessary to support MIDI input for timing-sensitive training disciplines?"**

Surprisingly little. The core requirements are:

1. **One SPM dependency** — `MIDIKitIO` (MIT, Swift 6, actively maintained)
2. **~15 lines of setup code** — `ObservableMIDIManager` + `addInputConnection(to: .allOutputs)` + event handler
3. **One new port protocol** — `MIDIInput` in `Core/Ports/`, following existing patterns
4. **One adapter implementation** — wrapping MIDIKit, bridging to `AsyncStream<MIDINoteEvent>`
5. **Standard composition root wiring** — `@Entry` + `.environment()` in `PeachApp`

No entitlements, no Info.plist changes, no AVAudioSession configuration, no background modes, no special permissions. A MIDI controller plugged in via USB-C works immediately.

### Confidence Assessment

| Claim | Confidence | Basis |
|-------|-----------|-------|
| CoreMIDI is the sole iOS MIDI framework | **High** | Apple documentation, SDK headers |
| USB MIDI latency ~1–2 ms | **High** | USB spec (1 ms polling), CoreMIDI SDK, multiple independent measurements |
| BLE MIDI iOS connection interval ≥11.25 ms | **High** | Apple Bluetooth Design Guidelines, CME measurements |
| MIDIKit dispatches off RT thread | **High** | Verified in MIDIKit source code (`MIDIInputConnection.swift`) |
| AsyncStream safe from MIDIKit's serial queue | **High** | MIDIKit dispatches to DispatchQueue before handler; yield is on normal thread |
| No MIDI on iOS Simulator | **High** | MIDIKit test suite guards, community reports, Apple platform behavior |
| MIDITimeStamp sub-ms precision for USB | **High** | Apple TN QA1398, Kymatica developer notes, Stanford CCRMA tests |
| BLE-MIDI timestamp 1 ms resolution | **High** | BLE-MIDI 1.0 specification (13-bit ms timestamp) |
| No iOS 26-specific CoreMIDI changes | **Medium** | SDK header scan + documentation check; absence of evidence ≠ evidence of absence |

### Source Documentation

**Apple Documentation:**
- [CoreMIDI Framework](https://developer.apple.com/documentation/coremidi/)
- [MIDIInputPortCreateWithProtocol](https://developer.apple.com/documentation/coremidi/3566488-midiinputportcreatewithprotocol)
- [MIDIReceiveBlock](https://developer.apple.com/documentation/coremidi/midireceiveblock)
- [MIDITimeStamp](https://developer.apple.com/documentation/coremidi/miditimestamp)
- [MIDINotificationMessageID](https://developer.apple.com/documentation/coremidi/midinotificationmessageid)
- [MIDI Bluetooth](https://developer.apple.com/documentation/coremidi/midi-bluetooth)
- [Incorporating MIDI 2 into Your Apps](https://developer.apple.com/documentation/coremidi/midi_services/incorporating_midi_2_into_your_apps/)
- [Core MIDI Updates](https://developer.apple.com/documentation/updates/coremidi)
- [MIDINetworkSession](https://developer.apple.com/documentation/coremidi/midinetworksession)
- [Apple TN QA1398: Mach Absolute Time Units](https://developer.apple.com/library/archive/qa/qa1398/_index.html)
- [iOS 6.0 Release Notes (UIBackgroundModes)](https://developer.apple.com/library/archive/releasenotes/General/RN-iOSSDK-6_0/index.html)

**MIDIKit:**
- [GitHub Repository](https://github.com/orchetect/MIDIKit)
- [Documentation](https://orchetect.github.io/MIDIKit/)
- [Swift Package Index](https://swiftpackageindex.com/orchetect/MIDIKit)
- [Discussion #184: SwiftUI Integration](https://github.com/orchetect/MIDIKit/discussions/184)

**Latency Measurements and Timing:**
- [Kymatica iOS MIDI Timestamps](http://devnotes.kymatica.com/ios_midi_timestamps.html)
- [CME: The Truth About Bluetooth MIDI](https://www.cme-pro.com/the-truth-about-bluetooth-midi/)
- [Gearspace BLE-MIDI Latency Measurement](https://gearspace.com/board/music-computers/1129003-ble-midi-bluetooth-midi-latency-measurement.html)
- [Sample Accurate MIDI Timing in AUv3 (cp3.io)](https://cp3.io/posts/sample-accurate-midi-timing/)
- [Precision Timing in iOS](https://kandelvijaya.com/2016/10/25/precisiontiminginios/)

**Architecture and Implementation:**
- [Modern CoreMIDI Event Handling with Swift (Furnace Creek, 2024)](https://furnacecreek.org/blog/2024-04-06-modern-coremidi-event-handling-with-swift)
- [Performance of AsyncStream — Swift Forums](https://forums.swift.org/t/performance-of-asyncstream/63668)
- [Using Locks in Real-Time Audio Processing (timur.audio)](https://timur.audio/using-locks-in-real-time-audio-processing-safely)
- [Loopy Pro Forum: Is Swift Enough for MIDI Apps?](https://forum.loopypro.com/discussion/47686/is-swift-enough-for-developing-midi-based-app)

**Specifications:**
- [BLE-MIDI 1.0 Specification](https://www.hangar42.nl/wp-content/uploads/2017/10/BLE-MIDI-spec.pdf)
- [Nordic Semiconductor: Optimizing BLE-MIDI Timing](https://devzone.nordicsemi.com/nordic/nordic-blog/b/blog/posts/optimizing-ble-midi-with-regards-to-timing-1293631358)

---

**Research Completion Date:** 2026-03-26
**Source Verification:** All technical claims cited with current sources; CoreMIDI SDK headers verified; MIDIKit source code examined
**Confidence Level:** High — based on multiple authoritative sources with cross-validation

# AVAudioSession (iOS Lifecycle)

`AVAudioSession` is iOS / tvOS / watchOS / visionOS only. On macOS the audio session is implicit; use `AVAudioEngine` directly and observe device changes via Core Audio (`AudioObjectAddPropertyListener`).

The session arbitrates audio between your app and the system (music app, calls, Siri, alarms, other apps). It owns the route choice (speaker, headphones, BT, AirPlay) and the activation state.

## Categories

`AVAudioSession.Category`:

| Category | Mixes | Records | Route choice | Silenced by ringer/lock |
|---|---|---|---|---|
| `ambient` | yes | no | no | yes |
| `soloAmbient` (default) | no | no | no | yes |
| `playback` | no (mixable via option) | no | yes | **no** |
| `record` | no | yes | yes | no (continues with lock) |
| `playAndRecord` | no (mixable) | yes | yes | no |
| `multiRoute` | no | yes | yes | no — simultaneous distinct routes |

Choose the smallest category that meets your need. `.multiRoute` is rarely correct.

## Modes

`AVAudioSession.Mode` refines I/O routing and DSP (AGC, beamforming, ducking):

- `default`
- `gameChat`
- **`measurement`** — disables system DSP (AGC, beamforming). **Required for tuners, analyzers, scientific recording.** Reduces voice quality.
- `moviePlayback`
- `spokenAudio` — cooperates with other spoken audio via `interruptSpokenAudioAndMixWithOthers`
- `videoChat`
- `videoRecording`
- `voiceChat` — enables echo cancellation, half-duplex AGC
- `voicePrompt`

## Options

`AVAudioSession.CategoryOptions`:

- `mixWithOthers` — let other apps' audio continue.
- `duckOthers` — lower other apps' audio while yours plays.
- `interruptSpokenAudioAndMixWithOthers` — interrupt podcasts/audiobooks, mix with music.
- `allowBluetooth` — HFP — bidirectional, narrowband.
- `allowBluetoothA2DP` — output-only, hi-fi.
- `allowAirPlay`.
- `defaultToSpeaker` — playAndRecord only — routes out of the earpiece.
- `overrideMutedMicrophoneInterruption` (iOS 14.5+).

## Recommended combinations

| Use case | Category | Mode | Options |
|---|---|---|---|
| Synth / instrument | `.playback` | `.default` | none (or `.mixWithOthers` for layering over Music) |
| Podcast / audiobook player | `.playback` | `.spokenAudio` | `.interruptSpokenAudioAndMixWithOthers` |
| Voice assistant | `.playAndRecord` | `.voiceChat` | `[.defaultToSpeaker, .allowBluetooth]` |
| Music production / DAW | `.playAndRecord` | `.measurement` | `.allowBluetoothA2DP` (monitoring) |
| Tuner / pitch detector | `.record` | `.measurement` | none |
| Game with optional bg music | `.ambient` | `.default` | `.mixWithOthers` (then `.soloAmbient` for solo) |

## Activation

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default, options: [])
try session.setActive(true)
```

**Configure category before activation.** Calling `setCategory` while active produces a momentary route change.

Deactivate with `setActive(false, options: .notifyOthersOnDeactivation)` — lets previously-suspended apps (Music, Podcasts) resume. Without it, they remain ducked or stopped. Forgetting this strands other media apps.

**Background audio** requires the **Audio, AirPlay, Picture in Picture** capability in Signing & Capabilities, which adds `audio` to `UIBackgroundModes` in Info.plist. Without it, your session deactivates on backgrounding even if the engine is running.

## Interruption handling

Observe `AVAudioSession.interruptionNotification`. `userInfo`:

- `AVAudioSessionInterruptionTypeKey` → `.began` | `.ended`
- `AVAudioSessionInterruptionReasonKey` (iOS 14.5+) → `.default` (phone call, Siri, timer), `.appWasSuspended` (your app was suspended in background — common false-positive), `.builtInMicMuted`, `.routeDisconnected` (iOS 17+)
- `AVAudioSessionInterruptionOptionKey` (on `.ended` only) → `.shouldResume`

```swift
func handleInterruption(_ note: Notification) {
    guard let info = note.userInfo,
          let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: rawType)
    else { return }
    switch type {
    case .began:
        engine.pause()                   // OS already silenced output
    case .ended:
        let rawOpts = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let opts = AVAudioSession.InterruptionOptions(rawValue: rawOpts)
        guard opts.contains(.shouldResume) else { return }
        try? session.setActive(true)
        try? engine.start()
    @unknown default: break
    }
}
```

**Discipline:**

- Only auto-resume when `.shouldResume` is present. iOS withholds it when the user explicitly redirected audio (e.g., started a different player). Resuming anyway is hostile.
- On iOS 16+, ignore `.began` with reason `.appWasSuspended` — your engine wasn't actually interrupted, just suspended. Treating it as an interruption double-pauses.

## Route change handling

Observe `AVAudioSession.routeChangeNotification`. `AVAudioSessionRouteChangeReasonKey`:

- `.newDeviceAvailable` — e.g., AirPods connected; consider switching.
- `.oldDeviceUnavailable` — **headphones unplugged. Pause** (Apple HIG).
- `.categoryChange` — your own `setCategory` call.
- `.override` — `overrideOutputAudioPort` called.
- `.wakeFromSleep`, `.noSuitableRouteForCategory`, `.routeConfigurationChange`.

```swift
guard reason == .oldDeviceUnavailable,
      let prev = info[AVAudioSessionRouteChangePreviousRouteKey]
              as? AVAudioSessionRouteDescription,
      prev.outputs.contains(where: { $0.portType == .headphones
                                  || $0.portType == .bluetoothA2DP })
else { return }
engine.pause()
```

Inspect `AVAudioSession.sharedInstance().currentRoute.outputs` for the current port (`.builtInSpeaker`, `.headphones`, `.bluetoothA2DP`, `.bluetoothHFP`, `.HDMI`, `.airPlay`, etc.).

**Don't assume** the new route's sample rate matches your previous graph. Wait for `AVAudioEngineConfigurationChangeNotification` and re-read formats.

## Media services reset

`AVAudioSession.mediaServicesWereLostNotification` (audio server died) and `mediaServicesWereResetNotification` (server back).

Rare — typically `mediaserverd` crashed — but catastrophic if unhandled. All audio silently dies for the rest of the process lifetime. On reset, rebuild **everything**:

- Re-set category/mode/options.
- Re-call `setActive(true)`.
- Recreate `AVAudioEngine` and every `AVAudioUnit` / `AVAudioPlayerNode`.
- Reload `AVAudioFile`s — handles are invalid.
- Reattach taps.
- Restore `AVAudioPlayerNode` schedules.

Singletons holding cached `AudioUnit` instances or `AudioComponentInstance` references must be torn down. Treat the engine as if the app just launched.

## macOS equivalents

`AVAudioSession` doesn't exist on macOS. Instead:

- Use `AVAudioEngine` directly.
- Observe device changes via Core Audio (`AudioObjectAddPropertyListener` on `kAudioHardwarePropertyDefaultOutputDevice`, `kAudioDevicePropertyDeviceIsAlive`, etc.).
- `AVAudioEngineConfigurationChangeNotification` still fires and remains the primary engine-level signal for sample-rate / route changes.
- There is no app-level activation / deactivation; the audio system is shared.

## Permissions

- **Microphone**: `NSMicrophoneUsageDescription` in Info.plist. Request with `AVAudioApplication.requestRecordPermission` (iOS 17+) or `AVAudioSession.sharedInstance().requestRecordPermission(_:)` (earlier).
- **Camera (for video+audio recording)**: `NSCameraUsageDescription`.
- **MotionManager (for AirPods head tracking)**: `NSMotionUsageDescription`.

## Common pitfalls

- **Setting category after `setActive(true)`** — glitch. Configure first.
- **`AVAudioEngineConfigurationChangeNotification` after a route change you already handled** — coalesce, don't double-restart.
- **Background audio capability missing** — engine suspends with screen lock.
- **`.measurement` mode for voice apps** — disables AGC; voice sounds bad.
- **`notifyOthersOnDeactivation` forgotten** — other media apps stay stranded.
- **Ignoring `.appWasSuspended` reason** — double-pause when iOS reports a fake interruption.
- **Bluetooth HFP downsampling** — voice routing via HFP forces mono 16 kHz. Don't expect 44.1 kHz stereo on a HFP route.

## Authoritative sources

- AVAudioSession — https://developer.apple.com/documentation/avfaudio/avaudiosession
- Category — https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct
- Mode — https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct
- CategoryOptions — https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions
- setActive(_:options:) — https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)
- interruptionNotification — https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification
- routeChangeNotification — https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification
- mediaServicesWereResetNotification — https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
- AVAudioEngineConfigurationChangeNotification — https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
- WWDC sessions: "Audio Session Configuration Best Practices" (WWDC14 #501), "Understanding Audio Interruptions".

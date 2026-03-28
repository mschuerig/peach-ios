# Story 66.2: Platform-Conditional Audio Session Configuration

Status: draft

## Story

As a **musician using Peach on macOS**,
I want audio playback to work correctly without `AVAudioSession`,
so that I can hear training notes on my Mac just like on my iPhone.

## Acceptance Criteria

1. **Given** `SoundFontEngine` on macOS **When** the engine starts **Then** `AVAudioEngine` initialises and plays audio without calling any `AVAudioSession` API. On iOS, the existing `AVAudioSession` configuration is preserved unchanged.

2. **Given** `AudioSessionInterruptionMonitor` on macOS **When** initialised **Then** it does not register observers for `AVAudioSession.interruptionNotification` or `AVAudioSession.routeChangeNotification` (these don't exist on macOS). Background/foreground observers still function using the injected notification names.

3. **Given** the macOS build **When** a training session is started **Then** the SoundFont (Samples.sf2) loads and notes play through `AVAudioUnitSampler` with correct timbre and timing.

4. **Given** the iOS build **When** tested **Then** all audio behaviour is identical to before — `AVAudioSession` is still configured with `.playback` category and 5ms preferred buffer duration.

5. **Given** the full test suite **When** run on iOS Simulator **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Conditionalise `SoundFontEngine.configureAudioSession()` (AC: #1, #4)
  - [ ] 1.1 Wrap the method body in `#if os(iOS)` — on macOS, `AVAudioEngine` works without session configuration
  - [ ] 1.2 Consider whether macOS needs any audio configuration (e.g., preferred sample rate) — likely not, but verify

- [ ] Task 2: Conditionalise `AudioSessionInterruptionMonitor` (AC: #2)
  - [ ] 2.1 Wrap the `AVAudioSession.interruptionNotification` observer setup in `#if os(iOS)`
  - [ ] 2.2 Wrap the `AVAudioSession.routeChangeNotification` observer setup in `#if os(iOS)`
  - [ ] 2.3 Wrap the corresponding handler methods and `deinit` cleanup in `#if os(iOS)`
  - [ ] 2.4 Background/foreground observers use injected `Notification.Name` — these remain cross-platform

- [ ] Task 3: Verify SF2 playback on macOS (AC: #3)
  - [ ] 3.1 Build and run on Mac
  - [ ] 3.2 Start a pitch comparison training — verify notes play
  - [ ] 3.3 Start rhythm training — verify percussion sounds play
  - [ ] 3.4 Change sound source in Settings — verify preset switching works

- [ ] Task 4: Run full test suite (AC: #5)

## Dev Notes

### Why macOS Doesn't Need `AVAudioSession`

`AVAudioSession` is iOS's mechanism for coordinating audio between apps (e.g., ducking music when a phone call arrives). macOS has no equivalent because:
- macOS has always supported multiple simultaneous audio streams
- There are no phone call interruptions
- The system mixer handles inter-app audio coordination transparently

`AVAudioEngine` itself is fully cross-platform (macOS 10.10+, iOS 8.0+). It just doesn't need session setup on macOS.

### Buffer Duration on macOS

On iOS, we request 5ms (`0.005s`) for low-latency playback. On macOS, the system default buffer size is typically 512 samples (~11ms at 44.1kHz), which is acceptable for ear training. If latency is an issue, it can be configured via `AVAudioEngine.outputNode.auAudioUnit` directly — but this is unlikely to be needed.

### Source File Locations

| File | Path | Change |
|------|------|--------|
| SoundFontEngine | `Peach/Core/Audio/SoundFontEngine.swift:438-444` | `#if os(iOS)` around session config |
| AudioSessionInterruptionMonitor | `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift:54-74` | `#if os(iOS)` around AVAudioSession observers |

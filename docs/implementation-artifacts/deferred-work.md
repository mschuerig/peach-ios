# Deferred Work

## From: Fix MIDI pitch bend lost on sound source change (2026-03-27)

- **Session leak on sound source change**: `onChange(of: soundSource)` replaces `pitchMatchingSession` and `pitchDiscriminationSession` without calling `stop()` on the old instances. If a session was active, its internal Tasks (MIDI listening, training loop) capture `self`, preventing deallocation. The old session's tasks run indefinitely until the AsyncStream finishes. Consider calling `stop()` before reassignment, or restructuring sessions to replace their NotePlayer rather than being fully recreated.
- **AsyncStream single-consumer**: `MIDIKitAdapter.events` is a single `AsyncStream` shared between `PitchMatchingSession` and `ContinuousRhythmMatchingSession`. While sessions are mutually exclusive by design, `AsyncStream` is documented as single-consumer. Consider using `AsyncBroadcastSequence` or per-session streams if multi-consumer support is ever needed.

## From: Fix AVAudioUnitSampler thread-unsafe reset crash (2026-04-25)

- **CC#123 doesn't reset pitch bend/controllers**: The old `auAudioUnit.reset()` reset all controller state including pitch bend. The replacement CC#123 (All Notes Off) only silences note-ons. If pitch bend was applied during playback and a new schedule starts, the bend could carry over. In practice this is mitigated because `sendPitchBend` is called explicitly before each `startNote`, but scheduled-only playback paths don't reset bend state.
- **`clearSchedule()` doesn't silence hanging notes**: When `clearSchedule()` is called, no All-Notes-Off is sent. Notes whose note-on was dispatched but note-off hasn't been reached will ring indefinitely. Pre-existing issue — the old `.reset()` was also only in `scheduleEvents()`, not `clearSchedule()`.

## From: Fix spectrogram sharing (2026-03-30)

- **Rhythm spectrogram export temp file cleanup**: `RhythmProfileCardView.renderShareImage()` writes PNGs to the temp directory on each re-render but doesn't track/delete previous renders, unlike `ChartImageRenderer.render()` which uses `lastRenderedURLs` for cleanup. Consider unifying both export paths through `ChartImageRenderer`.

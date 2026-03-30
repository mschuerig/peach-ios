# Deferred Work

## From: Fix MIDI pitch bend lost on sound source change (2026-03-27)

- **Session leak on sound source change**: `onChange(of: soundSource)` replaces `pitchMatchingSession` and `pitchDiscriminationSession` without calling `stop()` on the old instances. If a session was active, its internal Tasks (MIDI listening, training loop) capture `self`, preventing deallocation. The old session's tasks run indefinitely until the AsyncStream finishes. Consider calling `stop()` before reassignment, or restructuring sessions to replace their NotePlayer rather than being fully recreated.
- **AsyncStream single-consumer**: `MIDIKitAdapter.events` is a single `AsyncStream` shared between `PitchMatchingSession` and `ContinuousRhythmMatchingSession`. While sessions are mutually exclusive by design, `AsyncStream` is documented as single-consumer. Consider using `AsyncBroadcastSequence` or per-session streams if multi-consumer support is ever needed.

## From: Fix spectrogram sharing (2026-03-30)

- **Rhythm spectrogram export temp file cleanup**: `RhythmProfileCardView.renderShareImage()` writes PNGs to the temp directory on each re-render but doesn't track/delete previous renders, unlike `ChartImageRenderer.render()` which uses `lastRenderedURLs` for cleanup. Consider unifying both export paths through `ChartImageRenderer`.

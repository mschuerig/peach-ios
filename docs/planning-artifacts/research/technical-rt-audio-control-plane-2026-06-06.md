---
title: 'RT-audio control-plane ordering: AVAudioEngine + AVAudioUnitSampler'
date: '2026-06-06'
context: 'Story 85.1 v2 — diagnosing the first-reference-note-silent race; deciding whether a structural refactor was warranted'
status: 'draft — foundation for further research'
sources_verified: 19
sources_cited: 13
claims_extracted: 53
claims_verified: 25
claims_confirmed: 19
claims_killed: 6
agent_calls: 102
---

# Technical Research — Real-time audio control-plane ordering

## Question

How do real-time audio applications using `AVAudioEngine` + `AVAudioUnitSampler` on iOS/macOS systematically order stop-then-play MIDI sequences across the main thread / render thread boundary so that a subsequent noteOn is guaranteed to play after a deferred render-thread reset (e.g., a flag-driven CC#123 "All Notes Off" issued from the audio render callback) has been processed?

Specific architectural fault originally diagnosed: three uncoordinated MIDI dispatch paths into one shared `AVAudioUnitSampler` —

1. **Direct MainActor dispatch.** `sampler.startNote()`, `sampler.sendController()`, `sampler.sendPitchBend()` called from a Swift-Task chain on the main thread.
2. **Sample-accurate scheduled queue.** `enqueueImmediate` / scheduled events with sample positions, drained by the render thread.
3. **Render-thread flag-driven reset.** A `needsAllNotesOff: Atomic<Bool>` flag the main thread sets; on the next generation change the render thread reads it via `exchange(false)` and dispatches CC#123 + pitch-bend center via `midiBlock(AUEventSampleTimeImmediate, 0, 3, ptr)` on all 16 channels. Comment in code says this replaced an `auAudioUnit.reset()` that was crashing.

The Swift-Task chain on the main thread serialised path 1 with itself but had no ordering relationship to path 3.

## Headline finding

**Bencina-style RT-audio coordination is the wrong scale of solution for this problem.** The canonical real-time audio pattern (single-producer/single-consumer lock-free FIFO from main → render, render thread polls at start of each callback, sender never blocks) targets *buffer-fill ordering* — keeping the audio output continuous and glitch-free at low latency. Peach's actual problem is narrower: a single deferred control call from path A racing a subsequent control call from path B into the same `AVAudioUnitSampler` MIDI input. The pattern is *control-plane ordering*, not real-time DSP. A surgical fix at the dispatch sites is appropriate; a full SPSC-FIFO refactor is overengineering.

The empirical resolution was a two-line change (removed redundant cleanup paths) rather than a structural refactor.

## Verified findings (high confidence, ≥2/3 adversarial verification)

### F1 — Canonical inter-context pattern is SPSC lock-free FIFO

The canonical real-time-audio inter-thread pattern is a single-producer/single-consumer lock-free ring-buffer FIFO. Sender never blocks. Receiver polls at the start of each render callback. Cited unanimously across:

- Bencina, *Programming with light-weight asynchronous messages: some basic patterns* — "light-weight data structures often implemented using lock-free ring buffers. Writing to and reading from a queue are non-blocking operations… An audio callback polls for messages at the start of each callback." [^bencina-msgs]
- Doumler, *Using locks in real-time audio processing safely* — "If you have a stream of objects flowing from one thread to the other, such as MIDI messages, you can use a lock-free single-producer single-consumer FIFO." [^doumler-locks]
- Tyson, *Four common mistakes in audio development* — AEMessageQueue / TPCircularBuffer demonstrate the pattern in shipping iOS code. [^tyson-mistakes]
- Bencina, *QueueWorld* — "inter-thread communication for real-time audio applications where mutexes are not an option due to priority inversion." [^queueworld]
- Bencina, *Real-time audio programming 101: time waits for nothing* — the foundational summary article. [^bencina-101]

**Vote:** 3-0 unanimous on constituent claims.

### F2 — Main thread MUST NOT poll/block on render-thread state

The main (non-realtime) thread must not spin/sleep waiting for the render thread to observe a state change. Acknowledgement, when needed, flows back via a *second* queue (render → main) processed when the main thread next services it.

- Bencina: "To send a message in the opposite direction (from context B to context A) a second queue is needed… use some form of asynchronous Observer pattern where changes to x in the right hand context trigger change notification messages to be sent to the left hand context. This is a push model." [^bencina-msgs]
- Doumler: "This wait loop should never run on the audio thread; the audio thread should only ever call `try_lock()` and fall back to an alternative strategy on failure" — implying any wait lives on the non-realtime side, never the inverse. [^doumler-locks]
- QueueWorld provides `QwSpscUnorderedResultQueue` specifically as the return path "for returning results from a server thread to a client" with "a client-side counter for tracking expected vs received results" — request/ack realised as TWO queues. [^queueworld]

**Vote:** 3-0 unanimous.

**Implication for Peach:** the polling shim (`peekNeedsAllNotesOff()` + main-thread spin) that I initially proposed during diagnosis was on the wrong side of this rule.

### F3 — Atomic state replacement / swap is the O(1) ack alternative

Atomic state replacement (swap/exchange of a whole signal graph or state object) is the canonical O(1) alternative to a wait-for-reset handshake. The new state is published; the old state returns through a back-channel for deferred reclaim.

- Bencina: "Swap/exchange… A new object is sent and installed in the receiver and the old object is returned. This mechanism can be used to implement atomic state update in O(1) time, even when the object is large or complex (such as a whole signal flow graph)." [^bencina-msgs]
- Tyson / AEManagedValue: "assignments are atomic and release occurs only once the audio thread has finished with the value… the old value is only released when it's not going to mess with the audio thread." [^tyson-mistakes][^aemanagedvalue]

**Vote:** 3-0 on the core claim; 2-1 with the caveat that AEManagedValue's reclaim uses periodic main-thread polling internally — fine for state publication, but not "never polls anywhere".

**Caveat for Peach:** the swap/exchange pattern operates on objects the host owns and can atomically replace via pointer flip. It does NOT directly apply to internal voice/CC state inside `AVAudioUnitSampler`, which is a closed-source AU exposing no swappable graph pointer. **F3 is not applicable to Peach's case** — useful background, not a solution.

### F4 — AudioKit's `AppleSampler` has no synchronisation, no panic, no scheduling

AudioKit — the dominant community reference integration for `AVAudioUnitSampler` — provides:

- NO All-Notes-Off / panic / CC#123 API
- NO sample-accurate scheduling layer
- NO stop-then-play synchronisation

It calls `samplerUnit.startNote / stopNote / sendPitchBend` directly on the MainActor and treats `samplerUnit.reset()` as a safe synchronous call on the caller's thread after asset loads. There is therefore **no community-canonical "stop fully takes effect before play begins" pattern for this AU.**

Verified at AudioKit commit `4c3f5ef1b7d758609c7cfbc2d1f631fc45da04d1` against `Sources/AudioKit/Nodes/Playback/Apple Sampler/AppleSampler.swift`: [^audiokit-applesampler]

- `play()` → `samplerUnit.startNote(...)`
- `stop()` → `samplerUnit.stopNote(...)`
- `setPitchbend()` → `samplerUnit.sendPitchBend(...)`
- `resetSampler()` → `samplerUnit.reset()`

Zero occurrences in the file of `sendController`, `sendMIDIEvent`, `allNotesOff`, `panic`, `CC`, `123`, `AUScheduleMIDIEventBlock`, `MIDIEventList`, `DispatchQueue`, `Task`, `lock`, `atomic`, or `barrier`. `samplerUnit.reset()` called synchronously at 6 verified call sites with no async wrapping.

**Vote:** 3-0 unanimous.

**Implication for Peach:** the bug Peach surfaced is not one AudioKit has solved either. Peach must invent (or import from outside the AudioKit lineage) the ordering pattern. There is no copy-and-paste reference. Thread safety in the AudioKit pattern rests on AVAudioUnitSampler's own undocumented guarantees.

### F5 — Sample-accurate MIDI dispatch uses `AUScheduleMIDIEventBlock` with `AUEventSampleTimeImmediate + offsetFrames`

Sample-accurate MIDI dispatch into an AU must use `AUScheduleMIDIEventBlock` with `AUEventSampleTimeImmediate + offsetFrames`, scheduled from the audio (render) thread. Absolute `mSampleTime` values do not work reliably despite documentation implying they do. [^liljedahl]

Liljedahl (AUM author): "as far as my tests have shown, it does not work to send absolute sample time… use `AUScheduleMIDIEventBlock` + offsetFrames and make sure to schedule events from the audio thread, otherwise the timestamp can't be associated with the current render cycle."

And: "the MIDIOutputEventBlock will be called from the audio thread just like your render callback, so follow the rules of realtime safety! (No obj-c, swift, blocking, locks, memory allocations or file I/O)."

**Caveat (time-sensitivity):** Liljedahl's empirical claim is from iOS 11 era (2018) and has not been publicly re-verified on iOS 18/26. No contradicting evidence has surfaced, and the offset-from-render-cycle pattern is what AudioKit and Apple sample code use.

**Vote:** 3-0 unanimous.

### F6 — Synthesised architectural answer (community consensus)

The synthesised architecturally-correct resolution from F1+F2+F5: **unify all MIDI dispatch (noteOn, noteOff, CC, pitchBend, reset/All-Notes-Off) through one ordered SPSC queue drained on the render thread via `AUScheduleMIDIEventBlock` with `AUEventSampleTimeImmediate + offsetFrames`.** Because submission order into a single-writer FIFO is preserved, stop-then-play is automatically correctly ordered without polling, sleeping, atomic-flag handshakes, or Task chains.

If the reset path must remain a "deferred render-thread action" (e.g. because `reset()` crashes when called from main), the correct shape is to enqueue a "reset" message into the same FIFO that the noteOn would enter behind, NOT a parallel flag channel.

**Vote:** Derived synthesis. The verifier panel explicitly REJECTED the claim "a single one-way FIFO cannot express ordering" (0-3), confirming a single ordered FIFO IS sufficient for stop-then-play ordering provided every dispatch goes through it.

**Decision for Peach:** F6 was *not* adopted as the fix scope. F6 describes a structural refactor; Peach's actual symptom was resolved by a two-line surgical fix (remove redundant cleanup multiplex) that didn't require any unification. F6 remains the right answer if Peach's audio dispatch grows enough to need it — kept as a forward-looking reference for when a 4th dispatch caller appears.

### F7 — Apple has NOT documented an authoritative pattern

The Apple Developer Forums thread (123540) commonly cited for "AVAudioEngine thread safety" is about `AVAudioPlayerNode.play()` latency, not `AVAudioUnitSampler` MIDI ordering. [^apple-thread-123540] Direct verification of the cited thread: zero occurrences of `AVAudioUnitSampler`, CC#123, All Notes Off, `AUScheduleMIDIEventBlock`, sample-accurate, render-thread reset, or stop-then-play.

The pattern this report recommends is therefore **community-consensus from primary practitioners (Bencina, Doumler, Tyson, Liljedahl), not Apple-documented.** Defenders of the F6 pattern should cite it as community-consensus from named primary authorities, not as Apple authority.

**Vote:** 3-0 unanimous.

The verifier panel also rejected (0-3) the weaker claim that "serializing all `AVAudioEngine` access through a single background serial dispatch queue is the assumed-safe community consensus" — even that fallback is not supported by the cited Apple Forums thread.

## Refuted claims (worth recording so we don't re-make them)

The verifier panel killed six claims that initially seemed plausible:

| Claim | Vote | Why killed |
|---|---|---|
| "A single one-way FIFO cannot express acknowledgement — bidirectional ordering inherently needs a return path." | 0-3 | A single ordered FIFO IS sufficient for stop-then-play ordering, provided every dispatch goes through it. Submission order is preserved. The return path is only needed when the *main thread* needs to know "the render thread has processed this" — not when the goal is just "next operation lands after previous". |
| "Bencina explicitly recommends in-FIFO ordered state-change commands rather than parallel uncoordinated channels." | 0-3 | Bencina's writing is largely about what NOT to do; he is coy on positive prescriptions for THIS specific multi-path-into-one-AU shape. Don't cite Bencina as having recommended a specific positive pattern. |
| "For Inter-App Audio nodes, MIDI dispatch must originate from the audio thread so the timestamp can be tied to the current render cycle." | 0-3 | Liljedahl's claim is about AUM's specific dispatch pattern, not a general rule. Main-thread dispatch with `AUEventSampleTimeImmediate` does work in many AU contexts. |
| "When the main context needs to know the render context's state, the canonical pattern is synchronised/cached state (master holds a local mirror updated by push notifications, queries the mirror synchronously)." | 0-3 | Not in Bencina's RT-audio-101 article in the form claimed. The "push to a mirror, read the mirror" pattern is a general distributed-systems idiom, not specifically the canonical RT-audio answer. |
| "Community consensus is that serializing all AVAudioEngine access through a single background serial dispatch queue is the assumed-safe pattern, though officially undocumented." | 0-3 | The Apple Forums thread cited as evidence does not discuss this. No community-consensus exists for it. |
| "Failing to use MIDI timestamping when sending events causes audible timing jitter; sample-accurate scheduling is required for musically correct output." | 1-2 | For Peach's reference notes and pitch matching (not rhythm), sub-frame precision isn't required. Sample-accurate scheduling is for rhythm-precision contexts. The blanket "required for musically correct output" overreaches. |

## Caveats and time-sensitivity

1. **Liljedahl's empirical findings on absolute `mSampleTime`** — from 2018 / iOS 11. Not publicly re-verified against iOS 18/26. The offset-from-render-cycle pattern is still the de facto consensus but Apple has neither confirmed nor refuted the underlying bug.
2. **AEManagedValue's deferred reclaim** uses periodic main-thread polling internally — fine for state publication, but do not present it as "never polls anywhere."
3. **Bencina's swap/exchange pattern** operates on objects the host owns and can atomically replace via pointer flip. Does NOT directly apply to internal voice/CC state inside `AVAudioUnitSampler`, which is a closed-source AU exposing no swappable graph pointer.
4. **AudioKit's lack of CC#123 / sync mechanism** reflects what AudioKit does, not necessarily what is correct. The absence is informative (the community has not solved this) but not prescriptive.
5. **The F6 unified-queue recommendation** is community-consensus from named primary practitioners; it is NOT Apple-documented for `AVAudioEngine + AVAudioUnitSampler` specifically. Defend any architecture amendment by citing Bencina/Doumler/Tyson/Liljedahl by name, not by appealing to Apple authority.
6. **The original `auAudioUnit.reset()` crash** that motivated replacing the call with the flag mechanism was not investigated by this research. The recommendation here would be to enqueue reset/CC#123 events into a unified MIDI queue, which sidesteps `reset()` entirely rather than explaining why `reset()` crashed.

## How this research informed the 85.1 v2 fix

The research arrived in the middle of diagnosis. Its primary value was *negative* — confirming that:

1. There is no Apple-documented pattern to copy.
2. AudioKit hasn't solved this problem either, so no community reference exists.
3. The Bencina-style SPSC-FIFO refactor (F6) is correct but overscoped for Peach's actual symptom (which empirically resolved with a two-line cleanup-multiplex removal).

The two-line fix (commit `73ff62f3`) was the right scope. F6 remains the right answer if a 4th dispatch caller is ever added to `SoundFontEngine`.

## Open questions for further research

- **What actually caused the original `auAudioUnit.reset()` crash?** If the crash signature is reproducible, we could potentially retire the `needsAllNotesOff` flag mechanism entirely (or restrict it to the rhythm sequencer's actual need). Worth investigating before adding any 4th dispatch caller.
- **Is `AVAudioUnitSampler`'s voice management documented anywhere internally to Apple?** The empirical observation that `stopNote(N_A)` can affect voice state for `N_B` on the same channel (against strict MIDI polyphony) was the silencing mechanism in the cancellation race. Confirming the actual semantics would let us reason about future patterns more safely.
- **Does the iOS 26 release-rehosting of AVAudioEngine change any of the Liljedahl-2018 findings?** The MIDI dispatch path in modern AU v3 may have different semantics than the iOS 11 era observations.
- **Are there `AVAudioUnitSampler`-specific patterns shipping in Logic Pro, GarageBand, or Apple's own sample apps that we haven't found?** This research found nothing in `developer.apple.com/forums` of substance; sample code in `developer.apple.com/documentation` may have more.

## Source register

| Source | URL | Quality | Findings |
|---|---|---|---|
| Bencina — Light-weight asynchronous messages | http://www.rossbencina.com/code/programming-with-lightweight-asynchronous-messages-some-basic-patterns | primary | F1, F2, F3, F6, F7 |
| Bencina — Real-time audio programming 101 | http://www.rossbencina.com/code/real-time-audio-programming-101-time-waits-for-nothing | primary | F1, F5, F6 |
| Bencina — QueueWorld | https://github.com/RossBencina/QueueWorld | primary | F1, F2 |
| Doumler — Using locks in real-time audio | https://timur.audio/using-locks-in-real-time-audio-processing-safely | blog (primary practitioner) | F1, F2 |
| Tyson — Four common mistakes in audio development | https://atastypixel.com/four-common-mistakes-in-audio-development/ | blog (primary practitioner) | F1, F3, F5 |
| AudioKit — AppleSampler.swift @ 4c3f5ef | https://github.com/AudioKit/AudioKit/blob/4c3f5ef1b7d758609c7cfbc2d1f631fc45da04d1/Sources/AudioKit/Nodes/Playback/Apple%20Sampler/AppleSampler.swift | primary source | F4 |
| Liljedahl — iOS MIDI timestamps | http://devnotes.kymatica.com/ios_midi_timestamps.html | primary (AUM author) | F5 |
| AEManagedValue docs | https://theamazingaudioengine.com/doc2/interface_a_e_managed_value.html | primary | F3 |
| Apple Forums thread 123540 | https://developer.apple.com/forums/thread/123540 | forum (negative evidence) | F7 |

Lower-quality sources fetched but not cited in findings: `developer.apple.com/forums/thread/77425`, `developer.apple.com/forums/thread/672412`, `discussions.apple.com/thread/250958788`, `developer.apple.com/forums/thread/670069`, `developer.apple.com/forums/thread/709564`, `developer.apple.com/documentation/audiotoolbox/auschedulemidieventblock`, `https://github.com/bradhowes/SoundFonts/blob/main/README.md`, `https://www.audiokit.io/AudioKit/documentation/audiokit/applesampler/resetsampler()`, `https://cp3.io/posts/sample-accurate-midi-timing/`, `http://www.rossbencina.com/code/lockfree`, `http://www.rossbencina.com/code/interfacing-real-time-audio-and-file-io`.

[^bencina-msgs]: http://www.rossbencina.com/code/programming-with-lightweight-asynchronous-messages-some-basic-patterns
[^bencina-101]: http://www.rossbencina.com/code/real-time-audio-programming-101-time-waits-for-nothing
[^doumler-locks]: https://timur.audio/using-locks-in-real-time-audio-processing-safely
[^tyson-mistakes]: https://atastypixel.com/four-common-mistakes-in-audio-development/
[^queueworld]: https://github.com/RossBencina/QueueWorld
[^audiokit-applesampler]: https://github.com/AudioKit/AudioKit/blob/4c3f5ef1b7d758609c7cfbc2d1f631fc45da04d1/Sources/AudioKit/Nodes/Playback/Apple%20Sampler/AppleSampler.swift
[^liljedahl]: http://devnotes.kymatica.com/ios_midi_timestamps.html
[^aemanagedvalue]: https://theamazingaudioengine.com/doc2/interface_a_e_managed_value.html
[^apple-thread-123540]: https://developer.apple.com/forums/thread/123540

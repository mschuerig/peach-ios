# SoundFontEngine Sequence Diagrams

Three diagrams covering the core operations of the audio engine.
These are intended for inclusion in the arc42 runtime view (section 6).

---

## 1. Engine Initialization

**Purpose:** Stand up a real-time audio pipeline capable of sample-accurate MIDI dispatch,
with a render-thread clock that drives event timing even when outputting silence.

```mermaid
sequenceDiagram
    participant Caller
    participant Engine as SoundFontEngine
    participant AVEngine as AVAudioEngine
    participant Sampler0 as AVAudioUnitSampler<br/>(Channel 0)
    participant DBS as DoubleBufferedScheduleState
    participant AudioSession as AudioSessionConfiguring
    participant SourceNode as AVAudioSourceNode<br/>(Render Clock)

    Note over Caller,SourceNode: Goal: build a graph that can play MIDI<br/>and schedule events with sample accuracy

    Caller->>Engine: init(sf2URL, audioSessionConfigurator)

    rect rgb(240, 248, 255)
        Note over Engine,Sampler0: Phase 1 — Audio graph skeleton
        Engine->>AVEngine: create()
        Engine->>DBS: create(capacity: 4096)
        Engine->>Sampler0: create()
        Engine->>AVEngine: attach(sampler0)
        Engine->>AVEngine: connect(sampler0 → mainMixerNode)
    end

    rect rgb(240, 255, 240)
        Note over Engine,AudioSession: Phase 2 — System audio readiness
        Engine->>AudioSession: configure(logger:)
        Note right of AudioSession: Sets playback category,<br/>preferred sample rate, buffer size
        Engine->>AVEngine: start()
        Note right of AVEngine: Hardware I/O now active
    end

    rect rgb(255, 248, 240)
        Note over Engine,DBS: Phase 3 — Register Channel 0 for render-thread dispatch
        Engine->>Sampler0: auAudioUnit.scheduleMIDIEventBlock
        Sampler0-->>Engine: block0
        Engine->>DBS: midiBlocks(slot 0)[ch0] = block0
        Engine->>DBS: midiBlocks(slot 1)[ch0] = block0
        Note right of DBS: Both slots seeded — safe because<br/>source node isn't attached yet,<br/>so no concurrent reader exists
    end

    rect rgb(248, 240, 255)
        Note over Engine,SourceNode: Phase 4 — Render-thread clock
        Engine->>SourceNode: create(format: mono @ outputSampleRate)
        Note right of SourceNode: Outputs silence but runs on<br/>the real-time audio thread —<br/>provides the timing reference<br/>for all MIDI event dispatch
        Engine->>AVEngine: attach(sourceNode)
        Engine->>AVEngine: connect(sourceNode → mainMixerNode)
    end

    Engine-->>Caller: SoundFontEngine ready
```

---

## 2. Playing a Single Note

**Purpose:** Convert a musical frequency (e.g. 446.2 Hz — an A4 tuned 24 cents sharp)
into a MIDI note + pitch bend pair that reproduces the exact pitch through the SoundFont sampler.

```mermaid
sequenceDiagram
    participant Caller
    participant Player as SoundFontPlayer
    participant Engine as SoundFontEngine
    participant Sampler as AVAudioUnitSampler

    Note over Caller,Sampler: Goal: play an arbitrary frequency with<br/>microtonal accuracy via MIDI pitch bend

    Caller->>Player: play(frequency: 446.2 Hz, velocity, amplitudeDB)

    rect rgb(240, 248, 255)
        Note over Player,Engine: Phase 1 — Ensure the instrument is ready
        Player->>Engine: loadPreset(piano, channel: 0)
        alt preset not yet loaded
            Engine->>Sampler: loadSoundBankInstrument(sf2URL, program, bank)
            Engine->>Sampler: sendController (RPN 0x0000) — set pitch bend range ±2 semitones
            Note right of Sampler: 4 MIDI CC messages configure<br/>the ±200 cent bend range<br/>all bend math depends on
            Engine->>Engine: sleep(20ms) — let audio graph settle
        end
    end

    Player->>Player: validateFrequency(446.2 Hz ∈ 20...20000)

    rect rgb(240, 255, 240)
        Note over Player: Phase 2 — Frequency → MIDI translation
        Player->>Player: decompose(446.2 Hz)
        Note right of Player: 12-TET at A4=440 Hz (MIDI convention):<br/>exactMidi = 69 + 12·log₂(446.2/440) = 69.244<br/>rounded = 69 (A4), remainder = +24.4 cents
        Player-->>Player: (note: 69, cents: +24.4¢)

        Player->>Player: pitchBendValue(forCents: +24.4¢)
        Note right of Player: center = 8192, range = ±200¢<br/>bend = 8192 + 24.4 × 8192/200 = 9192<br/>→ 14-bit MIDI pitch bend value
        Player-->>Player: PitchBendValue(9192)
    end

    rect rgb(255, 248, 240)
        Note over Player,Sampler: Phase 3 — Sound the note
        Player->>Engine: startNote(A4, velocity, amplitudeDB, pitchBend: 9192, ch: 0)
        Engine->>Sampler: sendPitchBend(9192, channel: 0)
        Note right of Sampler: Shifts A4 up 24.4 cents<br/>→ exact 446.2 Hz
        Engine->>Sampler: overallGain = amplitudeDB
        Engine->>Sampler: startNote(69, velocity, channel: 0)
    end

    Player-->>Caller: SoundFontPlaybackHandle

    Note over Caller,Sampler: The handle allows the caller to:<br/>• stop() — mute-fade, note-off, reset pitch bend<br/>• adjustFrequency() — live pitch bend (within ±200¢)
```

---

## 3. Playing a RhythmPattern

**Purpose:** Schedule an entire percussion sequence for lock-free, sample-accurate playback.
Events are dispatched by the real-time render thread — no main-thread involvement after scheduling.

```mermaid
sequenceDiagram
    participant Caller
    participant Player as SoundFontPlayer
    participant Engine as SoundFontEngine
    participant DBS as DoubleBufferedScheduleState
    participant RenderThread as Render Thread<br/>(AVAudioSourceNode)
    participant Sampler as AVAudioUnitSampler

    Note over Caller,Sampler: Goal: play a timed percussion pattern with<br/>sample-accurate timing, no main-thread jitter

    Caller->>Player: play(pattern: RhythmPattern)

    rect rgb(240, 248, 255)
        Note over Player,Engine: Phase 1 — Ensure percussion instrument is loaded
        Player->>Engine: ensureAudioSessionConfigured()
        Player->>Engine: ensureEngineRunning()
        Player->>Engine: loadPreset(percussion, channel: 0)
        Note right of Engine: Percussion uses bank 128 (GM standard).<br/>No pitch bend range set — drums don't bend.
    end

    rect rgb(240, 255, 240)
        Note over Player: Phase 2 — Convert pattern to MIDI event stream
        Player->>Player: for each event in pattern.events
        Note right of Player: Each hit becomes two ScheduledMIDIEvents:<br/>• note-on at event.sampleOffset<br/>• note-off at sampleOffset + cappedDelay<br/><br/>Note-off delay is min(50ms, gap to next note − 1)<br/>to avoid clipping the next hit.
        Player->>Player: sort events by sampleOffset
        Note right of Player: Interleaving note-on/off pairs<br/>ensures correct temporal order<br/>for the render thread's linear scan.
    end

    rect rgb(255, 248, 240)
        Note over Engine,DBS: Phase 3 — Atomic schedule publish (main thread)
        Player->>Engine: scheduleEvents([...])
        Engine->>Sampler: auAudioUnit.reset() — flush stale MIDI on affected channels
        Engine->>DBS: write events to INACTIVE slot
        Engine->>DBS: copy mainThreadMidiBlocks to inactive slot
        Engine->>DBS: generation.store(gen+1, releasing)
        Note right of DBS: Single atomic increment<br/>publishes both the event buffer<br/>and the MIDI block snapshot.<br/>The render thread will see<br/>a consistent view on its next<br/>acquire load.
    end

    Player-->>Caller: SoundFontRhythmPlaybackHandle

    rect rgb(248, 240, 255)
        Note over RenderThread,Sampler: Phase 4 — Render-thread dispatch (runs autonomously)

        loop Every ~11.6ms render callback (512 samples @ 44.1kHz)
            RenderThread->>DBS: generation.load(acquiring)
            alt generation changed
                RenderThread->>DBS: reset cursor, samplePosition, immediate buffer
                Note right of RenderThread: Fresh schedule detected —<br/>start dispatching from event 0
            end

            RenderThread->>RenderThread: windowStart..windowEnd = current frame range

            loop Walk events from cursor while sampleOffset < windowEnd
                RenderThread->>DBS: read event[nextIndex]
                alt event.sampleOffset ∈ [windowStart, windowEnd)
                    RenderThread->>DBS: lookup midiBlock for event's channel
                    RenderThread->>Sampler: midiBlock(eventTime, 0, 3, bytes)
                    Note right of Sampler: Sub-sample-accurate dispatch:<br/>eventTime = AUEventSampleTimeImmediate<br/>+ intra-buffer offset
                end
                RenderThread->>RenderThread: advance cursor
            end

            RenderThread->>DBS: store samplePosition = windowEnd (releasing)
            Note right of DBS: Publishes timing progress<br/>for main-thread consumers<br/>(e.g. UI beat indicators)
        end
    end

    Note over Caller,Sampler: To stop: handle.stop() → clearSchedule()<br/>bumps generation → render thread resets<br/>and finds an empty event buffer
```

---

## Key Design Decisions Illustrated

| Concern | Solution | Diagram |
|---------|----------|---------|
| Real-time safety | No locks, no allocations on render thread — all via pre-allocated buffers and atomic generation counter | #3 Phase 4 |
| Microtonal accuracy | Frequency → MIDI note + pitch bend decomposition | #2 Phase 2 |
| Thread communication | Double-buffered slots with release/acquire ordering on a single generation counter | #3 Phases 3–4 |
| Immediate events (tap sounds) | SPSC ring buffer bypasses the double-buffer schedule | Not shown (separate path via `immediateNoteOn/Off`) |
| Audio session resilience | Lazy configure + ensure-running pattern before every play | All three Phase 1 |

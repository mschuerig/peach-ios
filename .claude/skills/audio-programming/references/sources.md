# Sources — Annotated Reading List

What each authority does and does not say. Cite responsibly.

## Tier 1 — RT-audio canon

### Ross Bencina

- **"Real-time audio programming 101: time waits for nothing"** — http://www.rossbencina.com/code/real-time-audio-programming-101-time-waits-for-nothing
  The universal starting point. Defines the constraints (no locks, no allocation, no I/O, no blocking) and the philosophy. Don't write audio code without reading it.
- **"Programming with light-weight asynchronous messages: some basic patterns"** — http://www.rossbencina.com/code/programming-with-lightweight-asynchronous-messages-some-basic-patterns
  The canonical taxonomy of inter-thread patterns (queue, swap, observer). Foundation for `inter-thread-patterns.md`.
- **QueueWorld** — https://github.com/RossBencina/QueueWorld
  Reference C++ SPSC primitives. Read for design vocabulary even if you don't use the code.

**Cite for:** foundational principles, the four rules, inter-thread pattern taxonomy. **Don't cite for:** specific positive prescriptions for Apple AUs; Bencina doesn't address them directly.

### Timur Doumler

- **"Using locks in real-time audio processing, safely"** — https://timur.audio/using-locks-in-real-time-audio-processing-safely
  Canonical reading on `try_lock` discipline; clarifies that locks aren't categorically forbidden, only blocking acquisition.
- **"Thread Synchronisation in Real-Time Audio Processing With RCU"** (ADC talk) — https://www.youtube.com/watch?v=7fKxIZOyBCE
  The atomic-swap / deferred-reclaim pattern (Linux RCU) for real-time audio. Pattern 2 in `inter-thread-patterns.md`.
- ADC and CppCon talks on real-time C++.

**Cite for:** lock discipline, RCU swap pattern, what RT-safety means in C++. **Don't cite for:** specific Apple API guarantees.

### Michael Tyson

- **"Four common mistakes in audio development"** — https://atastypixel.com/four-common-mistakes-in-audio-development/
  Canonical iOS-practitioner essay. Site is sometimes slow/500-error; cite URL but verify before quoting.
- **TPCircularBuffer** — battle-tested SPSC lock-free ring buffer used in AudioKit and many shipping iOS apps.
- **AEManagedValue** — atomic state swap with deferred reclaim for iOS.
- **AEMessageQueue** — message-passing primitive.

**Cite for:** iOS-shipped patterns, working code, what the community has settled on for Swift integration. **Don't cite for:** general DSP theory.

### Joel Liljedahl

- **"iOS MIDI timestamps"** — http://devnotes.kymatica.com/ios_midi_timestamps.html
  Author of AUM. Established the `AUEventSampleTimeImmediate + offsetFrames` pattern for sample-accurate MIDI dispatch into Audio Units. Empirically derived from iOS 11 (2018); not publicly contradicted since.

**Cite for:** sample-accurate MIDI scheduling into AUs. **Caveat:** finding is empirical from 2018, never publicly re-verified on later iOS.

## Tier 1 — Apple

### Documentation

Apple Developer Documentation (https://developer.apple.com/documentation/) is **authoritative for API surface but often silent on threading semantics**. WWDC sessions sometimes fill the gap; sample code occasionally contradicts the docs.

Key landing pages:

- AVFAudio — https://developer.apple.com/documentation/avfaudio
- AudioToolbox — https://developer.apple.com/documentation/audiotoolbox
- CoreAudio — https://developer.apple.com/documentation/coreaudio
- CoreMIDI — https://developer.apple.com/documentation/coremidi
- PHASE — https://developer.apple.com/documentation/phase
- Accelerate — https://developer.apple.com/documentation/accelerate

### WWDC sessions

- **WWDC14 #502** — "AVAudioEngine in Practice" — foundational tour
- **WWDC14 #501** — "Audio Session Configuration Best Practices"
- **WWDC15 #507** — "What's New in Core Audio" (manual rendering)
- **WWDC15 #508** — "Audio Unit Extensions" (AUv3 introduction)
- **WWDC17 #501** — "Creating Custom Audio Effects"
- **WWDC19 #508** — "Modernizing Your Audio App" (AUGraph deprecation)
- **WWDC19 #510** — "What's New in AVAudioEngine" (`AVAudioSourceNode` / `AVAudioSinkNode`)
- **WWDC20 #10224** — "Meet Audio Workgroups" (Doug Wyatt)
- **WWDC21 #10036** — "Bring your App to Life with AU Extensions"
- **WWDC21 #10079** — "Discover geometry-aware audio with PHASE"
- **WWDC21 #10190** — "Create audio drivers with DriverKit"
- **WWDC22 #10058** — "What's New in Audio"

ASCII transcripts at https://asciiwwdc.com (best fallback when video isn't accessible).

### Apple sample code

- *AVAEGamingExample* — spatial audio
- *AUv3FilterDemo*, *AUv3InstrumentDemo* — AUv3 development
- Audio Toolbox samples on developer.apple.com sample code

**Cite Apple docs/WWDC for:** API surface, official terminology, supported behaviors. **Don't cite for:** "thread-safety guarantees" that aren't explicitly stated. Verify with a real session video, not a forum thread that claims to summarize one.

### Apple Developer Forums

Anecdotal. Verify thread content before citing.

The frequently-cited thread 123540 (claimed "AVAudioEngine thread safety") is **actually** about `AVAudioPlayerNode.play()` latency, not thread-safety of `AVAudioUnitSampler` MIDI. Don't promote forum threads to canonical Apple authority.

## Tier 2 — Cross-platform community canon

### JUCE

- https://juce.com — framework
- https://docs.juce.com/master/index.html — docs
- https://forum.juce.com — forum with deep RT-safety threads

**Cite for:** cross-platform plugin patterns (`AudioProcessor::processBlock`, `AudioProcessorValueTreeState`, `AbstractFifo`). What's in JUCE is community consensus; what's *missing* from JUCE is informative but not prescriptive.

### Audio Developer Conference

- https://audio.dev — conference
- https://www.youtube.com/@audiodevcon — talks

Best single archive for RT-audio, DSP, plugin design talks.

### AudioKit (Apple-platform)

- https://github.com/AudioKit/AudioKit — reference Swift integration

**Cite for:** what Swift integration with `AVAudioUnitSampler` actually looks like. **What's missing is informative:**
- No All-Notes-Off / panic API
- No sample-accurate scheduling layer
- No stop-then-play synchronisation
- Calls `samplerUnit.startNote/stopNote/sendPitchBend` directly on MainActor
- Treats `samplerUnit.reset()` as safe-synchronous

Absence of these tells you the community has *not* solved the problem in question.

## Tier 2 — DSP fundamentals

- **Steven W. Smith — *The Scientist and Engineer's Guide to Digital Signal Processing*** — https://www.dspguide.com/ (full text free).
  The universal DSP reference. Tutorial-style; assumes no prior DSP background.
- **Will Pirkle — *Designing Audio Effect Plug-Ins in C++*** / ***Designing Software Synthesizer Plug-Ins in C++***.
  Practical implementations. Companion website and code.
- **Curtis Roads — *The Computer Music Tutorial*** (MIT Press).
  Encyclopedic; covers everything from synthesis to spatial audio.
- **Udo Zölzer (ed.) — *DAFX: Digital Audio Effects***.
  Effects survey with implementations.
- **Joshua D. Reiss & Andrew McPherson — *Audio Effects: Theory, Implementation and Application***.
  Bridges theory and code.
- **Robert Bristow-Johnson (RBJ) — Cookbook formulae for audio EQ biquad filter coefficients** — https://www.w3.org/TR/audio-eq-cookbook/.
  Coefficients for every standard biquad. Cite when implementing EQ.

## Tier 3 — Specialty / oddments

### Real-time programming in Swift

- Swift Forums — "Realtime threads with Swift" — https://forums.swift.org/t/realtime-threads-with-swift/40562
  Canonical discussion of Swift in real-time audio code. Conclusion: Swift can be used carefully with discipline; many primitives are unsafe.

### Apple-platform low-level Core Audio

- **Chris Adamson & Kevin Avila — *Learning Core Audio*** (Addison-Wesley, 2012).
  Pre-AVAudioEngine but the best long-form treatment of `AudioConverter` / `ExtAudioFile` / AUv2.
- **Chris Adamson — "Brain Dump: v3 Audio Units"** — http://subfurther.com/blog/2017/04/28/brain-dump-v3-audio-units/
  AUv3 walkthrough.

### Music Hackspace

- https://musichackspace.org — tutorials and workshops on AUv3 and CoreMIDI.

## Authority hierarchy (in disputes)

When sources disagree:

1. **Apple shipping behavior** wins over Apple documentation.
2. **Apple documentation** wins over Apple WWDC slides (slides simplify).
3. **WWDC sessions** win over forum threads (even Apple engineers' forum posts).
4. **Community primary practitioners** (Bencina/Doumler/Tyson/Liljedahl) win over apparent Apple-forum consensus.
5. **AudioKit shipping code** wins as evidence of what the iOS-Swift community has settled on.
6. **JUCE code** wins as evidence of cross-platform consensus.

When something is unanswered (e.g., closed-AU voice management), say so explicitly. Don't invent semantics from the MIDI 1.0 spec or from documentation that doesn't address the question.

## Time-sensitivity

- Liljedahl's empirical findings on `mSampleTime` — 2018 / iOS 11; never publicly re-verified.
- AudioKit conventions track Apple's API surface; check the commit your project depends on.
- WWDC session content reflects the OS version at presentation; some recommendations have shifted (e.g., default isolation, `os_workgroup` introduction).
- DSP textbook code (Pirkle / Zölzer) is timeless for theory; implementations may not be RT-safe out of the box on Apple platforms.

When citing, name the source and the year. "Liljedahl, 2018 / iOS 11" is informative; "Liljedahl says" is not.

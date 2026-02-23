# Story 8.1: Implement SoundFontNotePlayer with Fixed Cello Preset

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to hear a realistic Cello tone instead of only sine waves during training,
So that my pitch discrimination practice uses a timbre closer to real musical instruments.

## Acceptance Criteria

1. **Given** a `SoundFontNotePlayer` conforming to `NotePlayer`
   **When** `play(frequency:duration:amplitude:)` is called
   **Then** the player produces a Cello tone from the GeneralUser GS SF2 bundled in the app
   **And** the tone plays for the specified duration at the specified amplitude
   **And** audio latency from trigger to audible output is comparable to `SineWaveNotePlayer` (< 10ms)

2. **Given** a `SoundFontNotePlayer`
   **When** `play()` is called with a frequency requiring a fractional-cent offset from the nearest MIDI note
   **Then** MIDI pitch bend is applied to shift the pitch to the exact target frequency
   **And** pitch accuracy is within 0.1 cent of the target (matching the app's precision requirement)
   **And** pitch bend uses the default +/-2-semitone range (~0.024 cents/step resolution)

3. **Given** a `SoundFontNotePlayer`
   **When** `stop()` is called during playback
   **Then** the note stops cleanly without audible clicks or artifacts
   **And** the player is ready for the next `play()` call

4. **Given** a `RoutingNotePlayer` conforming to `NotePlayer`
   **When** the `soundSource` setting is `"sine"`
   **Then** it delegates to `SineWaveNotePlayer`
   **When** the `soundSource` setting is `"cello"`
   **Then** it delegates to `SoundFontNotePlayer`
   **And** the routing decision is made on each `play()` call (setting changes take effect on the next note)

5. **Given** the Settings Screen Sound Source picker
   **When** displayed
   **Then** it shows two options: "Sine Wave" and "Cello"
   **And** selecting "Cello" persists via `@AppStorage`
   **And** the next training comparison uses the Cello timbre

6. **Given** `PeachApp.swift`
   **When** the app initializes
   **Then** both `SineWaveNotePlayer` and `SoundFontNotePlayer` are created
   **And** a `RoutingNotePlayer` wrapping both is injected as the `NotePlayer` into `TrainingSession`
   **And** if `SoundFontNotePlayer` init fails, the app continues with sine-only mode (no crash)

7. **Given** the new code
   **When** unit tests are run
   **Then** frequency-to-MIDI conversion accuracy is verified (round-trip within 0.01 cent)
   **And** pitch bend calculation accuracy is verified at sub-cent precision
   **And** SF2 loading success/failure paths are verified
   **And** `RoutingNotePlayer` routing logic is verified with mock players
   **And** the full existing test suite continues to pass

## Tasks / Subtasks

- [ ] Task 1: Add frequency-to-MIDI reverse conversion to FrequencyCalculation (AC: #2, #7)
  - [ ] 1.1 Add `static func midiNoteAndCents(frequency:referencePitch:) -> (midiNote: Int, cents: Double)` to `FrequencyCalculation`
  - [ ] 1.2 Write tests verifying round-trip accuracy: frequency -> midiNote+cents -> frequency matches within 0.01 cent
  - [ ] 1.3 Test edge cases: exact MIDI notes (0 cents), half-semitone offsets, boundary frequencies, non-440 reference pitches

- [ ] Task 2: Implement SoundFontNotePlayer (AC: #1, #2, #3, #7)
  - [ ] 2.1 Create `Peach/Core/Audio/SoundFontNotePlayer.swift` conforming to `NotePlayer`
  - [ ] 2.2 Initialize own `AVAudioEngine` + `AVAudioUnitSampler`; load GeneralUser GS SF2 with Cello preset (program 42, bankMSB 0x79, bankLSB 0)
  - [ ] 2.3 Set pitch bend range to +/-2 semitones via RPN controller messages on init
  - [ ] 2.4 Implement `play()`: convert frequency -> MIDI note + cent remainder via `FrequencyCalculation`, apply pitch bend, `startNote()`, sleep for duration, `stopNote()`
  - [ ] 2.5 Implement `stop()`: stop currently playing note, handle cleanup without audible artifacts
  - [ ] 2.6 Implement pitch bend calculation: `8192 + Int(cents * 8192.0 / 200.0)` clamped to `0...16383`
  - [ ] 2.7 Configure `AVAudioSession` (`.playback` category) matching `SineWaveNotePlayer` pattern
  - [ ] 2.8 Handle `CancellationError` during `Task.sleep` — always call `stopNote()` in defer/cleanup
  - [ ] 2.9 Create `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift`

- [ ] Task 3: Implement RoutingNotePlayer (AC: #4, #7)
  - [ ] 3.1 Create `Peach/Core/Audio/RoutingNotePlayer.swift` conforming to `NotePlayer`
  - [ ] 3.2 Hold references to both `SineWaveNotePlayer` and optional `SoundFontNotePlayer`
  - [ ] 3.3 Read `SettingsKeys.soundSource` from `UserDefaults` on each `play()` call
  - [ ] 3.4 Delegate `play()`/`stop()` to the active player; stop the previously active player if source changed between calls
  - [ ] 3.5 Create `PeachTests/Core/Audio/RoutingNotePlayerTests.swift` testing routing logic with mock players

- [ ] Task 4: Update Settings UI (AC: #5)
  - [ ] 4.1 Add `"Cello"` option with tag `"cello"` to Sound Source picker in `SettingsScreen`
  - [ ] 4.2 Add localized strings for "Cello" (English + German)

- [ ] Task 5: Wire up in PeachApp.swift (AC: #6)
  - [ ] 5.1 Create `SoundFontNotePlayer` alongside existing `SineWaveNotePlayer`
  - [ ] 5.2 Create `RoutingNotePlayer` wrapping both
  - [ ] 5.3 Inject `RoutingNotePlayer` as the `NotePlayer` into `TrainingSession`
  - [ ] 5.4 Handle `SoundFontNotePlayer` init failure gracefully — log error, continue with sine-only (pass `nil` to `RoutingNotePlayer`)

- [ ] Task 6: Update project-context.md (housekeeping)
  - [ ] 6.1 Update AVAudioEngine rule to reflect that each NotePlayer implementation owns its own engine instance
  - [ ] 6.2 Add `SoundFontNotePlayer` and `RoutingNotePlayer` to project structure section
  - [ ] 6.3 Document `SettingsKeys.soundSource` values (`"sine"`, `"cello"`)

## Dev Notes

### Technical Requirements

- **AVAudioUnitSampler + SF2**: Load GeneralUser GS from app bundle via `Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")`. The SF2 is already bundled by the `infra-sf2-build-download-cache` build script [Source: docs/implementation-artifacts/infra-sf2-build-download-cache.md]
- **Cello preset**: General MIDI Program 42, Bank MSB `0x79` (`kAUSampler_DefaultMelodicBankMSB`), Bank LSB `0`. Use `loadSoundBankInstrument(at:program:bankMSB:bankLSB:)`
- **Pitch bend precision**: Default +/-2-semitone range = 8192 steps per 200 cents = **0.024 cents/step** — exceeds the 0.1-cent requirement by 4x [Source: research doc, Pitch Bend Implementation]
- **Pitch bend range setup via RPN**: Send controller messages at sampler init to explicitly set +/-2 semitones:
  ```
  sendController(101, withValue: 0, onChannel: 0)  // RPN MSB
  sendController(100, withValue: 0, onChannel: 0)  // RPN LSB
  sendController(6,   withValue: 2, onChannel: 0)  // Data Entry: 2 semitones
  sendController(38,  withValue: 0, onChannel: 0)  // Fine: 0 cents
  ```
- **Frequency -> MIDI conversion**: `exactMidi = 69 + 12 * log2(frequency / referencePitch)`, `nearestMidi = round(exactMidi)`, `centRemainder = (exactMidi - nearestMidi) * 100`. Add as `FrequencyCalculation.midiNoteAndCents(frequency:referencePitch:)`. Reference pitch comes from `@AppStorage` (default 440 Hz) [Source: docs/project-context.md — "Use FrequencyCalculation.swift for all Hz conversions"]
- **Pitch bend value calculation**: `bendValue = 8192 + Int(cents * 8192.0 / 200.0)`, clamped to `0...16383`. Send via `sampler.sendPitchBend(bendValue, onChannel: 0)` **before** `startNote()`
- **Note duration**: `startNote()` is instantaneous; duration controlled by `try await Task.sleep(for: .seconds(duration))` followed by `stopNote()`. Use `defer { stopNote() }` to ensure cleanup on cancellation
- **Amplitude -> MIDI velocity**: `velocity = UInt8(min(127, max(1, amplitude * 127)))` — MIDI velocity 0 means note-off in some implementations, so floor at 1
- **Stop behavior**: Track the currently playing MIDI note number; `stop()` calls `stopNote(currentNote, onChannel: 0)`. Reset pitch bend to center (8192) after stopping

### Architecture Compliance

- **`NotePlayer` protocol boundary preserved**: `SoundFontNotePlayer` receives frequency in Hz, not MIDI notes. All freq->MIDI conversion is internal. Callers (TrainingSession) remain unaware of the MIDI layer [Source: docs/project-context.md — "NotePlayer knows only frequencies (Hz)"]
- **`FrequencyCalculation.swift` for all Hz conversions**: The reverse conversion (Hz -> MIDI note + cents) is added to `FrequencyCalculation.swift`, not implemented locally in `SoundFontNotePlayer` [Source: docs/project-context.md — "Use FrequencyCalculation.swift for all Hz conversions"]
- **Separate AVAudioEngine per NotePlayer**: `SoundFontNotePlayer` creates its own `AVAudioEngine` separate from `SineWaveNotePlayer`'s engine. This is a **deliberate update** to the project-context "never instantiate a second engine" rule. Rationale: the two players use different audio graphs (`AVAudioPlayerNode` vs `AVAudioUnitSampler`) and `RoutingNotePlayer` ensures only one is active at a time. Sharing would require refactoring engine ownership for no benefit [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#system-design]
- **Composition root in PeachApp.swift**: Both players created and assembled in `PeachApp.swift`. `RoutingNotePlayer` injected as the single `NotePlayer` dependency [Source: docs/project-context.md — "All service instantiation happens in PeachApp.swift"]
- **Zero third-party dependencies**: Uses only Apple-native `AVAudioUnitSampler`, `AVAudioEngine`, `AVFoundation`. No AudioKit, no bradhowes/SF2Lib [Source: docs/project-context.md — "Zero third-party dependencies"]
- **Settings read live**: `RoutingNotePlayer` reads `UserDefaults` on each `play()` call, following the established pattern [Source: docs/project-context.md — "Settings read live"]
- **@MainActor isolation**: `SoundFontNotePlayer` and `RoutingNotePlayer` must be `@MainActor final class` matching the `NotePlayer` protocol requirement and `SineWaveNotePlayer` pattern

### Library & Framework Requirements

- **AVFoundation / AVFAudio** (already imported by `SineWaveNotePlayer`):
  - `AVAudioEngine` — audio rendering pipeline
  - `AVAudioUnitSampler` — SF2 sampler instrument
  - `AVAudioSession` — audio session configuration
- No new dependencies. No SPM packages.

### File Structure Requirements

**New files:**
```
Peach/Core/Audio/
├── SoundFontNotePlayer.swift         # AVAudioUnitSampler + SF2 implementation
└── RoutingNotePlayer.swift           # Routes to active NotePlayer based on setting

PeachTests/Core/Audio/
├── SoundFontNotePlayerTests.swift    # SF2 loading, pitch accuracy, protocol conformance
└── RoutingNotePlayerTests.swift      # Routing logic with mock players
```

**Modified files:**
```
Peach/Core/Audio/FrequencyCalculation.swift   # Add midiNoteAndCents() reverse conversion
Peach/Settings/SettingsScreen.swift            # Add "Cello" to Sound Source picker
Peach/App/PeachApp.swift                       # Wire RoutingNotePlayer
docs/project-context.md                        # Update AVAudioEngine rule, add new types
```

**Existing test files extended:**
```
PeachTests/Core/Audio/FrequencyCalculationTests.swift  # Add reverse conversion tests
```

### Testing Requirements

- **FrequencyCalculation reverse conversion** (`FrequencyCalculationTests.swift`):
  - Round-trip tests: `frequency(midiNote:cents:) -> midiNoteAndCents(frequency:)` matches within 0.01 cent
  - Exact MIDI notes return 0 cents remainder
  - Half-semitone offsets return ~50 cents
  - Works with A440 and non-440 reference pitches (A442, A415)
  - Edge cases: lowest/highest MIDI notes, extreme frequencies

- **SoundFontNotePlayer** (`SoundFontNotePlayerTests.swift`):
  - Protocol conformance: `play()` and `stop()` lifecycle works without crash
  - SF2 loading: success with bundled file, graceful error with missing file
  - Pitch bend calculation: known frequency -> expected bend value (e.g., A4=440Hz at referencePitch=440 -> bend center 8192, 0 cents)
  - Pitch bend for +50 cents -> expected bend value `8192 + Int(50 * 8192.0 / 200.0)` = 10240
  - Note: actual audio output quality is manual-verification only

- **RoutingNotePlayer** (`RoutingNotePlayerTests.swift`):
  - Routes to sine mock when setting is `"sine"`
  - Routes to cello mock when setting is `"cello"`
  - Falls back to sine when `SoundFontNotePlayer` is nil
  - Setting change between calls routes to new player
  - `stop()` stops the currently active player
  - Uses existing `MockNotePlayer` from test target

- **All tests `@MainActor async`** per project testing rules

### Previous Story Intelligence

**From `infra-sf2-build-download-cache` (done):**
- GeneralUser GS SF2 is bundled in the app at build time via `tools/download-sf2.sh`
- Access: `Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")`
- File: ~30.7 MB, GeneralUser GS v2.0.3
- Attribution follow-up tracked: S. Christian Collins credit needed in Info screen
- The build script uses commit-pinned GitHub raw URL, SHA-256 checksum verification, `~/.cache/peach/` persistent cache
[Source: docs/implementation-artifacts/infra-sf2-build-download-cache.md]

### Git Intelligence

Recent commits (last 5):
- `5e2aabb` Merge branch 'story/infra-sf2-build-download-cache'
- `0da6bab` Fix code review findings for infra-sf2-build-download-cache
- `ea2fca2` Implement story infra-sf2-build-download-cache: SF2 build download cache
- `e5dfaa5` Add story: SF2 sample download caching in build process
- `f1e596a` Add technical research: sampled instrument NotePlayer implementation

The project is in a post-MVP phase — recent work is sampled instrument infrastructure. This story creates the Swift implementation that consumes the SF2 file bundled by the preceding infra story.

### Project Structure Notes

- `SoundFontNotePlayer` and `RoutingNotePlayer` live in `Peach/Core/Audio/` alongside `NotePlayer.swift` and `SineWaveNotePlayer.swift` — all audio implementations in the same directory
- Test files mirror: `PeachTests/Core/Audio/`
- No new directories needed — fits cleanly in existing structure
- `RoutingNotePlayer` is a service (not a view) so it belongs in `Core/Audio/`, not in `App/`

### References

- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#recommended-architecture] — AVAudioUnitSampler + SF2 approach, system design
- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#pitch-bend-implementation] — RPN setup, bend calculation formula, precision analysis
- [Source: docs/planning-artifacts/research/technical-sampled-instrument-noteplayer-research-2026-02-23.md#noteplayer-protocol-integration] — Frequency->MIDI translation pattern for Approach B
- [Source: docs/project-context.md] — NotePlayer protocol boundary, FrequencyCalculation rule, testing patterns, @MainActor requirements
- [Source: docs/planning-artifacts/architecture.md#service-boundaries] — NotePlayer knows only frequencies, zero third-party deps
- [Source: docs/implementation-artifacts/infra-sf2-build-download-cache.md] — SF2 already bundled, Bundle.main access pattern

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

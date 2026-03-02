# Audit Report: NotePlayer and Frequency Computation Chain

**Auditor:** Adam (Music Domain Expert)
**Date:** 2026-03-02
**Story:** 28.2 — Audit NotePlayer and Frequency Computation Chain
**Scope:** Full pipeline from domain types through `TuningSystem.frequency()` to `SoundFontNotePlayer`, including the inverse `decompose()` path, MIDI pitch bend mechanics, and the `PlaybackHandle` adjustment chain
**Cross-reference:** [28.1 Audit Report](28-1-audit-report-interval-and-tuningsystem-domain-types.md)

---

## Executive Summary

The playback pipeline is well-engineered and mathematically correct. The forward path (logical → physical → MIDI) and the inverse path (Hz → MIDI note + cents → pitch bend) both work correctly within the musically relevant range. End-to-end precision is approximately 0.024 cents — well within the app's 0.1-cent target (NFR14).

**Key findings:**

- `decompose(frequency:)` is mathematically correct — it is the exact inverse of `TuningSystem.frequency()`
- `pitchBendValue(forCents:)` correctly maps the ±200 cent range to 14-bit MIDI pitch bend, with a 1-LSB asymmetry at the positive extreme that causes 0.024 cents of error
- `sendPitchBendRange()` correctly configures ±2 semitones via MIDI RPN — fully MIDI-spec-compliant
- `adjustFrequency()` does NOT introduce cumulative error — the decompose-reconstruct identity is exact in floating point
- The `NotePlayer` protocol boundary (taking `Frequency`) is the correct abstraction
- The pipeline handles non-12-TET intervals correctly — tested with just P5 (+1.955¢) and just M3 (-13.686¢)
- No hidden 12-TET assumptions exist in the playback layer — all "12" and "100" values are MIDI spec definitions, not tuning choices

**Verdict:** No blocking issues. Two findings warrant documentation; one edge case is theoretically imprecise but practically unreachable. The pipeline is ready for non-12-TET tuning systems.

---

## Per-Component Assessments

### 1. `NotePlayer.swift` — Protocol + AudioError

**Framework:** Protocol-oriented audio abstraction

| Aspect | Assessment | Rationale |
|---|---|---|
| `play(frequency:velocity:amplitudeDB:) → PlaybackHandle` | **Correct** | Returns a handle for ongoing pitch manipulation (pitch matching mode). `Frequency` parameter correctly insulates the protocol from tuning knowledge. |
| `play(frequency:duration:velocity:amplitudeDB:)` | **Correct** | Convenience for fixed-duration playback (comparison mode). Default implementation in extension calls the handle-returning variant, sleeps, then stops — clean delegation. |
| Duration guard `> 0` | **Correct** | Zero or negative duration is a programming error. Throwing `AudioError.invalidDuration` is appropriate. |
| `stopAll()` | **Correct** | Global silence control. Single responsibility — stop everything on the channel. |
| `AudioError` enum | **Correct** | Appropriate error cases covering all failure modes: engine start, invalid frequency, invalid duration, invalid preset, context unavailable, invalid interval. |
| Error handling in duration convenience | **Correct** | Catch block calls `handle.stop()` before rethrowing — prevents orphaned notes on cancellation. Uses `try?` for stop to avoid masking the original error. |

**Hidden assumptions:** None. The protocol is tuning-agnostic and framework-agnostic.

### 2. `TuningSystem.frequency()` → `NotePlayer.play()` Data Flow

**Framework:** Explicit parameter passing, no hidden state

| Caller | Assessment | Rationale |
|---|---|---|
| `ComparisonSession.playComparisonNotes()` (line 252–253) | **Correct** | Calls `comparison.referenceFrequency(tuningSystem: sessionTuningSystem, referencePitch: settings.referencePitch)` — explicit `tuningSystem` and `referencePitch`, no defaults. |
| `PitchMatchingSession.playNextChallenge()` (line 236–254) | **Correct** | Calls `sessionTuningSystem.frequency(for: challenge.referenceNote, referencePitch: settings.referencePitch)` — same explicit parameter pattern. |
| `Comparison.referenceFrequency()` / `targetFrequency()` | **Correct** | Pure delegation to `tuningSystem.frequency(for:referencePitch:)`. Both require explicit `tuningSystem` and `referencePitch` parameters. No hidden state, no defaults. |

**Confirmed from 28.1:** The `frequency(for:referencePitch:)` formula (`ref × 2^(totalCents / 1200)`) is universal — the MIDI-grid-based intermediate variables are artifacts of the MIDI spec, not tuning assumptions. Cross-reference: 28.1 Finding F-3.

### 3. `SoundFontNotePlayer.startNote()` — Play Sub-operation Sequence

**Framework:** MIDI 1.0 specification, AVAudioUnitSampler API

```
decompose(frequency) → (midiNote, cents)
pitchBendValue(cents) → 14-bit bend value
sampler.overallGain = amplitudeDB        ← set volume
sampler.sendPitchBend(bend, channel)     ← set pitch bend
sampler.startNote(midiNote, velocity, channel) ← trigger note
```

| Aspect | Assessment | Rationale |
|---|---|---|
| Operation order | **Correct** | Pitch bend MUST be set before `startNote()` to avoid audible pitch slide from center to target. Gain set before note start ensures correct initial volume. |
| decompose before bend | **Correct** | The frequency must be split into MIDI note + cents before the pitch bend can be computed. Logical dependency correctly reflected in code order. |
| Return value (midiNote) | **Correct** | The MIDI note is stored in `SoundFontPlaybackHandle` for later `adjustFrequency()` and `stopNote()` calls. |

**No issues found.** The sequence is idiomatic MIDI playback.

### 4. `SoundFontNotePlayer.decompose(frequency:)` — Hz → MIDI Inverse

**Framework:** MIDI 1.0 specification (A4 = MIDI 69 = 440 Hz, 12 semitones/octave)

The implementation:
```swift
let exactMidi = 69.0 + 12.0 * log2(frequency.rawValue / 440.0)
let roundedMidi = Int(exactMidi.rounded())
let centsRemainder = (exactMidi - Double(roundedMidi)) * 100.0
let clampedMidi = roundedMidi.clamped(to: 0...127)
```

#### Mathematical Verification

This is the exact inverse of `TuningSystem.frequency()`:

| Direction | Formula |
|---|---|
| Forward | `f = ref × 2^((midi - 69 + cents/100) / 12)` |
| Inverse | `exactMidi = 69 + 12 × log₂(f / 440)` |

Substituting the forward formula into the inverse:
```
exactMidi = 69 + 12 × log₂(ref × 2^((midi-69+c/100)/12) / 440)
          = 69 + 12 × log₂(2^((midi-69+c/100)/12))  [when ref=440]
          = 69 + (midi - 69 + c/100)
          = midi + c/100
```

So `decompose` recovers the exact MIDI value (note + cents/100) that was used to generate the frequency. The round-trip is mathematically exact.

#### Rounding Analysis

| exactMidi | roundedMidi | centsRemainder | Range |
|---|---|---|---|
| 69.0 | 69 | 0.0 | Center |
| 69.49 | 69 | +49.0 | Near boundary |
| 69.50 | 70 | -50.0 | Boundary (rounds up) |
| 69.51 | 70 | -49.0 | Just past boundary |

Swift's `.rounded()` uses `.toNearestOrAwayFromZero`, so half-values always round away from zero. The cents remainder range is **[-50.0, +50.0)** — asymmetric by one quantization step at the boundary. This is correct behavior: every frequency maps to exactly one MIDI note, and the cents remainder is always within ±50 cents (half a semitone).

#### Clamping Edge Case

| Aspect | Assessment | Rationale |
|---|---|---|
| Clamping to 0–127 | **Correct with caveat** | See Finding F-1 below. Clamping is applied AFTER computing `centsRemainder`, so the cents refer to the unclamped MIDI note, not the clamped one. This creates incorrect results for frequencies outside the MIDI range. |
| Practical impact | **None** | The `validFrequencyRange` (20–20000 Hz) gates all inputs. MIDI 0 ≈ 8.2 Hz (below 20 Hz minimum) and MIDI 127 ≈ 12544 Hz. Only frequencies 12544–20000 Hz could theoretically hit the clamping issue, and these are outside the musical range of any SF2 instrument. |

**Assessment: Correct.** The formula is mathematically sound, and the clamping edge case is unreachable in practice.

### 5. `SoundFontNotePlayer.pitchBendValue(forCents:)` — Cents to 14-bit MIDI

**Framework:** MIDI 1.0 specification, pitch bend message format

The implementation:
```swift
let raw = Int(8192.0 + cents.rawValue * 8192.0 / 200.0)
let clamped = Swift.min(16383, Swift.max(0, raw))
```

#### Formula Verification

MIDI pitch bend is a 14-bit value (0–16383) with 8192 as center (no bend). With the pitch bend range configured to ±2 semitones (±200 cents):

| Input (cents) | Expected | Computed | Result |
|---|---|---|---|
| 0 | 8192 (center) | 8192 + 0 = 8192 | **Correct** |
| +100 (1 semitone up) | 12288 | 8192 + 4096 = 12288 | **Correct** |
| -100 (1 semitone down) | 4096 | 8192 - 4096 = 4096 | **Correct** |
| +200 (max up) | 16383 | 8192 + 8192 = 16384 → clamped to 16383 | **Correct** (1-LSB clamp) |
| -200 (max down) | 0 | 8192 - 8192 = 0 | **Correct** |
| +50 | 10240 | 8192 + 2048 = 10240 | **Correct** |
| -50 | 6144 | 8192 - 2048 = 6144 | **Correct** |

#### Asymmetry Analysis

The 14-bit MIDI range is inherently asymmetric: 8192 steps down (8192 → 0) but only 8191 steps up (8192 → 16383). This is a MIDI spec limitation, not a code bug. The maximum positive bend reaches 16383 instead of 16384, causing a 0.024-cent shortfall at exactly +200 cents:

```
Max upward bend: (16383 - 8192) / 8192 × 200 = 199.976 cents
Max downward bend: (0 - 8192) / 8192 × 200 = -200.000 cents
```

The 0.024-cent asymmetry is well below the 0.1-cent precision target.

**Assessment: Correct.** Standard MIDI pitch bend mapping with appropriate clamping.

### 6. `sendPitchBendRange()` — RPN Configuration

**Framework:** MIDI 1.0 specification, Registered Parameter Numbers (RPN)

The implementation:
```swift
sampler.sendController(101, withValue: 0, onChannel: channel)  // RPN MSB = 0
sampler.sendController(100, withValue: 0, onChannel: channel)  // RPN LSB = 0
sampler.sendController(6,   withValue: 2, onChannel: channel)  // Data Entry MSB = 2
sampler.sendController(38,  withValue: 0, onChannel: channel)  // Data Entry LSB = 0
```

#### MIDI Spec Compliance

| Step | CC# | Value | MIDI Spec Meaning | Verdict |
|---|---|---|---|---|
| 1 | 101 | 0 | RPN MSB = 0x00 (Pitch Bend Sensitivity) | **Correct** |
| 2 | 100 | 0 | RPN LSB = 0x00 (confirms Pitch Bend Sensitivity) | **Correct** |
| 3 | 6 | 2 | Data Entry MSB = 2 (2 semitones) | **Correct** |
| 4 | 38 | 0 | Data Entry LSB = 0 (0 cents fine tuning) | **Correct** |

This configures pitch bend sensitivity to exactly ±2 semitones (±200 cents). The sequence follows the MIDI spec precisely: select parameter (CC#101/100), then set value (CC#6/38).

#### Timing and Race Conditions

| Aspect | Assessment | Rationale |
|---|---|---|
| Called in `init()` after `loadSoundBankInstrument` | **Correct** | Audio engine is running and instrument is loaded before RPN is sent. |
| Called in `loadPreset()` after instrument change | **Correct** | Preset changes may reset pitch bend sensitivity; re-sending ensures it's correct. |
| No "null RPN" terminator | **Acceptable** | Best practice recommends sending CC#101=127, CC#100=127 after setting an RPN to prevent accidental changes. `AVAudioUnitSampler` does not require this — the sampler processes the RPN synchronously and no other code sends CC#6/38. |
| Race condition with `startNote()` | **None** | `sendPitchBendRange()` is called synchronously within `loadPreset()`, which is `async` and awaited by callers. By the time `startNote()` executes, the RPN has been processed. |

**Assessment: Correct.** Fully MIDI-spec-compliant RPN sequence with no race conditions.

### 7. `SoundFontPlaybackHandle.adjustFrequency()` — Live Pitch Adjustment

**Framework:** MIDI pitch bend for real-time pitch manipulation

The implementation:
```swift
let decomposed = SoundFontNotePlayer.decompose(frequency: frequency)
let targetMidi = Double(decomposed.note) + decomposed.cents / 100.0
let baseMidi = Double(midiNote)
let centDifference = (targetMidi - baseMidi) * 100.0

guard abs(centDifference) <= 200.0 else { throw ... }

let bendValue = SoundFontNotePlayer.pitchBendValue(forCents: Cents(centDifference))
sampler.sendPitchBend(bendValue, onChannel: channel)
```

#### Mathematical Verification

**Key insight:** `decompose` is an identity operation for `targetMidi` reconstruction.

Given `decompose` returns `(roundedMidi, centsRemainder)` where `centsRemainder = (exactMidi - roundedMidi) * 100`:

```
targetMidi = roundedMidi + centsRemainder / 100
           = roundedMidi + (exactMidi - roundedMidi)
           = exactMidi
```

So `targetMidi` exactly equals the true MIDI position of the target frequency. **No floating-point error is introduced by the decompose-reconstruct step.** The decomposition is algebraically exact.

#### Worked Example

Base note: MIDI 69 (A4, 440 Hz), original pitch bend at +30 cents.
Target: 466.16 Hz (B♭4)

1. decompose(466.16) → exactMidi = 69 + 12 × log₂(466.16/440) = 70.0 → (note: 70, cents: 0.0)
2. targetMidi = 70.0
3. centDifference = (70.0 - 69) × 100 = 100.0
4. pitchBendValue(100) = 8192 + 100 × 8192/200 = 12288
5. sendPitchBend(12288) → MIDI note 69 bent up 100 cents = B♭4 ✅

**Critical correctness point:** `sendPitchBend` is absolute (replaces the previous bend), not relative. The centDifference is computed from `baseMidi` (the sounding MIDI note), not from the previous bend value. This is correct — each `adjustFrequency()` call independently sets the bend to reach the target frequency from the base note.

#### ±200 Cent Guard

| Aspect | Assessment | Rationale |
|---|---|---|
| Guard value: 200 cents | **Correct** | Matches the ±2 semitone pitch bend range set by `sendPitchBendRange()`. |
| Error on exceed | **Correct** | Throwing `AudioError.invalidFrequency` prevents silent clipping of pitch bend. The caller can handle the error gracefully. |
| Non-12-TET impact | **Minimal** | The largest common interval deviation from 12-TET is ~31 cents (septimal minor seventh). The ±200 cent limit constrains only quarter-tone or larger deviations from the base MIDI note, which are outside the app's scope. |

**Assessment: Correct.** No cumulative error, correct guard bounds, correct pitch bend semantics.

### 8. `SoundFontPlaybackHandle.stop()` — Note Termination

**Framework:** MIDI noteOff, audio render pipeline

| Aspect | Assessment | Rationale |
|---|---|---|
| Idempotent via `hasStopped` | **Correct** | Prevents double-stop issues. Multiple `stop()` calls are safe. |
| Fade-out: volume → 0, sleep, stopNote | **Correct** | Muting before stopping prevents click/pop artifacts from abrupt sample termination. The 25ms delay covers 2+ audio render cycles at 44.1kHz/512 samples. |
| Pitch bend reset to center | **Correct** | Prevents stale pitch bend affecting the next note on the same channel. |
| Volume restore to 1.0 | **Correct** | Ensures the next `startNote()` call produces sound. |
| Stop sequence order | **Correct** | mute → wait → stopNote → resetBend → restore. The noteOff must happen before the bend reset to avoid the note briefly sounding at the wrong pitch during stop. |

**Assessment: Correct.** Clean stop sequence with proper artifact prevention.

### 9. `PlaybackHandle.swift` — Protocol

**Framework:** Audio playback lifecycle abstraction

| Aspect | Assessment | Rationale |
|---|---|---|
| `stop()` method | **Correct** | Minimal lifecycle management. |
| `adjustFrequency(_ frequency: Frequency)` | **Correct** | Takes `Frequency` (physical world), not `DetunedMIDINote` (logical world). This maintains the tuning-agnostic boundary. |
| Protocol scope | **Correct** | Two methods — stop and adjust. No knowledge of MIDI, tuning, or playback mechanism. |

**Assessment: Correct.** The protocol is appropriately minimal and tuning-agnostic.

---

## End-to-End Precision Analysis

### Forward Chain: DetunedMIDINote → Hz → MIDI + Pitch Bend → Sound

**Test case: Just intonation P5 above A4 (ratio 3:2, +1.955¢ from 12-TET)**

| Step | Operation | Value | Error |
|---|---|---|---|
| 1 | `DetunedMIDINote(76, +1.955¢)` | Input | — |
| 2 | `TuningSystem.frequency()` | 659.9999... Hz | < 10⁻¹² Hz (Double precision) |
| 3 | `decompose(660.0)` | (note: 76, cents: 1.955) | Exact (algebraic identity) |
| 4 | `pitchBendValue(1.955)` | 8272 | Quantization: 0.002¢ |
| 5 | Sounding frequency | 659.995 Hz | 0.002¢ from target |

**Cumulative error: ~0.002 cents** — the only precision loss is the 14-bit pitch bend quantization.

### Pitch Bend Resolution

| Parameter | Value |
|---|---|
| Bit depth | 14 bits (0–16383) |
| Range | ±200 cents (400 cents total) |
| Resolution | 400 / 16384 = **0.0244 cents/step** |
| Steps per 0.1 cent | ~4.1 steps |
| Sufficient for NFR14 (0.1¢)? | **Yes — 4× margin** |

### adjustFrequency() Double-Decompose

As proven in the component assessment (Section 7), the decompose-reconstruct identity `roundedMidi + (exactMidi - roundedMidi) / 100 × 100 = exactMidi` is algebraically exact. **No additional error is introduced by the double-decompose path.**

The only quantization point in the entire pipeline is `pitchBendValue()` (Int truncation of the 14-bit value), which introduces at most 0.0244 cents of error per pitch bend operation.

### Precision Budget

| Source | Maximum Error | Notes |
|---|---|---|
| `TuningSystem.frequency()` | < 10⁻¹² ¢ | Double-precision floating point |
| `decompose()` | 0.0 ¢ | Algebraic identity, exact |
| `pitchBendValue()` | 0.0244 ¢ | 14-bit quantization |
| `adjustFrequency()` reconstruction | 0.0 ¢ | Uses decompose identity |
| **Total worst case** | **≤ 0.025 ¢** | **4× below 0.1¢ target** |

---

## Non-12-TET Generalizability Assessment

### Test Case 1: Just Intonation P5 (+1.955¢ from 12-TET)

A just perfect fifth from A4 (440 Hz) should produce exactly 660.000 Hz (3:2 ratio).

| Step | Result | Correct? |
|---|---|---|
| `DetunedMIDINote(76, +1.955¢)` | Logical input | ✅ |
| `frequency()` = 440 × 2^(7.01955/12) | 660.000 Hz | ✅ Matches 3:2 ratio |
| `decompose(660.0)` | (76, +1.955¢) | ✅ Same MIDI note as 12-TET |
| `pitchBendValue(1.955)` | 8272 | ✅ Within ±200 cent range |
| Sounding frequency | ~660.0 Hz | ✅ Within 0.003¢ of target |

### Test Case 2: Just Intonation M3 (-13.686¢ from 12-TET)

A just major third from A4 should produce exactly 550.000 Hz (5:4 ratio). This is 13.686 cents flatter than the 12-TET major third.

| Step | Result | Correct? |
|---|---|---|
| `DetunedMIDINote(73, -13.686¢)` | Logical input | ✅ |
| `frequency()` = 440 × 2^(3.86314/12) | 550.000 Hz | ✅ Matches 5:4 ratio |
| `decompose(550.0)` | exactMidi = 72.863, rounds to **73** | ✅ Same MIDI note |
| cents remainder | -13.686¢ | ✅ Correct offset |
| `pitchBendValue(-13.686)` | 7632 | ✅ Within ±200 cent range |
| Sounding frequency | ~550.0 Hz | ✅ Within 0.024¢ of target |

**Key validation:** The `decompose()` function rounds to MIDI 73 (the same MIDI note as the 12-TET E5), not to MIDI 72. This is correct because -13.686¢ is within the ±50¢ rounding boundary. Even the most extreme just intonation interval deviation (septimal minor seventh: -31.2¢) stays within the ±50¢ rounding zone.

### 12-TET vs. MIDI-Spec vs. Hidden Assumption Classification

| Component | Uses "12" or "100" | Classification | Rationale |
|---|---|---|---|
| `decompose()`: `69 + 12 × log₂(f/440)` | Yes | **MIDI spec** | A4 = MIDI 69, 12 semitones/octave — these define the MIDI grid, not a tuning choice |
| `decompose()`: `centsRemainder × 100` | Yes | **MIDI spec** | 100 cents = 1 MIDI semitone — unit conversion from the MIDI grid |
| `pitchBendValue()`: `8192 / 200` | No "12" | **Configuration** | 200 = ±2 semitones, matching `sendPitchBendRange()` setting |
| `sendPitchBendRange()`: `CC#6 = 2` | No "12" | **Configuration** | 2 semitones chosen for musical range needs |
| `TuningSystem.frequency()`: `12.0`, `100.0` | Yes | **MIDI spec** (see 28.1 F-3) | Formula simplifies to universal `ref × 2^(totalCents/1200)` |
| `MIDINote.name`: 12-element array | Yes | **MIDI spec** | MIDI defines 12 pitch classes per octave |

**Verdict: No hidden 12-TET assumptions exist in the playback layer.** Every use of "12" or "100" traces back to the MIDI specification's definition of 12 notes per octave, which is an infrastructure reality (like TCP/IP using 8-bit bytes), not a musical assumption. Non-12-TET intervals are correctly handled through cent offsets from the MIDI grid.

### ±200 Cent Limit Impact on Non-12-TET

The `adjustFrequency()` guard rejects pitch adjustments exceeding ±200 cents from the base MIDI note. For non-12-TET intervals:

| Interval | Just Intonation Deviation from 12-TET | Within ±200¢? |
|---|---|---|
| P5 (3:2) | +1.955¢ | ✅ |
| P4 (4:3) | -1.955¢ | ✅ |
| M3 (5:4) | -13.686¢ | ✅ |
| m3 (6:5) | +15.641¢ | ✅ |
| M6 (5:3) | -15.641¢ | ✅ |
| m7 (7:4) | -31.174¢ | ✅ |
| M2 (9:8) | +3.910¢ | ✅ |
| m2 (16:15) | +11.731¢ | ✅ |

The largest deviation in the commonly used just intervals is ~31 cents (septimal minor seventh), well within ±200. Even quarter-tone intervals (50 cents) are within range.

**The ±200 cent limit does not constrain any realistic non-12-TET usage for this app.**

---

## NotePlayer Protocol Boundary Assessment

**Question:** Does taking `Frequency` (not `DetunedMIDINote`) correctly insulate the audio layer from tuning knowledge?

### Arguments For `Frequency` (Current Design)

1. **Clean separation:** The `NotePlayer` protocol knows nothing about MIDI notes, tuning systems, or intervals. It receives a physical frequency and produces sound.
2. **Future-proof:** A non-MIDI implementation (e.g., a real-time synthesizer) would work directly in Hz without needing MIDI decomposition.
3. **Testability:** `MockNotePlayer` doesn't need MIDI logic — it just records the frequency it received.
4. **Dependency direction:** The audio layer doesn't depend on domain types (`TuningSystem`, `DetunedMIDINote`). Knowledge flows one way: domain → audio.

### Arguments Against (Passing `DetunedMIDINote`)

1. **Redundant conversion:** `SoundFontNotePlayer` decomposes Hz back to MIDI internally — the Hz step is "wasted."
2. **Theoretical precision:** Passing `DetunedMIDINote` would skip the decompose step entirely.

### Verdict

**`Frequency` is the correct parameter type.** The decompose step introduces zero precision loss (algebraic identity) and at most 0.024 cents of pitch bend quantization error. The architectural benefits of a tuning-agnostic audio layer far outweigh the theoretical (and negligible) precision cost.

The protocol boundary is correct as-is.

---

## Findings Detail

### F-1: `decompose()` Clamping Produces Incorrect Results Outside MIDI Range (Correct — Informational)

**File:** `SoundFontNotePlayer.swift`, line 218
**Framework:** MIDI note range constraints

When `roundedMidi` exceeds 0–127, it is clamped after computing `centsRemainder`. The cents then refer to the unclamped MIDI note, not the clamped one:

```
Example: frequency at exactMidi = 128.5
  roundedMidi = 129, centsRemainder = -50
  clampedMidi = 127
  Return: (note: 127, cents: -50)

  Reconstruction: 127 + (-50)/100 = 126.5 ≠ 128.5 (original)
  Error: 200 cents
```

**Practical impact: None.** The `validFrequencyRange` (20–20000 Hz) gates all inputs. The only frequencies that could trigger this are 12544–20000 Hz (above MIDI 127 ≈ 12544 Hz). These are outside the pitched musical range of any SF2 instrument, and no ear training exercise uses them.

**Recommendation:** No code change needed. The clamping behavior is correct for the app's operating range. If the app ever needs to support frequencies above 12544 Hz (extremely unlikely), the clamping logic would need revision.

### F-2: Pitch Bend 1-LSB Asymmetry at +200 Cents (Correct — Informational)

**File:** `SoundFontNotePlayer.swift`, line 199
**Framework:** MIDI 1.0 pitch bend specification

The formula `8192 + cents × 8192 / 200` maps +200 cents to 16384, which is clamped to 16383. This means the maximum positive bend reaches 199.976 cents, not 200.000 cents — a 0.024-cent shortfall.

This is a fundamental MIDI spec limitation: the 14-bit range (0–16383) has 8192 steps down from center but only 8191 steps up. The asymmetry is irrelevant for practical use (0.024¢ is imperceptible and below the precision target).

**Recommendation:** No code change needed. This is inherent to the MIDI spec and correctly handled by clamping.

### F-3: No Null RPN Terminator After `sendPitchBendRange()` (Acceptable — Low Severity)

**File:** `SoundFontNotePlayer.swift`, line 179
**Framework:** MIDI 1.0 RPN best practices

MIDI best practice recommends sending a "null" RPN (CC#101=127, CC#100=127) after setting an RPN parameter to prevent accidental changes. The implementation omits this.

**Risk assessment:** Minimal. `AVAudioUnitSampler` processes MIDI CC messages synchronously. No other code in the app sends CC#6 or CC#38, so there's no risk of accidental parameter modification. The omission saves two MIDI CC messages per preset change.

**Recommendation:** Consider adding the null RPN terminator for defensive correctness, but it is not necessary for the current app. If the app ever sends arbitrary MIDI CC messages (e.g., from user input), the null terminator would become important.

### F-4: `stopAll()` Uses CC#123 (All Notes Off) — Correct But Worth Documenting

**File:** `SoundFontNotePlayer.swift`, line 122
**Framework:** MIDI 1.0 Channel Mode Messages

`sampler.sendController(123, withValue: 0, onChannel: channel)` sends the MIDI "All Notes Off" message (CC#123). This is the correct way to silence all notes on a channel. The combination with volume muting and pitch bend reset provides a complete silence operation.

**Assessment: Correct.** No issue — just noting the MIDI CC number for documentation.

---

## Hidden Assumption Inventory

| # | Assumption | Location | Severity | Impact on Non-12-TET |
|---|---|---|---|---|
| H-1 | Nearest-MIDI-note rounding in `decompose()` | `SoundFontNotePlayer.decompose()` | None | MIDI grid IS 12-note — this is infrastructure, not a tuning assumption. Non-12-TET offsets are correctly carried in the cents remainder. |
| H-2 | ±200 cent pitch bend range | `sendPitchBendRange()`, `adjustFrequency()` guard | None | All common non-12-TET deviations are within ±50 cents of the nearest MIDI note. The ±200 cent range provides 4× margin. |
| H-3 | Pitch bend is per-channel, affects all notes | MIDI spec, `sendPitchBend()` | None (for this app) | Peach plays one note at a time per mode. If polyphonic non-12-TET playback were needed, per-note pitch bend (MIDI 2.0) or multi-channel allocation would be required. Not applicable to the app's ear training scope. |
| H-4 | `decompose()` uses A4=440 Hz and 12 semitones/octave | `SoundFontNotePlayer.decompose()` | None | These are MIDI spec definitions. `decompose()` is mapping to the MIDI grid, which IS 12-TET by specification. Non-12-TET is handled by cent offsets from this grid. |
| H-5 | Single SF2 preset per note | `startNote()` sequence | None | All notes use the same preset. This is correct for ear training — the timbral consistency is desired. |

**No hidden 12-TET assumptions found.** All "12-TET-looking" code traces to the MIDI specification's grid definition, which is the correct infrastructure for encoding any tuning system via cent offsets.

---

## Recommendations Catalogue

These are catalogued for future implementation stories. **No code changes should be made in story 28.2.**

| # | Finding | Recommendation | Priority | Effort |
|---|---|---|---|---|
| R-1 | `decompose()` clamping (F-1) | Add a comment documenting that clamping loses precision outside MIDI 0–127, and that this is acceptable given `validFrequencyRange` | Low | Trivial |
| R-2 | Null RPN terminator (F-3) | Consider adding CC#101=127, CC#100=127 after `sendPitchBendRange()` for defensive MIDI hygiene | Low | Trivial |
| R-3 | Pitch bend range documentation | Add a comment linking `pitchBendValue()` range (200) to `sendPitchBendRange()` configuration (2 semitones) so the coupling is explicit | Low | Trivial |
| R-4 | `adjustFrequency()` algebraic identity | Add a comment explaining why the decompose-reconstruct does not lose precision — future developers may question the "double decompose" | Low | Trivial |
| R-5 | Cross-reference 28.1 recommendations | R-2 and R-3 from the 28.1 report (add doc comments to `centOffset(for:)` and `frequency()`) remain open | Low | Trivial |

---

## Conclusion

The Peach playback pipeline is mathematically correct, architecturally clean, and ready for non-12-TET tuning systems.

**Key strengths:**
- The `decompose()` inverse is algebraically exact — no precision is lost in the Hz → MIDI conversion
- The 14-bit MIDI pitch bend provides 0.024 cents/step resolution — 4× better than the 0.1-cent target
- The `NotePlayer` protocol boundary correctly insulates the audio layer from tuning knowledge
- All callers pass `tuningSystem` and `referencePitch` explicitly — no hidden state
- The ±200 cent pitch bend range accommodates all common non-12-TET interval deviations with margin

**What happens when a non-12-TET tuning system is added:**
1. A new `TuningSystem` case (e.g., `.justIntonation`) returns the interval's cent offset via `centOffset(for:)`
2. The training strategy creates `DetunedMIDINote` with the appropriate offset (e.g., MIDI 73 at -13.686¢ for a just major third above A4)
3. `TuningSystem.frequency()` converts to Hz using the universal formula — no changes needed
4. `SoundFontNotePlayer` decomposes back to the nearest MIDI note + cent remainder — no changes needed
5. The pitch bend correctly shifts the MIDI note to the just-tuned frequency — no changes needed

**No pipeline changes are required to support non-12-TET tuning systems.** The architecture is already general.

**Overall verdict: The pipeline is solid. Proceed with Epic 29 (tuning system research) and Epic 30 (implementation) with confidence.**

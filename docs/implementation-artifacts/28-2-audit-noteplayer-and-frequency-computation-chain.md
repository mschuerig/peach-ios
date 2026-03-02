# Story 28.2: Audit NotePlayer and Frequency Computation Chain

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer preparing to add alternative tuning systems**,
I want the music domain expert (Adam) to audit the full pipeline from domain types through `TuningSystem.frequency()` to `SoundFontNotePlayer` — including the inverse `decompose()` path, MIDI pitch bend mechanics, and the `PlaybackHandle` adjustment chain,
so that implementation-level errors, hidden assumptions, and precision issues are caught before building non-12-TET playback on these foundations.

## Acceptance Criteria

1. Adam reviews the complete forward pipeline: `TuningSystem.frequency(for:referencePitch:)` → `Frequency` → `NotePlayer.play(frequency:...)` → `SoundFontNotePlayer.startNote()` (decompose → pitch bend → MIDI noteOn)
2. Adam reviews the inverse pipeline: `SoundFontNotePlayer.decompose(frequency:)` — Hz → nearest MIDI note + cent remainder, verifying mathematical correctness and 12-TET labeling
3. Adam reviews `SoundFontNotePlayer.pitchBendValue(forCents:)` — cents-to-MIDI-pitch-bend conversion, range assumptions, and precision
4. Adam reviews `SoundFontPlaybackHandle.adjustFrequency()` — cent difference computation from base note, ±200 cent hard limit, and implications for non-12-TET intervals
5. Adam reviews `sendPitchBendRange()` — RPN-based ±2 semitone pitch bend range configuration, MIDI spec compliance
6. The end-to-end precision chain is verified: can the pipeline maintain ≤0.1-cent accuracy from `DetunedMIDINote` → Hz → decompose → MIDI note + pitch bend → sounding frequency?
7. Adam assesses the pipeline's behavior when a non-12-TET tuning system is added (e.g., just intonation intervals producing cent offsets > 50¢ from the 12-TET grid)
8. Hidden 12-TET assumptions in the playback layer are explicitly flagged (vs. MIDI-spec requirements that happen to use 12)
9. The `NotePlayer` protocol boundary is assessed: does taking `Frequency` (not `DetunedMIDINote`) correctly insulate the audio layer from tuning knowledge?
10. Audit report is saved as a document in `docs/implementation-artifacts/`
11. If findings require code changes, they are catalogued as recommendations (not implemented in this story)

## Tasks / Subtasks

- [x] Task 1: Load the Adam agent persona (`/bmad-agent-music-domain-expert`) (AC: #1)
- [x] Task 2: Audit the forward pipeline — TuningSystem → Frequency → NotePlayer (AC: #1, #8, #9)
  - [x] 2.1 `NotePlayer.swift` — protocol design, `Frequency`-based API, default duration extension, `stopAll()`
  - [x] 2.2 `TuningSystem.frequency(for:referencePitch:)` → `NotePlayer.play()` data flow — confirm sessions pass explicit `tuningSystem` and `referencePitch` (no defaults)
  - [x] 2.3 `Comparison.swift` — `referenceFrequency()` and `targetFrequency()` convenience methods
- [x] Task 3: Audit the SoundFont playback sub-operations (AC: #1, #2, #3, #5)
  - [x] 3.1 `SoundFontNotePlayer.startNote()` — decompose → pitchBendValue → overallGain → sendPitchBend → startNote sequence
  - [x] 3.2 `SoundFontNotePlayer.decompose(frequency:)` — Hz-to-MIDI inverse formula, rounding, clamping, cent remainder
  - [x] 3.3 `SoundFontNotePlayer.pitchBendValue(forCents:)` — cents-to-14-bit-MIDI-bend formula, ±200 cent assumption, clamping
  - [x] 3.4 `sendPitchBendRange()` — RPN CC#101/100/6/38 sequence, ±2 semitone range, MIDI spec compliance
- [x] Task 4: Audit the PlaybackHandle adjustment chain (AC: #4)
  - [x] 4.1 `SoundFontPlaybackHandle.adjustFrequency()` — centDifference computation from base MIDI note, ±200 cent guard
  - [x] 4.2 `SoundFontPlaybackHandle.stop()` — fade-out, noteOff, pitch bend reset sequence
- [x] Task 5: End-to-end precision analysis (AC: #6)
  - [x] 5.1 Forward chain: `DetunedMIDINote` → `TuningSystem.frequency()` → `decompose()` → MIDI note + pitch bend → sounding frequency — quantify cumulative error
  - [x] 5.2 Pitch bend resolution: 14-bit MIDI (0–16383) across ±200 cents = ~0.024 cents/step — is this sufficient for 0.1-cent target?
  - [x] 5.3 `adjustFrequency()` chain: target Hz → decompose → centDifference from base → pitchBendValue — does double-decompose introduce error?
- [x] Task 6: Non-12-TET generalizability assessment (AC: #7, #8)
  - [x] 6.1 Just intonation example: P5 at +1.955¢ from 12-TET — trace through full pipeline and verify correctness
  - [x] 6.2 Large-offset intervals: just M3 at -13.686¢ from 12-TET — does decompose round to the same MIDI note? Does pitch bend range cover it?
  - [x] 6.3 Identify which components are genuinely 12-TET-specific (MIDI grid) vs. which carry hidden 12-TET assumptions
  - [x] 6.4 Assess whether `adjustFrequency()` ±200 cent limit constrains non-12-TET pitch matching
- [x] Task 7: Write audit report (AC: #10, #11)
  - [x] 7.1 Per-component assessment (correct / suspect / wrong) with rationale
  - [x] 7.2 Precision analysis summary
  - [x] 7.3 Hidden assumption inventory
  - [x] 7.4 Non-12-TET readiness assessment
  - [x] 7.5 Recommendations catalogue (for future implementation stories)
  - [x] 7.6 Save report to `docs/implementation-artifacts/`

## Dev Notes

### This is a research/audit story — NOT a code implementation story

The dev agent for this story should:
1. Load the Adam agent persona via `/bmad-agent-music-domain-expert`
2. Use Adam's `#audit-assumptions` prompt to systematically review each file
3. Produce a written audit report as the primary deliverable
4. **Do NOT make code changes** — catalogue recommendations only

### Files to Audit

**Core pipeline (all in `Peach/Core/Audio/`):**

| File | Type | Key Concern |
|---|---|---|
| `NotePlayer.swift` | protocol + `AudioError` enum | Takes `Frequency` — correct abstraction? Default duration extension safety? |
| `SoundFontNotePlayer.swift` | `final class` (sole NotePlayer impl) | `decompose()` inverse formula, `pitchBendValue()` formula, `startNote()` sequence, `sendPitchBendRange()` RPN, preset switching |
| `SoundFontPlaybackHandle.swift` | `final class` (PlaybackHandle impl) | `adjustFrequency()` centDifference math, ±200 cent limit, stop fade-out |
| `PlaybackHandle.swift` | protocol | `stop()` + `adjustFrequency(Frequency)` — is Frequency the right parameter type? |
| `TuningSystem.swift` | `enum` | `frequency(for:referencePitch:)` formula (already audited in 28.1 — cross-reference, don't re-audit) |

**Session callers (trace call chain only, don't audit session logic):**

| File | Relevant Call |
|---|---|
| `Core/Training/Comparison.swift` | `.referenceFrequency(tuningSystem:referencePitch:)`, `.targetFrequency(...)` |
| `Comparison/ComparisonSession.swift:252-253` | Calls `comparison.referenceFrequency()` / `.targetFrequency()` |
| `PitchMatching/PitchMatchingSession.swift:236-254` | Calls `sessionTuningSystem.frequency(for:..., referencePitch:)` directly |

**Supporting domain types (already audited in 28.1 — reference only):**

| File | Relevance to Pipeline |
|---|---|
| `MIDINote.swift` | Input to `TuningSystem.frequency()`, output of `decompose()` |
| `DetunedMIDINote.swift` | Input to `TuningSystem.frequency()` with cent offset |
| `Frequency.swift` | Output of `TuningSystem.frequency()`, input to `NotePlayer.play()` |
| `Cents.swift` | Used in `pitchBendValue()`, `decompose()` remainder |
| `MIDIVelocity.swift` | Passed through to `sampler.startNote()` |
| `AmplitudeDB.swift` | Applied via `sampler.overallGain` |
| `SoundSourceID.swift` | Preset selection via `parseSF2Tag()` |

### Previous Story (28.1) Findings — Key Cross-References

Story 28.1 audited the domain types. Relevant findings for 28.2:

- **F-2:** `centOffset(for:)` is unused in production — the actual pipeline is: create `DetunedMIDINote` → pass to `frequency(for:referencePitch:)`
- **F-3:** `frequency()` formula is universal via cents mechanism despite 12-TET-looking constants. The formula `ref × 2^(totalCents / 1200)` works for any tuning system.
- **F-6:** `centOffset(for:)` unused in production — a design hook only
- **Architecture verdict:** Two-world bridge is sound. Forward conversion always goes through `TuningSystem`.

### Key Audit Questions for Adam

1. **Is `decompose(frequency:)` mathematically correct?** It computes `69 + 12 × log2(freq/440)`, rounds to nearest integer, and takes the cent remainder. Does rounding introduce asymmetric error? Does clamping to 0–127 lose information?

2. **Is `pitchBendValue(forCents:)` correct?** Formula: `8192 + cents × 8192 / 200`. This maps ±200 cents to the 14-bit MIDI range (0–16383). Is 200 cents the correct range given `sendPitchBendRange()` sets ±2 semitones?

3. **Does `sendPitchBendRange()` correctly configure ±2 semitones?** RPN sequence: CC#101=0, CC#100=0, CC#6=2, CC#38=0. Per MIDI spec, this should set pitch bend sensitivity to 2 semitones ± 0 cents. Is this correct?

4. **Does `adjustFrequency()` double-decompose correctly?** It decomposes the target frequency, then computes centDifference from the base MIDI note. Does this introduce cumulative floating-point error? Is the ±200 cent guard correct for a ±2 semitone range?

5. **End-to-end precision:** 14-bit MIDI pitch bend across ±200 cents gives ~0.024 cents/step. Given the app requires 0.1-cent precision (NFR14), is this sufficient? Are there other precision bottlenecks?

6. **Non-12-TET impact:** When just intonation is added, intervals will have cent offsets from 12-TET (e.g., P5 = +1.955¢, M3 = -13.686¢). These offsets enter at `DetunedMIDINote.offset`. Does the pipeline handle these correctly? Does `decompose()` round to the correct MIDI note?

7. **`NotePlayer` protocol boundary:** The protocol takes `Frequency` — the SoundFont layer internally decomposes back to MIDI. Is this the right abstraction? Would any caller benefit from the SoundFont layer receiving `DetunedMIDINote` directly?

8. **Preset switching and pitch bend range:** After `loadPreset()`, `sendPitchBendRange()` is called. Is the RPN guaranteed to take effect before the next `startNote()`? Is there a race condition?

### Architecture Context: Two-World Pipeline

```
Logical World           Bridge              Physical World          MIDI Layer
─────────────           ──────              ──────────────          ──────────
MIDINote ─────┐    TuningSystem             NotePlayer.play()       SoundFontNotePlayer
  +            ├──→ .frequency(for:  ──→ Frequency ──→              .startNote()
Cents ─────── │     referencePitch:)                                  ├─ decompose(freq) → MIDI note + ¢
(DetunedMIDINote)                                                     ├─ pitchBendValue(¢) → 14-bit bend
                                                                      ├─ sampler.sendPitchBend()
                                                                      └─ sampler.startNote()
```

**Inverse path (within SoundFont layer only):**
```
Frequency → decompose() → (UInt8 midiNote, Double cents)
         → pitchBendValue(cents) → UInt16 (0–16383)
```

### Existing Test Coverage

Tests in `PeachTests/Core/Audio/`:
- **`SoundFontNotePlayerTests.swift`** — 31 tests covering: protocol conformance, play/stop lifecycle, pitch bend calculations, SF2 tag parsing, preset switching, frequency decomposition (including round-trip verification through TuningSystem), cents remainder range verification
- **`TuningSystemTests.swift`** — 25 tests covering: cent offsets for all 13 intervals, frequency computation at various MIDI notes and reference pitches, sub-cent precision, storage identifiers, MIDINote convenience overload

### Output Deliverable

A markdown audit report saved to `docs/implementation-artifacts/` containing:
1. Per-component assessment (correct / suspect / wrong) with MIDI spec or acoustics framework cited
2. End-to-end precision analysis with quantified error bounds
3. Hidden assumption inventory (12-TET vs. MIDI-spec vs. genuine assumptions)
4. Non-12-TET readiness verdict for the playback pipeline
5. Recommendations catalogue (for future implementation stories)

### Project Structure Notes

- Pipeline files span `Core/Audio/` (domain types, NotePlayer, SoundFont*) and session files in `Comparison/` and `PitchMatching/`
- `Core/` is framework-free except `SoundFontNotePlayer.swift` and `SoundFontPlaybackHandle.swift` which import `AVFoundation`
- The `NotePlayer` protocol boundary ensures all code outside `Core/Audio/` is framework-free

### References

- [Source: Peach/Core/Audio/NotePlayer.swift] — NotePlayer protocol, AudioError enum, default duration extension
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift] — decompose(), pitchBendValue(), startNote(), sendPitchBendRange(), ensurePresetLoaded(), parseSF2Tag()
- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift] — adjustFrequency(), stop(), ±200 cent guard
- [Source: Peach/Core/Audio/PlaybackHandle.swift] — PlaybackHandle protocol
- [Source: Peach/Core/Audio/TuningSystem.swift] — frequency(for:referencePitch:), centOffset(for:) (cross-ref 28.1)
- [Source: Peach/Core/Audio/Frequency.swift] — Physical Hz, concert440
- [Source: Peach/Core/Audio/MIDINote.swift] — MIDI grid position 0–127
- [Source: Peach/Core/Audio/DetunedMIDINote.swift] — MIDINote + Cents offset
- [Source: Peach/Core/Audio/Cents.swift] — Microtonal offset
- [Source: Peach/Core/Audio/MIDIVelocity.swift] — MIDI velocity 1–127
- [Source: Peach/Core/Audio/AmplitudeDB.swift] — dB gain -90…12
- [Source: Peach/Core/Audio/SoundSourceID.swift] — SF2 preset tag
- [Source: Peach/Settings/UserSettings.swift] — UserSettings protocol with soundSource, tuningSystem, referencePitch
- [Source: Peach/Core/Training/Comparison.swift] — referenceFrequency(), targetFrequency()
- [Source: Peach/Comparison/ComparisonSession.swift:252-253] — Pipeline caller
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:236-254] — Pipeline caller
- [Source: docs/implementation-artifacts/28-1-audit-report-interval-and-tuningsystem-domain-types.md] — 28.1 audit report (cross-reference)
- [Source: docs/project-context.md] — Two-world architecture, domain rules, NFR14 (0.1-cent precision)
- [Source: PeachTests/Core/Audio/SoundFontNotePlayerTests.swift] — 31 tests including decompose round-trip
- [Source: PeachTests/Core/Audio/TuningSystemTests.swift] — 25 tests including frequency precision

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — research/audit story, no code changes or debugging.

### Completion Notes List

- Loaded Adam (Music Domain Expert) persona and applied `#audit-assumptions` methodology
- Audited all 9 pipeline components systematically: NotePlayer protocol, TuningSystem.frequency(), Comparison convenience methods, startNote() sequence, decompose(), pitchBendValue(), sendPitchBendRange(), adjustFrequency(), stop()
- Verified decompose() is the algebraically exact inverse of TuningSystem.frequency() — no precision loss
- Confirmed pitchBendValue() correctly maps ±200 cents to 14-bit MIDI pitch bend with 0.024 cents/step resolution
- Confirmed sendPitchBendRange() is fully MIDI-spec-compliant (RPN sequence CC#101/100/6/38)
- Proved adjustFrequency() double-decompose introduces zero cumulative error (algebraic identity)
- End-to-end precision: ≤0.025 cents worst case — 4× below the 0.1-cent NFR14 target
- Traced just P5 (+1.955¢) and just M3 (-13.686¢) through the full pipeline — both handled correctly
- Classified all "12-TET-looking" code as MIDI spec definitions, not hidden tuning assumptions
- Confirmed ±200 cent pitch bend range accommodates all common non-12-TET deviations
- Assessed NotePlayer protocol boundary — Frequency is the correct parameter type
- Catalogued 5 recommendations for future stories (all low priority, documentation-only)
- No blocking issues found — pipeline is ready for non-12-TET tuning systems

### Change Log

- 2026-03-02: Completed audit of NotePlayer and frequency computation chain (story 28.2)

### File List

- `docs/implementation-artifacts/28-2-audit-report-noteplayer-and-frequency-computation-chain.md` (new) — Comprehensive audit report
- `docs/implementation-artifacts/28-2-audit-noteplayer-and-frequency-computation-chain.md` (modified) — Story file updated with task completion, Dev Agent Record, File List, Change Log, Status

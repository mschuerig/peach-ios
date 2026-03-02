# Audit Report: Interval and TuningSystem Domain Types

**Auditor:** Adam (Music Domain Expert)
**Date:** 2026-03-02
**Story:** 28.1 — Audit Interval and TuningSystem Domain Types
**Scope:** `Peach/Core/Audio/` — Interval, DirectedInterval, Direction, TuningSystem, MIDINote, DetunedMIDINote, Frequency, Cents

---

## Executive Summary

The domain type layer is well-designed for its current purpose: an ear training app operating within 12-TET. The two-world architecture (logical vs. physical, bridged by TuningSystem) is sound and cleanly implemented. Most types are musically correct within their stated scope.

**Key findings:**

- The `frequency(for:referencePitch:)` formula is mathematically correct and, despite surface appearance, generalizable via the cents mechanism
- `centOffset(for:)` has a hidden scope limitation: it assumes interval size is independent of scale position — true for equal temperaments, false for just intonation and historical tunings
- The tritone abbreviation "d5" privileges one enharmonic interpretation
- `MIDINote.name` sharps-only is a documented 12-TET display simplification, acceptable for the app's scope
- The architecture holds for adding "fixed-ratio" tuning variants (where each interval has one cent value regardless of root) but not for position-dependent tunings

**Verdict:** No blocking issues. Several findings warrant documentation or minor changes catalogued as recommendations below.

---

## Per-Type Assessments

### 1. `Interval.swift` — Semitone distance enum

**Framework:** Standard Western music theory interval classification (Common Practice Period)

| Aspect | Assessment | Rationale |
|---|---|---|
| Enum design (13 cases, P1–P8) | **Correct** | Covers all simple intervals in the chromatic scale. Compound intervals (> octave) intentionally excluded per app scope. |
| Raw value = semitone count | **Correct with caveat** | 1:1 mapping works in 12-TET where intervals ARE semitone distances. In just intonation, intervals are frequency ratios, and "major third" means 5:4 (~386¢), not "4 semitones" (400¢). The enum treats intervals as chromatic distance classes — valid in 12-TET, an approximation in other systems. |
| `between()` using `abs()` | **Correct** | Computes unsigned distance. Direction is a separate concern properly handled by `DirectedInterval.between()`. No information is lost because the original MIDI values are available to the caller. |
| `between()` throwing for > 12 semitones | **Correct for scope** | Enforces single-octave constraint. The app trains intervals within one octave. Callers (e.g., `TrainingDataStore`) use `try?` with fallback to 0, which is safe. |
| Case names | **Correct** | Standard music theory nomenclature. "Prime" (vs. "Unison") follows European convention — both are standard. |
| Abbreviations | **Suspect** (tritone only) | See Finding F-1 below. All other abbreviations (P1, m2, M2, … P8) follow standard notation. |
| Localized names | **Correct** | "Tritone" is the musically neutral name for the 6-semitone interval. |
| `Comparable` ordering | **Correct** | Ordering by semitone count is musically meaningful. |

**Hidden 12-TET assumptions:** The core assumption is that an interval's identity IS its semitone count. This is a 12-TET equivalence. In just intonation, a "major third" (5:4) and a "diminished fourth" (32:25) are different intervals that happen to be the same semitone distance. For the app's purpose — training the ear to recognize interval *sizes* — the semitone-based model is appropriate.

### 2. `DirectedInterval.swift` — Directed interval struct

**Framework:** Interval classification with ascending/descending direction

| Aspect | Assessment | Rationale |
|---|---|---|
| `between()` delegation pattern | **Correct** | Computes unsigned distance via `Interval.between()`, then derives direction from `target.rawValue >= reference.rawValue`. No information loss — direction is derived from the original MIDI values, not reconstructed from the interval. |
| Prime handling | **Correct** | `down(.prime)` normalizes to `.prime` (up). Prime has no meaningful direction. `displayName` omits direction for prime. |
| `Comparable` ordering | **Reasonable** | Orders by interval size first, then direction (up < down). No standard musical ordering for directed intervals exists, so this is a valid implementation choice. |
| `MIDINote.transposed(by:)` | **Correct** | `precondition` on MIDI range is appropriate — out-of-range transposition is a programming error, not a user input error. |

**Hidden assumptions:** None found. The type cleanly composes `Interval` + `Direction`.

### 3. `Direction.swift` — Binary direction enum

**Framework:** Pitch movement direction in single-interval training

| Aspect | Assessment | Rationale |
|---|---|---|
| Binary up/down model | **Correct for scope** | Sufficient for single-interval ear training. "Oblique motion" (counterpoint concept) is irrelevant here. |
| `Comparable` ordering (up < down) | **Arbitrary but consistent** | No musical basis for ordering directions. Needed for `DirectedInterval.Comparable`. |

**Hidden assumptions:** None. The model is honest about its scope.

### 4. `TuningSystem.swift` — Tuning system enum and frequency bridge

**Framework:** Equal temperament (12-TET), with design hooks for alternative tunings

| Aspect | Assessment | Rationale |
|---|---|---|
| `centOffset(for:)` — 12-TET | **Correct** | `semitones × 100.0` is the definition of 12-TET. |
| `centOffset(for:)` — API shape | **Suspect** | See Finding F-2 below. The signature assumes interval → cent offset is a pure function of interval alone. This holds only for equal temperaments. |
| `frequency(for:referencePitch:)` formula | **Correct** | See Section "Formula Verification" below. |
| `frequency()` generalizability | **Correct** | See Finding F-3 below — the formula is more general than it appears. |
| Enum (not protocol) design | **Correct for scope** | Enables `CaseIterable` for Settings picker, `Codable` for storage. Appropriate for a small, known set of tuning systems. |
| Storage identifiers | **Correct** | String-based identifiers decouple persistence from enum raw values. |

**Hidden 12-TET assumptions:**

1. **`centOffset(for:)`** — see Finding F-2
2. **`frequency()` constants** — `semitonesPerOctave = 12.0` and `centsPerSemitone = 100.0` appear 12-TET-specific, but the formula simplifies to `ref × 2^(totalCents / 1200)`, which is universal (see Formula Verification)

#### Formula Verification

The implementation:
```swift
let semitones = Double(note.note.rawValue - 69) + note.offset.rawValue / 100.0
return Frequency(referencePitch.rawValue * pow(2.0, semitones / 12.0))
```

Expanding:
```
f = ref × 2^((midi - 69)/12 + cents/1200)
```

- `(midi - 69)/12`: MIDI note offset from A4, converted to octaves. MIDI defines 12 notes per octave — this is the MIDI spec, not a tuning assumption.
- `cents/1200`: Cent offset converted to octaves. 1200 cents = 1 octave by universal definition.

**Verification with known values:**

| Input | Expected | Computed | Result |
|---|---|---|---|
| A4 (MIDI 69, 0¢, ref 440) | 440.000 Hz | 440 × 2^(0/12) = 440.000 | ✅ |
| C4 (MIDI 60, 0¢, ref 440) | 261.626 Hz | 440 × 2^(−9/12) = 261.626 | ✅ |
| A4 + 50¢ (MIDI 69, 50¢, ref 440) | 452.893 Hz | 440 × 2^(0.5/12) = 452.893 | ✅ |
| Just P5 above A4 (MIDI 76, +1.955¢, ref 440) | 660.000 Hz | 440 × 2^(7.01955/12) = 660.000 | ✅ |

The formula is correct. The last row demonstrates that non-12-TET intervals work correctly when encoded as MIDI note + cent offset.

### 5. `MIDINote.swift` — MIDI grid position

**Framework:** MIDI 1.0 specification, Scientific Pitch Notation

| Aspect | Assessment | Rationale |
|---|---|---|
| Range 0–127 | **Correct** | Standard MIDI spec. |
| `name` — sharps only | **Correct with caveat** | See Finding F-4. Acceptable for ear training display. |
| Octave numbering | **Correct** | `(rawValue / 12) - 1` yields C-1 for MIDI 0, C4 for MIDI 60, A4 for MIDI 69. Standard scientific pitch notation. |
| `random(in:)` | **Correct** | Uniform distribution across MIDI range. Musical weighting (e.g., within a scale) is the strategy layer's responsibility, not MIDINote's. |
| `ExpressibleByIntegerLiteral` | **Correct** | Convenience for test fixtures and literals. |

**Hidden 12-TET assumptions:** The `name` property uses a 12-element pitch class array, which is inherent to MIDI's 12-notes-per-octave grid. MIDI itself is a 12-TET system by specification, so this is not a hidden assumption — it's the standard's definition.

### 6. `DetunedMIDINote.swift` — MIDI note with microtonal offset

**Framework:** Microtonal pitch representation (grid position + deviation)

| Aspect | Assessment | Rationale |
|---|---|---|
| `MIDINote` + `Cents` composition | **Correct** | Clean separation: MIDI note gives chromatic grid position, cents provides microtonal precision. |
| No frequency knowledge | **Correct** | Properly lives in the logical world. Conversion goes through `TuningSystem`. |
| Signed offset semantics | **Correct** | Positive = sharper, negative = flatter. Universal convention. |
| No offset range constraint | **Correct** | Large offsets (e.g., +200¢ = 2 semitones) are valid. Normalization is the caller's responsibility if needed. |
| Convenience `init(_ note:)` | **Correct** | Defaults offset to 0¢, representing an on-grid note. |

**Hidden assumptions:** None found. The type is a clean logical-world value.

### 7. `Frequency.swift` — Physical frequency in Hz

**Framework:** Acoustic physics, ISO 16 standard pitch

| Aspect | Assessment | Rationale |
|---|---|---|
| `rawValue: Double` | **Correct** | Hz as floating-point. |
| Positive-only precondition | **Correct** | Physical frequencies are positive by definition. |
| `concert440` constant | **Correct** | A4 = 440 Hz per ISO 16. Orchestras may tune differently, but 440 Hz is the standard reference. |
| Literal conformances | **Correct** | Convenience for tests and construction. |

**Hidden assumptions:** None. The type is a pure physical-world container.

### 8. `Cents.swift` — Universal microtonal measurement

**Framework:** Alexander Ellis's cent system (1885), adopted universally in acoustics and music theory

| Aspect | Assessment | Rationale |
|---|---|---|
| Universality claim | **Correct** | "1/1200 of an octave" is universal. The cent's origin is 12-TET (100¢ per semitone), but its definition depends only on the octave (2:1 ratio), which is a near-universal acoustic reality. The `Cents` type carries no 12-TET-specific semantics. |
| `magnitude` property | **Correct** | Absolute value — "how far off?" without caring about direction. |
| Signed value | **Correct** | Standard convention: positive = sharp, negative = flat. |
| No range constraint | **Correct** | Any microtonal distance is representable. |

**Hidden assumptions:** None. The one theoretical edge case — tuning systems that stretch the octave (e.g., some piano tuning practices where the octave is slightly wider than 2:1) — would still use cents as a measurement unit, just with values slightly different from 1200 per octave. This is a measurement precision concern, not a type design issue.

---

## Two-World Architecture Assessment

### Logical World Verification

| Type | Carries frequency/tuning knowledge? | Verdict |
|---|---|---|
| `MIDINote` | No — pure grid index | ✅ Clean |
| `DetunedMIDINote` | No — MIDI note + cent offset | ✅ Clean |
| `Interval` | No — semitone distance | ✅ Clean |
| `DirectedInterval` | No — interval + direction | ✅ Clean |
| `Direction` | No — up/down enum | ✅ Clean |
| `Cents` | No — universal measurement unit | ✅ Clean |

All logical-world types are free of frequency and tuning knowledge. The separation is rigorous.

### Bridge Verification

- **Forward (logical → physical):** `TuningSystem.frequency(for:referencePitch:)` is the sole bridge. All callers use it explicitly with `tuningSystem` and `referencePitch` parameters — no defaults, no hidden state.
- **Inverse (physical → logical):** `SoundFontNotePlayer.decompose(frequency:)` — internal to the audio layer, not part of the public domain API.

The bridge is clean and singular.

### Non-12-TET Generalizability

The architecture supports adding alternative tuning systems through this pipeline:

1. New `TuningSystem` case (e.g., `.justIntonation`) implements `centOffset(for:)` returning the interval's cent value in that system
2. Training logic creates `DetunedMIDINote` with the appropriate offset
3. `frequency(for:referencePitch:)` converts to Hz — the formula works universally via the cents mechanism

**This holds for "fixed-ratio" tuning variants** where each named interval has a single cent value regardless of root note. Examples:

- **Just intonation intervals** (as commonly used in ear training): P5 = 701.955¢, M3 = 386.314¢, etc.
- **Pythagorean tuning intervals**: P5 = 701.955¢, M3 = 407.820¢, etc.
- **Other equal temperaments** (19-TET, 31-TET): each interval has a fixed cent value by definition.

**This does NOT hold for position-dependent tuning systems** where interval size varies by scale degree:

- **Well temperaments** (Werckmeister, Kirnberger): the P5 from C is different from the P5 from F#
- **Full just-intonation scales**: the M2 from C (9:8 = 203.9¢) differs from the M2 from D (10:9 = 182.4¢)

For position-dependent systems, `centOffset` would need additional context (root note or scale degree). However, **no ear training app in common use implements position-dependent tuning** — they all use fixed-ratio intervals. This limitation is therefore acceptable for the app's foreseeable scope.

---

## Findings Detail

### F-1: Tritone Abbreviation "d5" (Suspect — Low Severity)

**Type:** `Interval.swift`, line 33
**Framework:** Standard music theory interval nomenclature

The tritone (6 semitones) is inherently ambiguous:
- **Diminished fifth (d5):** C → G♭ — a fifth narrowed by a chromatic semitone
- **Augmented fourth (A4):** C → F♯ — a fourth widened by a chromatic semitone

These are enharmonically equivalent in 12-TET but represent different interval qualities. The abbreviation "d5" privileges the diminished-fifth interpretation. In the context of an ear training app without harmonic context or key signatures, neither interpretation is more "correct."

**Recommendation:** Consider changing the abbreviation to "TT" (tritone), which matches the already-neutral localized name "Tritone" and avoids privileging either enharmonic interpretation. Alternatively, document the choice and keep "d5" — it's a minor cosmetic concern.

### F-2: `centOffset(for:)` API Shape Limits Generalizability (Suspect — Medium Severity)

**Type:** `TuningSystem.swift`, line 11
**Framework:** Tuning theory — equal vs. unequal temperaments

The signature `centOffset(for interval: Interval) -> Double` assumes that an interval's cent value is a pure function of the interval alone. This assumption:

- **Holds for:** All equal temperaments (12-TET, 19-TET, 31-TET, etc.) and fixed-ratio interval sets used in ear training
- **Fails for:** Position-dependent systems (well temperaments, full just-intonation scales)

The method is **currently unused in production code** — it exists only as a design hook and is tested only in `TuningSystemTests`. The actual frequency pipeline is: create `DetunedMIDINote` with the appropriate cent offset → pass to `frequency(for:referencePitch:)`.

**Recommendation:** No immediate change needed. If/when a position-dependent tuning system is added (unlikely for this app), the API would need extension. For now, document this limitation in the method's doc comment:

```swift
/// Returns the cent offset for the given interval in this tuning system.
///
/// This assumes the interval's cent value is independent of scale position,
/// which holds for equal temperaments and fixed-ratio interval sets.
/// Position-dependent tuning systems (well temperaments, full JI scales)
/// would require additional context (root note or scale degree).
func centOffset(for interval: Interval) -> Double
```

### F-3: `frequency()` Formula Is More General Than It Appears (Correct — Informational)

**Type:** `TuningSystem.swift`, lines 25–29
**Framework:** Acoustics — frequency computation from cents

The named constants `semitonesPerOctave = 12.0` and `centsPerSemitone = 100.0` suggest 12-TET specificity, but the formula simplifies to:

```
f = ref × 2^(totalCents / 1200)
```

where `totalCents = (midiOffset × 100) + centDeviation`. This is a universal formula — it converts any cent distance from A4 to a frequency. The "12" and "100" are artifacts of MIDI's 12-notes-per-octave grid, not tuning assumptions.

**Recommendation:** Consider adding a clarifying comment explaining this universality, so future developers don't mistakenly think they need to change the formula for non-12-TET systems:

```swift
// The formula ref × 2^(totalCents / 1200) is universal — it converts any
// cent distance to a frequency ratio. The intermediate use of semitones and
// centsPerSemitone reflects MIDI's 12-per-octave grid, not a tuning assumption.
```

### F-4: `MIDINote.name` Sharps-Only Is a 12-TET Display Simplification (Correct — Informational)

**Type:** `MIDINote.swift`, line 21
**Framework:** Enharmonic equivalence in 12-TET; note naming conventions

The `name` property always uses sharps (C#, D#, F#, G#, A#) rather than contextually choosing between sharps and flats. In 12-TET, C# and D♭ are the same pitch, so this is not incorrect. In non-12-TET tuning systems, they would be different pitches, making the naming actually wrong — but since `MIDINote.name` is a display convenience (showing "which key on the piano"), not a music-theory-correct note name, this is acceptable.

**Recommendation:** No code change needed. The doc comment already states "A discrete position on the 128-note MIDI grid" — this frames `name` correctly as a grid label, not a theory-correct note name.

### F-5: `Interval.between()` Single-Octave Constraint (Correct — Informational)

**Type:** `Interval.swift`, line 63
**Framework:** Interval classification — simple vs. compound intervals

The method throws for distances exceeding 12 semitones. The app's training scope is single-octave intervals, making this appropriate. Callers (`TrainingDataStore`) use `try?` with fallback to 0, handling the constraint gracefully.

**Recommendation:** No change needed. If compound intervals are ever needed, a separate type or extension would be more appropriate than expanding the enum.

### F-6: `centOffset(for:)` Unused in Production (Informational)

**Type:** `TuningSystem.swift`, line 11
**Framework:** Software architecture

The method is not called anywhere in production code — only in tests. The actual tuning pipeline is:
1. Training strategy creates a `DetunedMIDINote` with the desired cent offset
2. `frequency(for:referencePitch:)` converts it to Hz

This means `centOffset(for:)` is a design hook for future use, not part of the active pipeline. When a new tuning system is added, the training strategy would call `centOffset(for:)` to determine the cent offset for a given interval, then create the appropriate `DetunedMIDINote`.

**Recommendation:** No change needed. The method's existence supports the intended extension pattern for future tuning systems.

---

## Hidden Assumption Inventory

| # | Assumption | Location | Severity | Impact |
|---|---|---|---|---|
| H-1 | Interval identity = semitone count | `Interval` enum rawValue | Low | Correct in 12-TET and all equal temperaments. In just intonation, different intervals can have the same semitone approximation. Acceptable for ear training. |
| H-2 | Interval cent value is position-independent | `centOffset(for:)` API | Medium | Blocks position-dependent tuning systems. Acceptable given that no ear training app implements these. |
| H-3 | Note names use sharps only | `MIDINote.name` | Low | Display simplification. Not used for music theory correctness. |
| H-4 | 12 notes per octave (MIDI grid) | `MIDINote`, `frequency()` formula | None | This is the MIDI spec, not a hidden assumption. Non-12-TET systems work via cent offsets from the MIDI grid. |
| H-5 | Octave = 2:1 frequency ratio | `Cents` definition, `frequency()` | None | Near-universal acoustic reality. Stretched octaves (piano tuning) are a measurement concern, not a type design issue. |

---

## Recommendations Catalogue

These are catalogued for future implementation stories. **No code changes should be made in story 28.1.**

| # | Finding | Recommendation | Priority | Effort |
|---|---|---|---|---|
| R-1 | Tritone abbreviation "d5" | Change to "TT" to match neutral localized name | Low | Trivial |
| R-2 | `centOffset(for:)` API limitation | Add doc comment explaining position-independence assumption | Low | Trivial |
| R-3 | `frequency()` formula clarity | Add comment explaining the formula's universality despite 12-TET-looking constants | Low | Trivial |
| R-4 | `MIDINote.name` documentation | Already adequately documented; no change needed | None | — |
| R-5 | `Interval` enum scope | Already appropriate; compound intervals not needed for app scope | None | — |

---

## Conclusion

The Peach domain type layer is musically sound for its purpose. The two-world architecture is clean and correctly implemented. The types carry minimal hidden assumptions, and those that exist are appropriate for the app's scope (ear training with interval recognition).

The most significant finding (F-2) — that `centOffset(for:)` assumes position-independent interval sizes — is not a defect but a scope limitation that aligns with how ear training software universally works. The recommendation is documentation, not redesign.

The frequency formula (F-3) is correct and more general than its named constants suggest. No changes are needed for adding fixed-ratio tuning system variants (the expected use case for Epic 29/30).

**Overall verdict: The foundations are solid. Build on them with confidence.**

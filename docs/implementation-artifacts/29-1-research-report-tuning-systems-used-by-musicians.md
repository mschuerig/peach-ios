# Research Report: Tuning Systems Used by Musicians in Practice

**Author:** Adam (Music Domain Expert)
**Date:** 2026-03-02
**Story:** 29.1 — Research Tuning Systems Used by Musicians in Practice
**Scope:** Survey of non-12-TET tuning systems, practical usage assessment, ear training relevance, architecture compatibility with Peach, and recommendation for Epic 30 implementation

---

## 1. Executive Summary

**Recommendation: 5-limit Just Intonation** is the single most relevant tuning system for Peach to implement first.

Just intonation is the tuning system that working musicians actually encounter and use. String quartets, choirs, wind ensembles, and barbershop singers routinely adjust their intonation toward just intervals in performance. Music schools teach just intonation as the foundation of "playing in tune." The difference between 12-TET and just intervals (particularly the major third at -13.7 cents and the minor third at +15.6 cents) is the single most practical intonation distinction a musician can train their ear to perceive.

5-limit just intonation fits the Peach architecture perfectly: each interval has exactly one fixed ratio, mapping directly to `centOffset(for: Interval) -> Double` with no API changes. All deviations from 12-TET fall within ±18 cents — well inside the ±200 cent pipeline limit. FR55 is fully satisfied: only a new `TuningSystem` case and its `centOffset(for:)` switch branch are needed.

No other candidate comes close on the combination of practical relevance, pedagogical value, and architectural fit.

---

## 2. Tuning System Survey

### 2.1 Equal Temperament Variants (19-TET, 31-TET, 53-TET)

**Usage classification: Experimental/niche**

| System | Step Size | Who Uses It | Practical Frequency |
|---|---|---|---|
| 19-TET | 63.158¢ | Microtonal composers (Mandelbaum, Blackwood), experimental guitarists with refretted instruments | Rare — a few dozen active practitioners worldwide |
| 31-TET | 38.710¢ | Dutch microtonal tradition (Huygens, Fokker), some organ builders | Rare — historically used in the Netherlands, minimal current practice |
| 53-TET | 22.642¢ | Turkish music theory (theoretical framework), some academic composers | Very rare — primarily a theoretical construct; 53-TET's excellent approximation of just intervals made it historically interesting but impractical for most instruments |

**Assessment:** These systems require purpose-built or modified instruments (refretted guitars, custom keyboards). No standard orchestral or ensemble instrument uses them. They are not taught in any mainstream music curriculum. For ear training, they offer no practical benefit to working musicians — the intervals do not correspond to anything a performer encounters in professional practice.

**Notable property:** All equal temperaments are position-independent by definition (every step is the same size), so they would fit the `centOffset(for:)` API. However, the Peach `Interval` enum has 13 cases mapping to the 12-TET chromatic scale, and these don't map meaningfully to 19 or 31 divisions of the octave.

### 2.2 Just Intonation (5-limit)

**Usage classification: Core practical relevance — used daily by millions of musicians**

Just intonation intervals are defined by simple frequency ratios involving the prime factors 2, 3, and 5. These ratios produce the "pure" intervals that the ear naturally gravitates toward.

| Context | How JI Is Used | Typical Practitioners |
|---|---|---|
| String quartets | Adjust thirds and sixths toward pure ratios for vertical sonority; use Pythagorean fifths for open strings | Professional and student chamber musicians |
| Choirs | Tune chords to pure intervals, especially major thirds (14¢ flatter than 12-TET) and minor thirds (16¢ sharper) | All trained choral singers |
| Wind ensembles | Adjust intonation for blend; brass sections tune to natural harmonics (inherently just) | Orchestral and band musicians |
| Barbershop quartets | Strict just intonation tuning to produce "expanded sound" through reinforced overtones | Dedicated barbershop community |
| Solo string players | Pythagorean tuning for melodic passages, just intonation for double stops and chords | Violinists, violists, cellists |
| Piano tuners | Reference point — pianos are tuned to 12-TET, but tuners compare against just intervals to assess beating rates | Piano technicians |

**What problem it solves:** 12-TET is a compromise — every interval except the octave is slightly out of tune relative to the natural harmonic series. The major third is 14 cents sharp, the minor third is 16 cents flat. Just intonation eliminates these errors for the intervals being sounded, producing cleaner, more resonant harmonies.

**Actively taught:** Yes. Just intonation is part of standard music theory and ear training curricula at conservatories and university music programs. String pedagogy explicitly teaches the distinction between Pythagorean melodic intonation and just harmonic intonation. Choir directors routinely reference just thirds and sixths.

### 2.3 Pythagorean Tuning

**Usage classification: Pedagogically significant, partial practical use**

Pythagorean tuning derives all intervals from stacked perfect fifths (ratio 3:2). It produces pure fifths and fourths but harsh thirds and sixths.

| Aspect | Detail |
|---|---|
| Who uses it | String players for melodic passages and open-string tuning; medieval/early music performers |
| Key intervals | P5 = 701.955¢ (same as JI), M3 = 407.820¢ (21.5¢ sharper than 12-TET — harsh) |
| Practical significance | String instruments are tuned in fifths (violin: G-D-A-E), creating a Pythagorean framework. Melodic leading tones are played high (Pythagorean tendency). |
| Pedagogical value | Teaches the difference between melodic and harmonic intonation |

**Assessment:** Pythagorean tuning is position-independent (each interval has one fixed ratio) and would fit the API. However, its thirds and sixths are actually *worse* than 12-TET for harmonic purposes (M3 at 408¢ vs. 12-TET's 400¢ vs. JI's 386¢). For ear training, just intonation is strictly more useful because it represents what musicians aim for when tuning chords.

**Overlap with JI:** The Pythagorean P5 (701.955¢) and P4 (498.045¢) are identical to the 5-limit JI values. The systems diverge at thirds, sixths, and sevenths.

### 2.4 Well Temperaments (Werckmeister, Kirnberger, Vallotti)

**Usage classification: Historical keyboard practice, niche revival**

Well temperaments are "circular" tunings where all 24 keys are usable but each has a distinctive character. The size of a given interval (e.g., the perfect fifth) varies depending on the root note.

| System | Era | Modern Use |
|---|---|---|
| Werckmeister III (1691) | Late Baroque | Harpsichord and organ tuning for Bach-era repertoire; some ensemble use |
| Kirnberger III (1779) | Late 18th century | Favored by some violinists (pure open-string fifth); organ tuning |
| Vallotti (1754) | Classical | Popular among piano tuners as a 12-TET alternative; organ tuning |
| Young II (1799) | Early Romantic | Occasional piano tuner preference |

**Critical architectural issue:** Well temperaments are **position-dependent**. The P5 from C is different from the P5 from F#. This fundamentally conflicts with `centOffset(for: Interval) -> Double`, which assumes each interval has a single cent value regardless of root note.

**Assessment:** Not suitable for Peach without API changes. The historical keyboard niche is too narrow to justify the architectural complexity. No ear training app in common use implements well temperaments.

### 2.5 Meantone Temperaments (Quarter-comma, Third-comma)

**Usage classification: Historical, active revival in early music performance**

Quarter-comma meantone was the dominant keyboard tuning in Europe from approximately 1500 to 1700. It achieves pure major thirds (5:4) at the cost of a "wolf" fifth and several unusable keys.

| Property | Value |
|---|---|
| Fifth size | 696.578¢ (5.4¢ flat of pure) |
| Major third | 386.314¢ (pure 5:4 — same as JI) |
| Usable keys | 8 of 12 major triads; keys beyond 3-4 sharps/flats are unusable |
| Modern use | Early music ensembles, harpsichord/organ recitals of Renaissance and early Baroque repertoire |

**Critical architectural issue:** Like well temperaments, meantone is **position-dependent** when viewed as a 12-key system. The 8 "good" thirds are pure, but the 4 "bad" ones are extremely wide (427¢). The wolf fifth (737¢) is unplayable. A position-independent model can only capture the "good" intervals, effectively duplicating the JI M3 and P4/P5 values.

**Assessment:** Not suitable for Peach. The usable intervals overlap with JI, and the unusable ones can't be represented cleanly. The early music revival audience is small and specialized.

### 2.6 Non-Western Tuning Systems

**Usage classification: Culturally important, architecturally incompatible**

| System | Region | Structure | Compatibility |
|---|---|---|---|
| Arabic maqam | Middle East, North Africa | Modal system with quarter-tone inflections; scales vary by maqam | Fundamentally different framework — maqam specifies melodic behavior, not just pitches |
| Indian raga/shruti | South Asia | 22 shrutis per octave; microtonal inflections define raga identity | Position-dependent and context-dependent; shruti placement varies by raga |
| Javanese/Balinese gamelan | Southeast Asia | Slendro (5-note) and pelog (7-note); no standard tuning — each gamelan is unique | Entirely outside Western interval categories; no mapping to P1–P8 |
| Chinese/Japanese traditional | East Asia | Various pentatonic and heptatonic systems, often Pythagorean-derived | The Pythagorean-derived variants could theoretically work, but the cultural context doesn't align with Peach's Western interval training |

**Assessment:** Non-Western systems are musically rich but architecturally incompatible with Peach. They don't map to the 13-interval Western chromatic framework (P1–P8) that Peach is built on. Implementing any of them would require fundamental redesign of the interval model, not just a new `centOffset(for:)` switch branch. This is far outside the scope of Epic 30.

---

## 3. Ear Training Relevance Assessment

### 3.1 Which tuning systems are actively used in ear training curricula?

**Just intonation is the only non-12-TET system regularly used in music education ear training.**

| Curriculum Context | JI Usage | Other Non-12-TET |
|---|---|---|
| University music theory | Teaching the difference between tempered and pure intervals; demonstrating why string quartets "sound different" from pianos | None — other systems are mentioned in music history courses, not trained as skills |
| Conservatory performance | String and wind students learn to tune intervals to just ratios in ensemble settings | Pythagorean mentioned for melodic intonation (leading tones), but not drilled as a separate system |
| Choral training | Directors teach singers to tune major thirds low and minor thirds high relative to the piano | None |
| Barbershop education | Extensive JI ear training — quartets lock chords to pure intervals | None |

**Existing ear training tools that offer JI:**
- INTUNATOR: drone-based JI training for instrumentalists
- tuneUp: includes just intonation mode
- Sonofield: adding JI support (announced 2025)
- Various pedagogical resources reference JI intervals without implementing them in software

### 3.2 What pedagogical value does non-12-TET ear training offer?

The core pedagogical value is **intonation awareness** — understanding that the piano's tuning is a compromise, and that pure intervals exist at specific, learnable distances from the tempered grid.

| Skill Developed | How JI Training Helps |
|---|---|
| Chord tuning | Hearing the 14¢ difference on major thirds transforms a musician's ability to tune chords in ensemble |
| Ensemble blend | Understanding that "in tune" in an ensemble means "in tune with each other" (just ratios), not "in tune with the piano" (12-TET) |
| Intonation flexibility | Musicians who know where both the tempered and just versions of an interval are can choose contextually |
| Overtone perception | Pure intervals reinforce overtones; training the ear to perceive this reinforcement improves general pitch sensitivity |

**What JI training does NOT do:**
- It does not help with sight-reading or interval identification (those skills are system-agnostic)
- It does not replace 12-TET training (which remains essential for piano and fretted instruments)
- It does not teach harmonic analysis or music theory

### 3.3 Which systems help musicians understand intonation differences encountered in practice?

**Ranked by practical relevance to working musicians:**

| Rank | System | Why It Matters in Practice |
|---|---|---|
| 1 | **5-limit Just Intonation** | String quartets, choirs, wind ensembles — this IS the tuning system musicians adjust toward when "playing in tune" together |
| 2 | Pythagorean (for melodic tendency) | String players sharpen leading tones and widen whole steps in melodies — but these tendencies are subtle refinements of JI, not a separate system to train |
| 3 | All others | Not encountered in standard Western musical practice |

---

## 4. Architecture Compatibility Matrix

### 4.1 Position-independence classification

| System | Position-Independent? | Fits `centOffset(for:)`? | Notes |
|---|---|---|---|
| **5-limit Just Intonation** | **Yes** | **Yes** | Each interval has exactly one ratio. The "two whole tones" issue (9/8 vs. 10/9) is resolved by choosing one per interval slot. |
| Pythagorean | Yes | Yes | All intervals derived from fifths — one value per interval. |
| 12-TET (current) | Yes | Yes (already implemented) | By definition position-independent. |
| 19-TET, 31-TET, 53-TET | Yes | Problematic | Position-independent, but intervals don't map to 13-case `Interval` enum. |
| Well temperaments | **No** | **No** | Interval size varies by root note. Would need `centOffset(for:rootNote:)`. |
| Quarter-comma meantone | **No** (as a 12-key system) | **No** | Wolf fifth and unusable keys break the model. |
| Non-Western systems | **No** | **No** | Different interval frameworks entirely. |

### 4.2 Cent offset range verification

All 5-limit JI deviations from 12-TET are within ±18 cents:

| Interval | JI Cents | 12-TET Cents | Deviation | Within ±200¢? |
|---|---|---|---|---|
| P1 | 0.000 | 0 | 0.000 | Yes |
| m2 | 111.731 | 100 | +11.731 | Yes |
| M2 | 203.910 | 200 | +3.910 | Yes |
| m3 | 315.641 | 300 | +15.641 | Yes |
| M3 | 386.314 | 400 | -13.686 | Yes |
| P4 | 498.045 | 500 | -1.955 | Yes |
| TT | 590.224 | 600 | -9.776 | Yes |
| P5 | 701.955 | 700 | +1.955 | Yes |
| m6 | 813.686 | 800 | +13.686 | Yes |
| M6 | 884.359 | 900 | -15.641 | Yes |
| m7 | 1017.596 | 1000 | +17.596 | Yes |
| M7 | 1088.269 | 1100 | -11.731 | Yes |
| P8 | 1200.000 | 1200 | 0.000 | Yes |

**Maximum deviation: 17.596 cents** (minor seventh). This is 11× smaller than the ±200 cent pipeline limit.

### 4.3 Pipeline compatibility confirmation

Cross-referencing with story 28.2 conclusions:

- `TuningSystem.frequency(for:referencePitch:)` — universal formula, no changes needed (confirmed with JI P5 and JI M3 in 28.2)
- `SoundFontNotePlayer.decompose()` — correctly rounds to nearest MIDI note for all JI deviations (all within ±50¢ rounding zone)
- `pitchBendValue()` — 14-bit MIDI pitch bend handles all JI offsets with 0.024¢ precision
- `adjustFrequency()` — ±200¢ guard accommodates all JI intervals with 10× margin
- End-to-end precision: ≤0.025¢ worst case — 4× below NFR14 target

**No pipeline changes required.**

### 4.4 FR55 verification

> FR55: System supports multiple tuning systems beyond 12-TET; adding a new tuning system requires no changes to interval or training logic.

For 5-limit just intonation:
- Add `case justIntonation` to `TuningSystem` enum — **required**
- Add `centOffset(for:)` switch branch with 13 cent values — **required**
- Add `storageIdentifier` — **required**
- Add `fromStorageIdentifier()` mapping — **required**
- Changes to `Interval`, `DirectedInterval`, `Direction` — **none needed**
- Changes to `frequency(for:referencePitch:)` — **none needed**
- Changes to `NotePlayer` pipeline — **none needed**
- Changes to `ComparisonSession`, `PitchMatchingSession` — **none needed**
- Changes to training logic, strategy, or data store — **none needed**

**FR55 is fully satisfied.**

---

## 5. Recommendation: 5-limit Just Intonation

### 5.1 Scoring Matrix

| Criterion | JI (5-limit) | Pythagorean | 19-TET | Well Temp. | Meantone |
|---|---|---|---|---|---|
| **Practical relevance** | **5** — used by millions of musicians daily | 3 — partial use (fifths only) | 1 — experimental niche | 2 — historical niche | 2 — early music niche |
| **Pedagogical value** | **5** — directly teaches ensemble tuning skills | 3 — useful for melodic tendency | 1 — no practical application | 1 — historical interest only | 1 — historical interest |
| **Architectural fit** | **5** — position-independent, fits API perfectly | 5 — same API compatibility | 2 — interval mapping problematic | 1 — position-dependent, breaks API | 1 — position-dependent |
| **Implementation simplicity** | **5** — 13 constant values, no logic changes | 5 — same simplicity | 2 — interval mapping redesign | 4 — needs new API parameter | 3 — wolf interval handling |
| **Total** | **20/20** | **16/20** | **6/20** | **8/20** | **7/20** |

### 5.2 Rationale

5-limit just intonation is the clear winner on every dimension:

1. **It's what musicians actually do.** When a string quartet adjusts their major third to sound "pure," they're tuning to 5:4 (386¢), not to 12-TET's 400¢. Training a musician's ear to hear this 14-cent difference is directly useful.

2. **It's what music schools teach.** Intonation pedagogy references just ratios as the target for ensemble tuning. A musician who can perceive the difference between tempered and just intervals is a better ensemble player.

3. **It fits the architecture perfectly.** Each interval maps to exactly one ratio. The `centOffset(for:)` API works as designed. No pipeline changes, no new parameters, no architectural modifications.

4. **It's simple to implement.** Thirteen constant cent values in a switch statement. The entire implementation is a new enum case with one method branch.

5. **It provides meaningful training.** The deviations from 12-TET (up to ±17.6¢) are large enough to be perceptible to a trained ear but small enough to be challenging. This is the sweet spot for ear training.

### 5.3 Complete Cent Offset Table

These values are ready for direct use in `TuningSystem.centOffset(for:)`:

| Interval | Peach Enum Case | Ratio | Cent Offset | Deviation from 12-TET |
|---|---|---|---|---|
| P1 | `.prime` | 1/1 | 0.000 | 0.000 |
| m2 | `.minorSecond` | 16/15 | 111.731 | +11.731 |
| M2 | `.majorSecond` | 9/8 | 203.910 | +3.910 |
| m3 | `.minorThird` | 6/5 | 315.641 | +15.641 |
| M3 | `.majorThird` | 5/4 | 386.314 | -13.686 |
| P4 | `.perfectFourth` | 4/3 | 498.045 | -1.955 |
| TT | `.tritone` | 45/32 | 590.224 | -9.776 |
| P5 | `.perfectFifth` | 3/2 | 701.955 | +1.955 |
| m6 | `.minorSixth` | 8/5 | 813.686 | +13.686 |
| M6 | `.majorSixth` | 5/3 | 884.359 | -15.641 |
| m7 | `.minorSeventh` | 9/5 | 1017.596 | +17.596 |
| M7 | `.majorSeventh` | 15/8 | 1088.269 | -11.731 |
| P8 | `.octave` | 2/1 | 1200.000 | 0.000 |

**Swift implementation preview:**
```swift
case .justIntonation:
    switch interval {
    case .prime:        return 0.0
    case .minorSecond:  return 111.731  // 16/15
    case .majorSecond:  return 203.910  // 9/8
    case .minorThird:   return 315.641  // 6/5
    case .majorThird:   return 386.314  // 5/4
    case .perfectFourth: return 498.045 // 4/3
    case .tritone:      return 590.224  // 45/32
    case .perfectFifth: return 701.955  // 3/2
    case .minorSixth:   return 813.686  // 8/5
    case .majorSixth:   return 884.359  // 5/3
    case .minorSeventh: return 1017.596 // 9/5
    case .majorSeventh: return 1088.269 // 15/8
    case .octave:       return 1200.0   // 2/1
    }
```

### 5.4 Edge Cases and Limitations

#### Edge Case 1: Broken octave complement symmetry (M2/m7 pair)

In a mathematically perfect system, an interval and its octave complement should sum to exactly 1200 cents. Most JI pairs satisfy this:

| Pair | Sum | Exact? |
|---|---|---|
| m2 (111.731) + M7 (1088.269) | 1200.000 | Yes |
| M2 (203.910) + m7 (1017.596) | **1221.506** | **No — off by 21.506¢ (syntonic comma)** |
| m3 (315.641) + M6 (884.359) | 1200.000 | Yes |
| M3 (386.314) + m6 (813.686) | 1200.000 | Yes |
| P4 (498.045) + P5 (701.955) | 1200.000 | Yes |

**Explanation:** In full just intonation, there are TWO sizes of whole tone: 9/8 (203.910¢, the "major whole tone") and 10/9 (182.404¢, the "minor whole tone"). The M2 slot uses 9/8; its true complement is 16/9 (996.090¢), not 9/5 (1017.596¢). The m7 slot uses 9/5 because it's the standard 5-limit minor seventh.

**Impact on Peach:** Minimal. The app trains intervals in isolation — it never presents M2 and m7 as complementary pairs. If a future feature compares a note's "interval going up" with the "interval going down to the same pitch," the 21.5¢ asymmetry would be audible. This can be documented and addressed if the need arises.

**Alternative:** Using 16/9 (996.090¢, deviation -3.910¢) for m7 would restore octave symmetry but reduce the perceived difference from 12-TET to only 3.9 cents — too subtle for effective ear training. The 9/5 choice (17.6¢ deviation) is pedagogically superior.

#### Edge Case 2: Tritone ambiguity

The tritone's octave complement is 64/45 (609.776¢), not 45/32 (590.224¢) reflected. The Peach `Interval` enum has a single `.tritone` case, so only one value can be stored.

**Choice rationale:** 45/32 is the standard 5-limit augmented fourth — the interval from C to F# in the just major scale. Its complement (the diminished fifth, C to G♭) would be 64/45. Since Peach doesn't distinguish between augmented fourths and diminished fifths, 45/32 is the conventional choice.

**Impact on Peach:** None for current functionality. The tritone is inherently dissonant in all tuning systems, and the 9.8¢ deviation from 12-TET is perceptible but not dramatic.

#### Edge Case 3: The "which m7?" question

Three common minor seventh ratios exist in music theory:

| Ratio | Cents | Deviation from 12-TET | Context |
|---|---|---|---|
| 9/5 (recommended) | 1017.596 | +17.596 | Standard 5-limit just m7; commonly cited in theory |
| 16/9 | 996.090 | -3.910 | Pythagorean m7; octave complement of 9/8 |
| 7/4 | 968.826 | -31.174 | Harmonic (septimal) seventh; barbershop tuning; 7-limit |

The recommended 9/5 is the best choice for a 5-limit system. The 7/4 "harmonic seventh" (used by barbershop quartets) is acoustically dramatic (-31¢ from 12-TET) but requires exiting the 5-limit framework. It could be considered for a future "7-limit" or "harmonic series" tuning variant.

#### Edge Case 4: Position-independence is a simplification

Real-world just intonation is inherently position-dependent. A string quartet tuning a C major chord uses 5:4 for the C-E major third, but the D-F# third in a D major chord is also 5:4 — which means the E and the F# are NOT related by a simple 9:8 whole step. The actual D-to-E step is 10/9 (182.404¢), not 9/8 (203.910¢).

Peach's model assigns one cent value per interval regardless of context. This is acceptable because:
1. Peach trains individual interval recognition, not harmonic progressions
2. No ear training app implements position-dependent just intonation
3. The 21.5¢ difference between the two whole tones is relevant only when comparing intervals across different roots, which Peach doesn't do

---

## 6. Epic 30 Implementation Specification

### Chosen system name
`TuningSystem.justIntonation`

### Storage identifier
`"justIntonation"` (for `storageIdentifier` and `fromStorageIdentifier()`)

### Localized display names

| Language | Display Name |
|---|---|
| English | Just Intonation |
| German | Reine Stimmung |

### User-facing description

**English:**
> Pure intervals based on natural frequency ratios (3:2, 5:4, etc.). This is the tuning that skilled string players, singers, and wind musicians aim for when playing in tune together. Train your ear to hear the difference from equal temperament.

**German:**
> Reine Intervalle basierend auf natürlichen Frequenzverhältnissen (3:2, 5:4 usw.). Diese Stimmung verwenden erfahrene Streicher, Sänger und Bläser beim Zusammenspiel. Trainiere dein Gehör, den Unterschied zur gleichstufigen Stimmung zu hören.

### Complete cent offset table

See Section 5.3 above for the full table with ratios and `centOffset(for:)` values.

### Implementation checklist for Epic 30

1. Add `case justIntonation` to `TuningSystem` enum
2. Add `centOffset(for:)` switch branch with 13 values from Section 5.3
3. Add `storageIdentifier` case: `"justIntonation"`
4. Add `fromStorageIdentifier()` mapping: `"justIntonation" -> .justIntonation`
5. Add localization strings for English and German
6. Add tests: cent offset values for all 13 intervals, frequency precision verification (mirror existing 12-TET test pattern)
7. No changes needed to: `Interval`, `DirectedInterval`, `Direction`, `frequency(for:referencePitch:)`, `NotePlayer`, `ComparisonSession`, `PitchMatchingSession`, or any training logic

---

## Appendix A: Ratio Derivations

All 5-limit just intonation ratios derive from combinations of the three prime harmonics:

| Harmonic | Ratio | Interval |
|---|---|---|
| 2nd harmonic | 2:1 | Octave |
| 3rd harmonic | 3:2 | Perfect fifth |
| 5th harmonic | 5:4 | Major third |

From these three building blocks:

| Interval | Derivation | Ratio |
|---|---|---|
| P1 | Identity | 1/1 |
| m2 | P8 ÷ M7 = 2/(15/8) | 16/15 |
| M2 | P5 × P5 ÷ P8 = (3/2)² / 2 | 9/8 |
| m3 | P5 ÷ M3 = (3/2)/(5/4) | 6/5 |
| M3 | 5th harmonic | 5/4 |
| P4 | P8 ÷ P5 = 2/(3/2) | 4/3 |
| TT | M2 × M3 = (9/8)(5/4) | 45/32 |
| P5 | 3rd harmonic | 3/2 |
| m6 | P8 ÷ M3 = 2/(5/4) | 8/5 |
| M6 | P5 × M3 ÷ P8 ... simpler: P8 ÷ m3 = 2/(6/5) | 5/3 |
| m7 | P5 × m3 = (3/2)(6/5) | 9/5 |
| M7 | P5 × M3 = (3/2)(5/4) | 15/8 |
| P8 | 2nd harmonic | 2/1 |

## Appendix B: Sources and References

### Project references
- [28.1 Audit Report: Interval and TuningSystem Domain Types](28-1-audit-report-interval-and-tuningsystem-domain-types.md)
- [28.2 Audit Report: NotePlayer and Frequency Computation Chain](28-2-audit-report-noteplayer-and-frequency-computation-chain.md)
- [Story 28.1](28-1-audit-interval-and-tuningsystem-domain-types.md)
- [Story 28.2](28-2-audit-noteplayer-and-frequency-computation-chain.md)
- `Peach/Core/Audio/TuningSystem.swift` — Current implementation
- `PeachTests/Core/Audio/TuningSystemTests.swift` — Existing test patterns

### External references
- [Kyle Gann — Just Intonation Explained](https://www.kylegann.com/tuning.html)
- [Kyle Gann — An Introduction to Historical Tunings](https://www.kylegann.com/histune.html)
- [Wikipedia — Just Intonation](https://en.wikipedia.org/wiki/Just_intonation)
- [Wikipedia — List of intervals in 5-limit just intonation](https://en.wikipedia.org/wiki/List_of_intervals_in_5-limit_just_intonation)
- [Wikipedia — Five-limit tuning](https://en.wikipedia.org/wiki/Five-limit_tuning)
- [Wikipedia — Well temperament](https://en.wikipedia.org/wiki/Well_temperament)
- [Wikipedia — Meantone temperament](https://en.wikipedia.org/wiki/Meantone_temperament)
- [Wikipedia — 19 equal temperament](https://en.wikipedia.org/wiki/19_equal_temperament)
- [University of Iowa — A practical introduction to just intonation through string quartet playing](https://iro.uiowa.edu/esploro/outputs/doctoral/A-practical-introduction-to-just-intonation/9983777110202771)
- [INTUNATOR App — Just temperament training](https://www.intunator.com/en)
- [Violinna.Live — Pythagorean Tuning vs Just Intonation](https://www.violinna.live/pythagorean-tuning-vs-just-intonation-a-paradox-of-playing-in-tune/)
- [Helen Bledsoe — Just Intonation: Thirds and Sixths](https://helenbledsoe.com/just-intonation-thirds-and-sixths-an-exercise/)
- [NAfME — Teaching Intonation to Beginning Musicians](https://nafme.org/blog/teaching-intonation-to-beginning-musicians-setting-up-for-success-from-day-one/)

# Story 28.1: Audit Interval and TuningSystem Domain Types

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer preparing to add alternative tuning systems**,
I want the music domain expert (Adam) to audit Interval, DirectedInterval, Direction, TuningSystem, MIDINote, DetunedMIDINote, Frequency, and Cents for hidden musical assumptions and correctness,
so that domain-level errors are caught before building on these foundations.

## Acceptance Criteria

1. Adam reviews every domain type in `Core/Audio/` listed below and produces a written audit report
2. Each finding states which musical/theoretical framework applies and why the current implementation is correct, suspect, or wrong
3. Hidden 12-TET assumptions in types that claim to be tuning-system-agnostic are explicitly flagged
4. The `TuningSystem.centOffset(for:)` and `TuningSystem.frequency(for:referencePitch:)` methods are verified against the equal temperament formula and assessed for generalizability to non-equal tuning systems
5. `Interval` enum design (0–12 semitones only, no compound intervals) is assessed for musical completeness given the app's training scope
6. `Interval.between(_:_:)` using `abs()` (discarding direction) is assessed for correctness
7. Naming accuracy is reviewed: interval case names, abbreviations (e.g., tritone as "d5"), `MIDINote.name` (sharps only, no enharmonic awareness)
8. The two-world architecture (logical: MIDINote/DetunedMIDINote/Interval/Cents vs. physical: Frequency, bridged by TuningSystem) is assessed for soundness
9. Audit report is saved as a document in `docs/implementation-artifacts/`
10. If findings require code changes, they are catalogued as recommendations (not implemented in this story)

## Tasks / Subtasks

- [ ] Task 1: Load the Adam agent persona (`/bmad-agent-music-domain-expert`) (AC: #1)
- [ ] Task 2: Audit each domain type systematically (AC: #1, #2, #3)
  - [ ] 2.1 `Interval.swift` — enum design, case completeness, `between()` method, naming/abbreviations
  - [ ] 2.2 `DirectedInterval.swift` — direction semantics, `between()` vs `Interval.between()`, `Comparable` ordering
  - [ ] 2.3 `Direction.swift` — binary up/down model adequacy
  - [ ] 2.4 `TuningSystem.swift` — `centOffset(for:)` correctness, `frequency(for:referencePitch:)` formula, generalizability for non-equal tuning systems
  - [ ] 2.5 `MIDINote.swift` — range, `name` property (sharps-only), `random(in:)` semantics
  - [ ] 2.6 `DetunedMIDINote.swift` — offset semantics, relationship to logical/physical worlds
  - [ ] 2.7 `Frequency.swift` — Hz representation, `concert440` constant
  - [ ] 2.8 `Cents.swift` — universality claim (tuning-system-agnostic?), magnitude semantics
- [ ] Task 3: Assess the two-world architecture as a whole (AC: #8)
  - [ ] 3.1 Verify logical world types carry no frequency/tuning knowledge
  - [ ] 3.2 Verify TuningSystem is the sole bridge
  - [ ] 3.3 Assess whether the architecture holds for non-12-TET tuning systems
- [ ] Task 4: Verify `TuningSystem.frequency()` against the equal temperament formula (AC: #4)
  - [ ] 4.1 Formula: `referencePitch * 2^((midiNote - 69 + cents/100) / 12)` — check implementation matches
  - [ ] 4.2 Assess whether `centOffset(for:)` return type and semantics generalize to non-equal temperaments
- [ ] Task 5: Review naming accuracy (AC: #7)
  - [ ] 5.1 Interval case names against standard music theory nomenclature
  - [ ] 5.2 Abbreviations: tritone as "d5" vs "A4" vs "TT"
  - [ ] 5.3 `MIDINote.name` — sharps-only (no flats/enharmonics), octave numbering convention
- [ ] Task 6: Write audit report (AC: #9)
  - [ ] 6.1 For each type: state framework, assessment (correct/suspect/wrong), rationale
  - [ ] 6.2 Catalogue code change recommendations separately (AC: #10)
  - [ ] 6.3 Save report to `docs/implementation-artifacts/`

## Dev Notes

### This is a research/audit story — NOT a code implementation story

The dev agent for this story should:
1. Load the Adam agent persona via `/bmad-agent-music-domain-expert`
2. Use Adam's `#audit-assumptions` prompt to systematically review each file
3. Produce a written audit report as the primary deliverable
4. **Do NOT make code changes** — catalogue recommendations only

### Files to Audit

All in `Peach/Core/Audio/`:

| File | Type | Key Concern |
|---|---|---|
| `Interval.swift` | `enum Interval: Int` (13 cases, P1–P8) | Limited to single octave; `between()` uses `abs()` losing direction; tritone abbreviated "d5" |
| `DirectedInterval.swift` | `struct` wrapping `Interval` + `Direction` | `between()` delegates to `Interval.between()` then adds direction — is abs+re-derive correct? |
| `Direction.swift` | `enum` with `.up` / `.down` | Binary model — sufficient for current scope? |
| `TuningSystem.swift` | `enum` with `.equalTemperament` | `centOffset(for:)` returns `semitones * 100.0`; `frequency()` uses standard 12-TET formula; must generalize for just intonation etc. |
| `MIDINote.swift` | `struct` with `rawValue: Int` (0–127) | `name` property uses sharps only (C#, not Db); octave = rawValue/12 - 1 |
| `DetunedMIDINote.swift` | `struct` with `MIDINote` + `Cents` | Pure logical type — no frequency knowledge |
| `Frequency.swift` | `struct` with `rawValue: Double` | Physical world — `concert440` constant |
| `Cents.swift` | `struct` with `rawValue: Double` | Claims universality (not 12-TET-specific) — verify |

### Existing Test Files

Tests exist for all domain types in `PeachTests/Core/Audio/`:
- `IntervalTests.swift`, `DirectedIntervalTests.swift`, `TuningSystemTests.swift`
- `MIDINoteTests.swift`, `DetunedMIDINoteTests.swift`, `FrequencyTests.swift`, `CentsTests.swift`

### Architecture Context: Two-World Design

The codebase implements a deliberate two-world architecture [Source: docs/project-context.md]:
- **Logical world**: `MIDINote`, `DetunedMIDINote`, `Interval`, `DirectedInterval`, `Direction`, `Cents`
- **Physical world**: `Frequency` (Hz)
- **Bridge**: `TuningSystem.frequency(for:referencePitch:)` — forward conversion only; inverse (Hz → MIDI) is internal to `SoundFontNotePlayer.decompose()`

Key design decisions from architecture [Source: docs/planning-artifacts/architecture.md, v0.3 amendment]:
- `Interval` is an enum (bounded domain P1–P8) — raw Int = semitone count
- `TuningSystem` is an enum (not protocol) to support future Settings picker + `CaseIterable`
- Original architecture specified a `Pitch` type; implementation renamed it to `DetunedMIDINote` (story 22.3)
- `centOffset(for:)` was designed so adding a tuning system case (e.g., `.justIntonation`) only requires implementing its cent deviations — no changes to training logic

### Key Audit Questions for Adam

1. **Is `Interval` correctly modeled as semitone distance?** In 12-TET, intervals map cleanly to semitone counts. In just intonation or Pythagorean tuning, intervals are frequency ratios — does the semitone-based model still work?
2. **Does `centOffset(for:)` generalize?** For 12-TET, `centOffset(.perfectFifth) = 700.0`. For just intonation, a perfect fifth is 3:2 ratio = ~701.955 cents. The method returns `Double` which handles this. But is the API shape correct — should it take additional context (e.g., scale degree, root note)?
3. **Is `Interval.between()` using `abs()` musically sound?** It computes unsigned distance. `DirectedInterval.between()` re-derives direction from note comparison. Is there a case where this loses information?
4. **Tritone abbreviation "d5"**: Musically, the tritone is both a diminished fifth (d5) and an augmented fourth (A4). The choice of "d5" privileges one interpretation. Is this acceptable for an ear training app?
5. **`MIDINote.name` sharps only**: C# vs Db are enharmonic equivalents in 12-TET but not in other tuning systems. Is sharps-only naming a hidden 12-TET assumption?
6. **`Cents` universality**: The cent is defined as 1/1200 of an octave (assuming octave = 2:1 ratio). This is technically universal, but its origin is 12-TET (100 cents per semitone). Does the `Cents` type carry hidden assumptions?
7. **Compound intervals**: `Interval` caps at octave (12 semitones). The app's MIDI range spans 0–127 (>10 octaves). `Interval.between()` throws for distances > 12. Is this musically limiting for the app's future scope?

### Output Deliverable

A markdown audit report saved to `docs/implementation-artifacts/` containing:
1. Per-type assessment (correct / suspect / wrong) with musical framework cited
2. Hidden assumption inventory
3. Generalizability assessment for non-12-TET tuning systems
4. Recommendations catalogue (for future implementation stories)

### Project Structure Notes

- All audited files live in `Peach/Core/Audio/` — no cross-feature concerns
- `Core/` is framework-free (no SwiftUI, UIKit, Charts imports)
- Domain types are pure value types (`struct`/`enum`) with `Sendable` conformance

### References

- [Source: Peach/Core/Audio/Interval.swift] — Interval enum with 13 cases
- [Source: Peach/Core/Audio/DirectedInterval.swift] — DirectedInterval struct + MIDINote.transposed(by:)
- [Source: Peach/Core/Audio/Direction.swift] — Direction enum
- [Source: Peach/Core/Audio/TuningSystem.swift] — centOffset(), frequency bridge, storage identifiers
- [Source: Peach/Core/Audio/MIDINote.swift] — MIDINote struct with name, random, Comparable
- [Source: Peach/Core/Audio/DetunedMIDINote.swift] — MIDINote + Cents offset
- [Source: Peach/Core/Audio/Frequency.swift] — Physical Hz, concert440
- [Source: Peach/Core/Audio/Cents.swift] — Microtonal offset
- [Source: docs/project-context.md] — Two-world architecture, domain rules
- [Source: docs/planning-artifacts/architecture.md#v0.3-amendment] — Original domain type design decisions

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

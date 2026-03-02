# Story 30.1: Add Just Intonation Tuning System Case

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer extending Peach's tuning system support**,
I want to add a `.justIntonation` case to the `TuningSystem` enum with its complete `centOffset(for:)` implementation, storage identifier, and comprehensive tests,
so that the app can compute interval frequencies using 5-limit just intonation ratios — the tuning system recommended by the Epic 29 research as the most practically relevant for musicians.

## Acceptance Criteria

1. **Given** `TuningSystem` enum, **when** inspecting its cases, **then** a new `.justIntonation` case exists alongside `.equalTemperament`
2. **Given** `TuningSystem.justIntonation`, **when** calling `centOffset(for:)` for each of the 13 intervals (P1–P8), **then** it returns the 5-limit just intonation cent values: P1=0.000, m2=111.731, M2=203.910, m3=315.641, M3=386.314, P4=498.045, TT=590.224, P5=701.955, m6=813.686, M6=884.359, m7=1017.596, M7=1088.269, P8=1200.000
3. **Given** `TuningSystem.justIntonation`, **when** computing `frequency(for:referencePitch:)` for a detuned MIDI note, **then** the result is accurate to within 0.1 cent of the theoretical value (NFR14) — verified by comparing against independently calculated frequencies using the just intonation ratios
4. **Given** `TuningSystem.justIntonation`, **when** accessing `storageIdentifier`, **then** it returns `"justIntonation"`
5. **Given** the string `"justIntonation"`, **when** calling `TuningSystem.fromStorageIdentifier(_:)`, **then** it returns `.justIntonation`
6. **Given** `TuningSystem.allCases`, **when** counting cases, **then** there are exactly 2 cases (`.equalTemperament` and `.justIntonation`)
7. **Given** `TuningSystem.justIntonation`, **when** encoding and decoding via `Codable`, **then** round-trip produces the same value
8. **Given** the existing `frequency(for:referencePitch:)` method, **when** called with `.justIntonation`, **then** no changes to the method implementation are needed — it works via the universal cents-based formula already in place
9. **Given** no other source files besides `TuningSystem.swift` and its test file, **when** this story is complete, **then** no changes were made to `Interval.swift`, `DirectedInterval.swift`, `NotePlayer`, `ComparisonSession`, `PitchMatchingSession`, or any training/data logic (FR55 verification)

## Tasks / Subtasks

- [ ] Task 1: Write failing tests for `.justIntonation` cent offsets (AC: #1, #2)
  - [ ] 1.1 Add test: `justIntonation centOffset for all 13 intervals returns correct values` — table-driven test iterating all `Interval.allCases` against the expected cent values from the research report
  - [ ] 1.2 Add test: `justIntonation centOffset for prime returns 0.0` — explicit edge case
  - [ ] 1.3 Add test: `justIntonation centOffset for octave returns 1200.0` — explicit edge case
  - [ ] 1.4 Add test: `justIntonation centOffset for majorThird returns 386.314` — the signature JI interval (14¢ flatter than 12-TET)
  - [ ] 1.5 Add test: `justIntonation centOffset for perfectFifth returns 701.955` — verifies the Pythagorean/JI pure fifth
- [ ] Task 2: Write failing tests for storage identifiers (AC: #4, #5)
  - [ ] 2.1 Add test: `storageIdentifier returns "justIntonation" for justIntonation`
  - [ ] 2.2 Add test: `fromStorageIdentifier round-trips justIntonation`
  - [ ] 2.3 Update existing test: `fromStorageIdentifier returns nil for unknown identifier` — remove `"justIntonation"` from the unknown-identifier assertions (it is currently tested as unknown)
- [ ] Task 3: Write failing tests for CaseIterable and Codable (AC: #6, #7)
  - [ ] 3.1 Update test: `CaseIterable gives 2 cases` (currently asserts 1)
  - [ ] 3.2 Add test: `Codable round-trip preserves justIntonation`
- [ ] Task 4: Write failing tests for frequency precision (AC: #3, #8)
  - [ ] 4.1 Add test: `justIntonation frequency for just major third is accurate to 0.1 cent` — compute expected Hz from ratio 5/4 applied to reference, compare with `TuningSystem.justIntonation.frequency(for:referencePitch:)` using a `DetunedMIDINote` built from the cent offset
  - [ ] 4.2 Add test: `justIntonation frequency for just perfect fifth is accurate to 0.1 cent` — ratio 3/2
  - [ ] 4.3 Add test: `justIntonation frequency for just minor seventh is accurate to 0.1 cent` — ratio 9/5, the largest deviation from 12-TET (+17.6¢)
- [ ] Task 5: Implement `.justIntonation` case in `TuningSystem.swift` (AC: #1, #2, #4, #5)
  - [ ] 5.1 Add `case justIntonation` to the enum
  - [ ] 5.2 Add `centOffset(for:)` switch branch with all 13 cent values from research report Section 5.3
  - [ ] 5.3 Add `storageIdentifier` case returning `"justIntonation"`
  - [ ] 5.4 Add `fromStorageIdentifier` mapping for `"justIntonation"`
- [ ] Task 6: Run full test suite and verify all tests pass (AC: all)
  - [ ] 6.1 Run `bin/test.sh` — all existing + new tests must pass
  - [ ] 6.2 Verify FR55: confirm no files were changed besides `TuningSystem.swift` and `TuningSystemTests.swift` (AC: #9)

## Dev Notes

### Technical Requirements

**What this story IS:**
- Add a single enum case (`.justIntonation`) with one new switch branch in `centOffset(for:)` containing 13 hardcoded `Double` constants
- Add two storage identifier mappings (one in `storageIdentifier`, one in `fromStorageIdentifier`)
- Write comprehensive tests mirroring the existing `.equalTemperament` test patterns

**What this story is NOT:**
- No UI changes — story 30.2 handles the Settings picker
- No localization changes — story 30.2 handles display names and descriptions
- No changes to `frequency(for:referencePitch:)` — the universal cents-based formula already handles any tuning system
- No changes to any file outside `TuningSystem.swift` and `TuningSystemTests.swift`
- No new files, no new types, no new protocols

**The cent values are NOT computed — they are constants:**
The 13 cent offset values come directly from the research report (story 29.1, Section 5.3). They are derived from `1200 × log₂(ratio)` for each 5-limit JI ratio. The dev agent must use these exact values — do NOT recompute them, do NOT round them differently:

| Interval | Ratio | Cent Offset (use exactly) |
|----------|-------|--------------------------|
| `.prime` | 1/1 | `0.0` |
| `.minorSecond` | 16/15 | `111.731` |
| `.majorSecond` | 9/8 | `203.910` |
| `.minorThird` | 6/5 | `315.641` |
| `.majorThird` | 5/4 | `386.314` |
| `.perfectFourth` | 4/3 | `498.045` |
| `.tritone` | 45/32 | `590.224` |
| `.perfectFifth` | 3/2 | `701.955` |
| `.minorSixth` | 8/5 | `813.686` |
| `.majorSixth` | 5/3 | `884.359` |
| `.minorSeventh` | 9/5 | `1017.596` |
| `.majorSeventh` | 15/8 | `1088.269` |
| `.octave` | 2/1 | `1200.0` |

**Precision requirement (NFR14):** All frequency computations must be accurate to within 0.1 cent. The existing `frequency(for:referencePitch:)` formula achieves ≤0.025¢ worst-case precision (verified in story 28.2). No changes needed — just verify with tests.

### Architecture Compliance

**FR55 is the governing requirement:**
> FR55: System supports multiple tuning systems beyond 12-TET (e.g., Just Intonation); adding a new tuning system requires no changes to interval or training logic.

This story is the first real-world validation of FR55. The dev agent must prove FR55 holds by confirming zero changes to anything outside `TuningSystem.swift`.

**Two-world architecture (unchanged):**
- Logical world: `MIDINote`, `DetunedMIDINote`, `Interval`, `Cents` — no tuning knowledge
- Physical world: `Frequency` — Hz values
- Bridge: `TuningSystem.frequency(for:referencePitch:)` — sole conversion point
- `centOffset(for:)` is the only method that differs per tuning system — the bridge formula is universal

**Pipeline confirmation from story 28.2:**
- `SoundFontNotePlayer.decompose()` correctly rounds to nearest MIDI note for all JI deviations (all within ±18¢, well inside ±50¢ rounding zone)
- `pitchBendValue()` handles all JI offsets with 0.024¢ precision via 14-bit MIDI pitch bend
- `adjustFrequency()` ±200¢ guard accommodates all JI intervals with 10× margin
- End-to-end precision: ≤0.025¢ worst case — 4× below NFR14 target

**What must NOT change (FR55 checklist):**
- `Interval.swift` — no new cases, no API changes
- `DirectedInterval.swift` — unchanged
- `Direction.swift` — unchanged
- `MIDINote.swift` — unchanged
- `DetunedMIDINote.swift` — unchanged
- `Frequency.swift` — unchanged
- `Cents.swift` — unchanged
- `SoundFontNotePlayer.swift` — unchanged
- `ComparisonSession.swift` — unchanged
- `PitchMatchingSession.swift` — unchanged
- `KazezNoteStrategy.swift` — unchanged
- `TrainingDataStore.swift` — unchanged
- `ComparisonRecord` / `PitchMatchingRecord` — unchanged (already store `tuningSystem` as `storageIdentifier` string)

**Enum conformances preserved:**
`TuningSystem` conforms to `Hashable`, `Sendable`, `CaseIterable`, `Codable`. Adding a new case automatically participates in `CaseIterable` and synthesized `Codable`/`Hashable`. No manual conformance code needed.

### Library & Framework Requirements

**No new dependencies.** This story adds 13 hardcoded constants to an existing Swift enum. Zero external libraries, zero new imports.

- `import Foundation` — already present in `TuningSystem.swift`
- `import Testing` + `@testable import Peach` — already present in `TuningSystemTests.swift`
- No `import SwiftUI`, `import AVFoundation`, or any other framework needed
- **Zero third-party dependencies** rule (project-context.md) is trivially satisfied

### File Structure Requirements

**Exactly 2 files modified, 0 files created:**

| File | Action | What Changes |
|------|--------|-------------|
| `Peach/Core/Audio/TuningSystem.swift` | Modify | Add `case justIntonation`, add `centOffset(for:)` switch branch, add `storageIdentifier` case, add `fromStorageIdentifier` mapping |
| `PeachTests/Core/Audio/TuningSystemTests.swift` | Modify | Add JI cent offset tests, JI frequency precision tests, JI storage identifier tests, update `CaseIterable` count assertion, update `fromStorageIdentifierUnknown` assertion, add JI `Codable` round-trip test |

**No new files.** Do not create separate test files, helper files, or utility files.

**Do not touch these files (FR55):**
- `Peach/Core/Audio/Interval.swift`
- `Peach/Core/Audio/DirectedInterval.swift`
- `Peach/Core/Audio/Direction.swift`
- `Peach/Core/Audio/MIDINote.swift`
- `Peach/Core/Audio/DetunedMIDINote.swift`
- `Peach/Core/Audio/Frequency.swift`
- `Peach/Core/Audio/Cents.swift`
- Any file in `Peach/Comparison/`, `Peach/PitchMatching/`, `Peach/Settings/`, `Peach/Core/Data/`, `Peach/Core/Training/`

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — never XCTest.

**Test structure:** Add tests to the existing `TuningSystemTests` struct in `PeachTests/Core/Audio/TuningSystemTests.swift`. Do not create a new test file.

**All `@Test` functions must be `async`.** No `test` prefix on function names.

**New tests to add (mirror existing `.equalTemperament` patterns):**

```swift
// MARK: - Just Intonation Cent Offsets

@Test("all 13 intervals have correct just intonation cent values")
func allIntervalsJustIntonationCentValues() async {
    // Table-driven: iterate Interval.allCases, compare against expected JI values
    // Use accuracy check: abs(actual - expected) < 0.001
}

@Test("justIntonation centOffset for prime returns 0.0")
func justIntonationPrimeCentOffset() async { ... }

@Test("justIntonation centOffset for octave returns 1200.0")
func justIntonationOctaveCentOffset() async { ... }

@Test("justIntonation centOffset for majorThird returns 386.314")
func justIntonationMajorThirdCentOffset() async { ... }

@Test("justIntonation centOffset for perfectFifth returns 701.955")
func justIntonationPerfectFifthCentOffset() async { ... }

// MARK: - Just Intonation Storage Identifiers

@Test("storageIdentifier returns justIntonation for justIntonation")
func storageIdentifierJustIntonation() async { ... }

@Test("fromStorageIdentifier round-trips justIntonation")
func fromStorageIdentifierJustIntonationRoundTrip() async { ... }

// MARK: - Just Intonation Codable

@Test("Codable round-trip preserves justIntonation")
func codableRoundTripJustIntonation() async throws { ... }

// MARK: - Just Intonation Frequency Precision (NFR14)

@Test("justIntonation frequency for just major third is accurate to 0.1 cent")
func justIntonationFrequencyMajorThird() async { ... }

@Test("justIntonation frequency for just perfect fifth is accurate to 0.1 cent")
func justIntonationFrequencyPerfectFifth() async { ... }

@Test("justIntonation frequency for just minor seventh is accurate to 0.1 cent")
func justIntonationFrequencyMinorSeventh() async { ... }
```

**Existing tests to update:**

1. `caseIterableCount()` — change assertion from `count == 1` to `count == 2`
2. `fromStorageIdentifierUnknown()` — remove `"justIntonation"` from the unknown-identifier assertions (line: `#expect(TuningSystem.fromStorageIdentifier("justIntonation") == nil)`)

**Frequency precision test approach:**
To verify NFR14 independently, compute the expected frequency directly from the JI ratio instead of from cents:
```swift
// For just M3 (ratio 5/4) above A4:
let expectedHz = 440.0 * (5.0 / 4.0)  // = 550.0 Hz exactly
// Then compute via TuningSystem:
let detunedNote = DetunedMIDINote(note: MIDINote(69), offset: Cents(386.314 - 400.0))
// Wait — this doesn't work because centOffset returns absolute cents, not deviation.
```

**Correct approach for frequency precision tests:**
The `frequency(for:referencePitch:)` method takes a `DetunedMIDINote` and uses `note.rawValue - 69 + offset/100` in the formula. To test a just M3 above A4 (MIDI 69):
1. The target note is MIDI 73 (E5) with a detuning of `386.314 - 400.0 = -13.686` cents
2. Build: `DetunedMIDINote(note: MIDINote(73), offset: Cents(-13.686))`
3. Expected Hz: `440.0 × (5/4) = 550.0` exactly
4. Verify: `abs(computed.rawValue - 550.0)` is negligible

This mirrors how the pipeline actually works: `decompose()` splits a frequency into nearest MIDI note + cent offset, so testing with `DetunedMIDINote` at the JI offset validates the real path.

**Run full suite:** `bin/test.sh` — all tests must pass before committing.

### Previous Story Intelligence

**Story 29.1 (Research Tuning Systems) — direct predecessor:**
- Recommended **5-limit Just Intonation** with score 19/20
- Provided the complete cent offset table (Section 5.3) — use these exact values
- Documented 4 edge cases (syntonic comma, tritone ambiguity, m7 ratio choice, position-independence simplification) — none affect this story's implementation, but the dev should be aware
- Provided Swift implementation preview matching the exact pattern needed
- Research report location: `docs/implementation-artifacts/29-1-research-report-tuning-systems-used-by-musicians.md`

**Story 28.2 (NotePlayer Pipeline Audit) — pipeline validation:**
- Verified just P5 (+1.955¢) and just M3 (-13.686¢) trace through the full pipeline correctly
- Confirmed ±200¢ pitch bend range accommodates all JI deviations with 10× margin
- End-to-end precision: ≤0.025¢ worst case
- Conclusion: "No pipeline changes required to support non-12-TET tuning systems"

**Story 28.1 (Domain Types Audit) — API shape validation:**
- Confirmed `centOffset(for:)` is the designed extension point for new tuning systems
- Confirmed position-independent tuning systems (like JI) fit the API without changes
- Finding F-6: `centOffset(for:)` is unused in production but architecturally sound for this purpose

**Key learnings from previous stories:**
- The existing test file (`TuningSystemTests.swift`) has clear `// MARK:` sections — follow the same organizational pattern
- Tests use `#expect()` with direct equality for exact values, `abs(x - expected) < tolerance` for floating point
- The `fromStorageIdentifierUnknown` test currently uses `"justIntonation"` as a test case for unknown identifiers — this MUST be updated

### Git Intelligence

**Recent commits (Epic 28-29 research chain):**
```
e915d9e Review story 29.1: Research Tuning Systems Used by Musicians in Practice
65e6485 Implement story 29.1: Research Tuning Systems Used by Musicians in Practice
42ffd87 Add story 29.1: Research Tuning Systems Used by Musicians in Practice
2f5c355 Review story 28.2: Audit NotePlayer and Frequency Computation Chain
c9ccf11 Implement story 28.2: Audit NotePlayer and Frequency Computation Chain
```

**Patterns observed:**
- Commit message format: `{Verb} story {id}: {Description}`
- Stories 28.1, 28.2, and 29.1 were research/audit stories with no code changes — this is the first code story in the tuning system chain
- All research conclusions are already verified and reviewed — the dev agent can trust the cent values without re-deriving them

**Files relevant from recent work:**
- `Peach/Core/Audio/TuningSystem.swift` — the file to modify (last code change was story 21.2)
- `PeachTests/Core/Audio/TuningSystemTests.swift` — the test file to modify (last code change was story 23.1)
- `docs/implementation-artifacts/29-1-research-report-tuning-systems-used-by-musicians.md` — primary reference for cent values

### Project Structure Notes

- `TuningSystem.swift` lives in `Peach/Core/Audio/` — Core/ is framework-free (no SwiftUI, no UIKit)
- Tests mirror source structure: `PeachTests/Core/Audio/TuningSystemTests.swift`
- The enum is 49 lines — compact, well-organized with `// MARK:` sections
- Existing test file is 258 lines with 25 tests — new tests should add approximately 12 more
- No conflicts with unified project structure detected

### References

- [Source: docs/implementation-artifacts/29-1-research-report-tuning-systems-used-by-musicians.md] — Complete research report with cent offset table (Section 5.3), edge cases (Section 5.4), and implementation specification (Section 6)
- [Source: docs/implementation-artifacts/29-1-research-tuning-systems-used-by-musicians-in-practice.md] — Story 29.1 file with completion notes and review record
- [Source: docs/implementation-artifacts/28-2-audit-noteplayer-and-frequency-computation-chain.md] — Pipeline audit confirming no changes needed for non-12-TET
- [Source: docs/implementation-artifacts/28-1-audit-interval-and-tuningsystem-domain-types.md] — Domain types audit confirming `centOffset(for:)` as extension point
- [Source: Peach/Core/Audio/TuningSystem.swift] — Current implementation (49 lines, `.equalTemperament` only)
- [Source: PeachTests/Core/Audio/TuningSystemTests.swift] — Current tests (258 lines, 25 tests) — patterns to mirror
- [Source: Peach/Core/Audio/Interval.swift] — 13 interval enum cases verified against research report
- [Source: docs/project-context.md] — Swift 6.2, Swift Testing, TDD workflow, NFR14 (0.1-cent precision)
- [Source: docs/planning-artifacts/epics.md] — FR55 requirement definition

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

# Story 63.1: Update Planning Documents for MIDI Support

Status: done

## Story

As a **developer reading the planning docs**,
I want documentation to reflect that MIDI input is implemented,
So that the docs remain a reliable source of truth and don't contradict the codebase.

## Acceptance Criteria

1. **Given** `docs/planning-artifacts/prd.md` **When** updated **Then** FR76 reflects that MIDI input is supported (not "reserved for future") **And** the "Deferred" section no longer lists "MIDI input for Rhythm Matching"

2. **Given** `docs/planning-artifacts/rhythm-training-spec.md` **When** updated **Then** ADR-7 (Tap-Only Input for V1) is marked as superseded with reference to Epic 62 **And** "MIDI input" is removed from the "Future Enhancements" section

3. **Given** `docs/planning-artifacts/architecture.md` **When** updated **Then** the `inputMethod` field documentation reflects MIDI as a supported input method **And** the MIDIInput port protocol and MIDIKit adapter are documented in the architecture

4. **Given** `docs/planning-artifacts/epics.md` **When** reviewed **Then** FR76 in the FR coverage map is updated to reflect MIDI support

## Tasks / Subtasks

- [x] Task 1: Update `docs/planning-artifacts/prd.md` (AC: #1)
  - [x] 1.1 Update FR76 at line 552 — change `System accepts tap input only (clap and MIDI reserved for future; inputMethod field reserved in data model)` to reflect that MIDI input is now supported for rhythm matching and pitch matching training, while clap detection remains deferred
  - [x] 1.2 Update "Deferred to subsequent iteration" block at line 166-171 — remove "MIDI input for Rhythm Matching" from the deferred list item `Clap detection (audio input) and MIDI input for Rhythm Matching`; keep clap detection as still deferred
  - [x] 1.3 Verify no other stale MIDI-deferred references remain in the PRD

- [x] Task 2: Update `docs/planning-artifacts/rhythm-training-spec.md` (AC: #2)
  - [x] 2.1 Mark ADR-7 at lines 155-165 as superseded — add a note that this decision was superseded by Epic 62 which implemented MIDI input for both rhythm matching (62.4) and pitch matching (62.5); preserve the original decision text for historical context
  - [x] 2.2 Update "Future Enhancements" section at lines 167-173 — remove MIDI input from the list item `Clap detection (audio input) and MIDI input for Mode 2`; keep clap detection; similarly update the per-input-method latency calibration item to reference only clap
  - [x] 2.3 Update the summary note at line 17 — change `Tap only for v1. Clap (audio input) and MIDI documented as future enhancements` to reflect MIDI is now implemented

- [x] Task 3: Update `docs/planning-artifacts/architecture.md` (AC: #3)
  - [x] 3.1 Update the `inputMethod` reservation comment at line 2153 and design note at line 2158 — change from "reserved for future" to document that MIDI input is implemented via `MIDIInput` port protocol, while clap detection remains future
  - [x] 3.2 Add MIDIInput port protocol documentation in the architecture's port protocols section — document `MIDIInput` protocol in `Core/Ports/`, `MIDIInputEvent` enum (`.noteOn`, `.noteOff`, `.pitchBend`), `MIDIKitAdapter` implementation, and composition root wiring pattern
  - [x] 3.3 Document MIDI integration points — note that `ContinuousRhythmMatchingSession` consumes `.noteOn` for tap input, `PitchMatchingSession` consumes `.pitchBend` for pitch bend input

- [x] Task 4: Update `docs/planning-artifacts/epics.md` FR coverage map (AC: #4)
  - [x] 4.1 Update FR76 row at line 387 — change from `Tap input only (clap/MIDI reserved)` to reflect that MIDI is now supported (Epic 62), clap detection still deferred
  - [x] 4.2 Update FR76 definition at line 94 — same change as above
  - [x] 4.3 Add FR114-FR128 to the coverage map if not already present (these are the MIDI-specific FRs defined in the epics file at lines 133-147, covered by Epic 62)

- [x] Task 5: Verify consistency
  - [x] 5.1 Search all four documents for remaining "MIDI reserved", "MIDI deferred", or "MIDI future" phrases and update any that are stale
  - [x] 5.2 Ensure all changes are internally consistent — no document contradicts another

## Dev Notes

This is a **documentation-only story** — no code changes, no tests needed. All changes are to markdown files in `docs/planning-artifacts/`.

### Key Principle: Supersede, Don't Delete

For ADRs and historical decisions, mark them as superseded rather than deleting them. The original reasoning is valuable historical context. Add a "Superseded by" note at the top of the ADR.

### What MIDI Support Was Implemented (Epic 62)

Epic 62 implemented full MIDI controller input across five stories:
- **62.1**: `MIDIInputEvent` enum (`.noteOn`, `.noteOff`, `.pitchBend`), domain types (`MIDIChannel`, `PitchBendValue`), `MIDIKit` dependency
- **62.2**: `MIDIInput` port protocol in `Core/Ports/`, `MockMIDIInput` for testing, composition root wiring via `@Entry`
- **62.3**: `MIDIKitAdapter` bridging MIDIKit to the `MIDIInput` protocol, USB + Bluetooth MIDI, hot-plug detection
- **62.4**: MIDI note-on as tap input in `ContinuousRhythmMatchingSession`, using `MIDITimeStamp` for timing precision
- **62.5**: MIDI pitch bend for `PitchMatchingSession`, pitch bend wheel drives pitch slider

### What Remains Deferred

- **Clap detection (audio input)** — still requires mic permission, onset detection algorithm, latency calibration
- **Per-input-method latency calibration** — relevant only for clap detection now; MIDI uses hardware timestamps
- **`inputMethod` data model field** — MIDI results are recorded identically to tap results (same `RhythmOffset`, same observer notifications), so no `inputMethod` discriminator was added. The architecture comment should note this design choice

### Exact Locations to Edit

| File | Line(s) | Current Text | Change |
|------|---------|-------------|--------|
| `prd.md` | 552 | `FR76: System accepts tap input only (clap and MIDI reserved for future; inputMethod field reserved in data model)` | Update to reflect MIDI supported |
| `prd.md` | 167 | `Clap detection (audio input) and MIDI input for Rhythm Matching` | Remove MIDI portion |
| `rhythm-training-spec.md` | 155-165 | ADR-7: Tap-Only Input for V1 (full section) | Mark superseded by Epic 62 |
| `rhythm-training-spec.md` | 169 | `Clap detection (audio input) and MIDI input for Mode 2` | Remove MIDI portion |
| `rhythm-training-spec.md` | 170 | `Per-input-method latency calibration (when clap/MIDI added)` | Remove MIDI reference |
| `rhythm-training-spec.md` | 17 | `Tap only for v1. Clap (audio input) and MIDI documented as future enhancements` | Update to reflect MIDI implemented |
| `architecture.md` | 2153 | `// inputMethod field reserved for future (clap detection, MIDI input)` | Update reservation comment |
| `architecture.md` | 2158 | `inputMethod reserved as a comment, not a field — add the field when the first non-tap input is implemented` | Note MIDI is implemented but shares tap recording path |
| `epics.md` | 94 | `FR76: System accepts tap input only (clap and MIDI reserved for future; inputMethod field reserved in data model)` | Update to reflect MIDI supported |
| `epics.md` | 387 | `FR76 | Epic 49 | Tap input only (clap/MIDI reserved)` | Update description and add Epic 62 |

### What NOT To Do

- Do NOT delete ADR-7 — mark it as superseded, preserve the original text
- Do NOT add implementation details (code snippets, class internals) to planning docs — they describe what/why, not how
- Do NOT update `project-context.md` — that file documents code-level rules, not planning decisions
- Do NOT modify any source code or test files
- Do NOT change `docs/implementation-artifacts/` files (story files for Epic 62 are already done)
- Do NOT add new FRs beyond what's already defined (FR114-FR128 already exist in epics.md)

### Project Structure Notes

- All files to edit are in `docs/planning-artifacts/`
- No source tree changes
- No test changes
- No build impact

### References

- [Source: docs/planning-artifacts/epics.md#Epic 62] — MIDI implementation epic with FR114-FR128
- [Source: docs/planning-artifacts/epics.md#Epic 63] — This story's acceptance criteria
- [Source: docs/implementation-artifacts/62-4-midi-input-for-continuous-rhythm-matching-training.md] — MIDI rhythm matching implementation details
- [Source: docs/implementation-artifacts/62-5-midi-pitch-bend-for-pitch-matching-training.md] — MIDI pitch bend implementation details
- [Source: docs/planning-artifacts/prd.md#line 552] — FR76 current text
- [Source: docs/planning-artifacts/rhythm-training-spec.md#ADR-7] — Tap-Only decision to supersede
- [Source: docs/planning-artifacts/architecture.md#line 2153] — inputMethod reservation

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — documentation-only story, no code or tests.

### Completion Notes List

- Updated FR76 in prd.md to reflect MIDI input is supported for rhythm matching and pitch matching
- Removed "MIDI input for Rhythm Matching" from PRD deferred list, keeping clap detection
- Marked ADR-7 (Tap-Only Input) as superseded by Epic 62 in rhythm-training-spec.md, preserving original text
- Updated rhythm-training-spec.md Future Enhancements: removed MIDI from both input method and latency calibration items
- Updated rhythm-training-spec.md summary note at line 17
- Updated architecture.md inputMethod comment and design note to explain MIDI shares tap recording path
- Added v0.7 Architecture Amendment section documenting MIDIInput port protocol, MIDIKitAdapter, and integration points
- Updated FR76 definition and coverage map row in epics.md to reflect MIDI support via Epic 62
- Confirmed FR114-FR128 already present in coverage map
- Verified no stale "MIDI reserved/deferred/future" references remain across all four documents

### Change Log

- 2026-03-27: Updated all four planning documents to reflect MIDI input implementation (Epic 62)

### File List

- `docs/planning-artifacts/prd.md` (modified)
- `docs/planning-artifacts/rhythm-training-spec.md` (modified)
- `docs/planning-artifacts/architecture.md` (modified)
- `docs/planning-artifacts/epics.md` (modified)
- `docs/implementation-artifacts/63-1-update-planning-documents-for-midi-support.md` (modified)

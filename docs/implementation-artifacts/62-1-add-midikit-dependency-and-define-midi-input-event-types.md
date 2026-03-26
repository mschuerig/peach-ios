# Story 62.1: Add MIDIKit Dependency and Define MIDI Input Event Types

Status: review

## Story

As a **developer**,
I want the MIDIKit SPM package available and MIDI input event types defined,
So that the MIDI input infrastructure has its foundation types and external dependency in place.

## Acceptance Criteria

1. **Given** the Xcode project **When** MIDIKit is added as an SPM dependency **Then** only the `MIDIKitIO` product is linked to the Peach target **And** `import MIDIKitIO` compiles successfully

2. **Given** the `MIDIInputEvent` enum in `Core/Music/` **When** defined **Then** it has cases `.noteOn(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)`, `.noteOff(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)`, and `.pitchBend(value: PitchBendValue, channel: UInt8, timestamp: UInt64)` **And** it conforms to `Sendable`  **And** the timestamp is a raw `MIDITimeStamp` (host ticks) preserving sub-millisecond precision

3. **Given** the project **When** built **Then** no entitlements, Info.plist entries, or AVAudioSession changes are required (FR127)

4. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions

## Tasks / Subtasks

- [x] Task 1: Add MIDIKit SPM dependency (AC: #1)
  - [x] 1.1 Add `https://github.com/orchetect/MIDIKit` package to `Peach.xcodeproj` via SPM
  - [x] 1.2 Link only the `MIDIKitIO` product to the `Peach` target (not `MIDIKitCore`, `MIDIKitSMF`, `MIDIKitSync`, etc.)
  - [x] 1.3 Do NOT link MIDIKit to the `PeachTests` target — tests use mocks, never import MIDIKit directly
  - [x] 1.4 Verify `import MIDIKitIO` compiles in a temporary test file, then remove the test file
- [x] Task 2: Create `MIDIInputEvent` enum (AC: #2)
  - [x] 2.1 Create `Peach/Core/Music/MIDIInputEvent.swift`
  - [x] 2.2 Define the enum with three cases using existing domain types: `MIDINote`, `MIDIVelocity`, `PitchBendValue`
  - [x] 2.3 Mark `nonisolated` (same pattern as all Core/Music types) and conform to `Sendable`
  - [x] 2.4 The `timestamp` parameter is `UInt64` (raw `MIDITimeStamp` host ticks) — do NOT wrap in a domain type yet
- [x] Task 3: Write tests for `MIDIInputEvent` (AC: #2)
  - [x] 3.1 Create `PeachTests/Core/Music/MIDIInputEventTests.swift`
  - [x] 3.2 Test construction of all three cases with valid domain types
  - [x] 3.3 Test `Sendable` conformance compiles (value type with all Sendable fields — implicit)
- [x] Task 4: Verify no regressions (AC: #3, #4)
  - [x] 4.1 Run full test suite via `bin/test.sh`
  - [x] 4.2 Verify build succeeds via `bin/build.sh` — no new warnings
  - [x] 4.3 Confirm no entitlement, Info.plist, or AVAudioSession changes in the diff

## Dev Notes

### Architecture Context

This is the first story in the MIDI input epic. It is a foundation story: add the external dependency and define the event types. No protocol, no adapter, no wiring — those come in stories 62.2–62.4.

The `MIDIInputEvent` enum lives in `Core/Music/` alongside existing domain types (`MIDINote`, `MIDIVelocity`, `PitchBendValue`). It is a **broad enum** by design — `.pitchBend` is included from the start to support future pitch matching via MIDI pitch wheel, even though only `.noteOn` is consumed in story 62.4.

### Existing Domain Types to Reuse

All associated value types already exist in `Core/Music/`:
- `MIDINote` (`Core/Music/MIDINote.swift`) — `nonisolated struct`, `rawValue: Int`, range 0–127, `ExpressibleByIntegerLiteral`
- `MIDIVelocity` (`Core/Music/MIDIVelocity.swift`) — `nonisolated struct`, `rawValue: UInt8`, range 1–127, `ExpressibleByIntegerLiteral`
- `PitchBendValue` (`Core/Music/PitchBendValue.swift`) — `nonisolated struct`, `rawValue: UInt16`, range 0–16383, `ExpressibleByIntegerLiteral`, has `static let center = PitchBendValue(8192)`

Do NOT create new types for these. The epic AC says `value: UInt16` for pitchBend — use `PitchBendValue` instead (project convention: domain types everywhere, not raw primitives).

### MIDIKit SPM Dependency Details

- **Repository:** `https://github.com/orchetect/MIDIKit`
- **License:** MIT
- **Latest release:** v0.11.0 (February 2, 2026)
- **Swift:** 6.0, strict concurrency compliant
- **Product to link:** `MIDIKitIO` only — this is the I/O module for sending/receiving MIDI. Other products (`MIDIKitCore`, `MIDIKitSMF`, `MIDIKitSync`) are not needed.
- **This is the first third-party dependency in the project** — previously zero external packages. This was explicitly approved in the MIDI research and epic design.

### Timestamp Design Decision

The `timestamp: UInt64` is a raw `MIDITimeStamp` (host ticks from `mach_absolute_time()`). It is kept as `UInt64` intentionally:
- Sub-millisecond precision for timing-sensitive rhythm training
- USB MIDI: ~100 microsecond accuracy
- BLE MIDI: ~1 ms precision (back-dated by CoreMIDI from BLE timestamps)
- Story 62.4 will compare these timestamps against the audio engine's sample-accurate timing
- Do NOT convert to `Duration` or `TimeInterval` — precision would be lost and the conversion requires `mach_timebase_info` which belongs in the adapter layer (story 62.3)

### What NOT To Do

- Do NOT create `Core/Ports/MIDIInput.swift` — that is story 62.2
- Do NOT create any adapter wrapping MIDIKit — that is story 62.3
- Do NOT add `@Entry` for MIDI in `EnvironmentKeys.swift` — that is story 62.2
- Do NOT wire anything in `PeachApp.swift` — that is story 62.3
- Do NOT add `import MIDIKitIO` to any Core/ file — MIDIKit is only imported in the adapter (story 62.3) and `PeachApp.swift`
- Do NOT add MIDIKit to the test target — domain logic is tested via mocks

### File Placement

| File | Location | Rationale |
|------|----------|-----------|
| `MIDIInputEvent.swift` | `Peach/Core/Music/` | Domain value type alongside `MIDINote`, `MIDIVelocity`, `PitchBendValue` |
| `MIDIInputEventTests.swift` | `PeachTests/Core/Music/` | Mirrors source structure |

### Pattern Reference

Follow the exact pattern of existing `Core/Music/` types:
- `nonisolated` struct/enum (not default MainActor)
- Conform to `Sendable` (and `Hashable` if useful for testing)
- No `import SwiftUI` or `import UIKit` in Core/ files
- No documentation drive-bys on other files

[Source: docs/planning-artifacts/epics.md#Epic 62, Story 62.1]
[Source: docs/planning-artifacts/research/technical-midi-input-ios-research-2026-03-26.md]
[Source: docs/project-context.md]

### Project Structure Notes

- `Core/Music/` already contains 20+ domain types — `MIDIInputEvent` fits naturally
- No new directories needed
- No changes to existing files (pure additive story)
- SPM dependency change will modify `Peach.xcodeproj/project.pbxproj`

### References

- [Source: docs/planning-artifacts/epics.md#Epic 62, Story 62.1] — AC and epic context
- [Source: docs/planning-artifacts/research/technical-midi-input-ios-research-2026-03-26.md] — MIDIKit details, threading, timestamps
- [Source: docs/project-context.md] — File placement, domain type rules, testing rules
- FR114, FR117, FR118, FR121, FR127, FR128 — Functional requirements

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None required.

### Completion Notes List

- Added MIDIKit v0.11.0 as the project's first SPM dependency, linking only `MIDIKitIO` to the Peach target (not PeachTests)
- Created `MIDIInputEvent` enum with three cases (`.noteOn`, `.noteOff`, `.pitchBend`) using existing domain types (`MIDINote`, `MIDIVelocity`, `PitchBendValue`) and raw `UInt64` timestamps
- Enum is `nonisolated`, conforms to `Hashable` and `Sendable`, following existing Core/Music patterns
- Boy Scout fix: added missing `nonisolated` keyword to `MIDIVelocity` struct (was inconsistent with `MIDINote` and `PitchBendValue`)
- 6 new tests for MIDIInputEvent covering construction, equality, and Sendable conformance
- All 1478 tests pass, no regressions, no new warnings, no entitlement/Info.plist/AVAudioSession changes

### Change Log

- 2026-03-26: Implemented story 62.1 — MIDIKit dependency and MIDIInputEvent type

### File List

- `Peach.xcodeproj/project.pbxproj` (modified — MIDIKit SPM dependency)
- `Peach.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (new — SPM lock file)
- `Peach/Core/Music/MIDIInputEvent.swift` (new — domain enum)
- `Peach/Core/Music/MIDIVelocity.swift` (modified — added `nonisolated` keyword)
- `PeachTests/Core/Music/MIDIInputEventTests.swift` (new — 6 tests)
- `docs/implementation-artifacts/sprint-status.yaml` (modified — status update)
- `docs/implementation-artifacts/62-1-add-midikit-dependency-and-define-midi-input-event-types.md` (modified — task completion)

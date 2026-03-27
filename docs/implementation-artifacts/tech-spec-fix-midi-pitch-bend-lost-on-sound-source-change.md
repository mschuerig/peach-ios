---
title: 'Fix MIDI pitch bend lost on sound source change'
type: 'bugfix'
created: '2026-03-27'
status: 'done'
baseline_commit: '7b5e511'
context: ['docs/project-context.md']
---

# Fix MIDI pitch bend lost on sound source change

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** When the user has a non-default sound source, `onChange(of: soundSource)` in `PeachApp` recreates `pitchMatchingSession` without passing `midiAdapter`, because `createPitchMatchingSession` has a default `midiInput: ... = nil` parameter. The new session silently loses MIDI support. This also fires on launch when `@AppStorage` syncs a stored value that differs from the code default.

**Approach:** Remove the `= nil` default from both `createPitchMatchingSession` and `createContinuousRhythmMatchingSession` factory methods so the compiler enforces passing `midiInput` at every call site. Fix the `onChange` handler to pass `midiAdapter`.

## Boundaries & Constraints

**Always:** The session init keeps its `= nil` default (tests legitimately omit MIDI input).

**Ask First:** Whether `createContinuousRhythmMatchingSession` also needs recreation in the `onChange(of: soundSource)` handler (currently it's not recreated there — seems intentional since it uses the step sequencer, not the note player).

**Never:** Do not change MIDI event handling logic or AsyncStream architecture.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Launch with non-default sound source | UserDefaults has `"sf2:8:80"`, `onChange` fires | Recreated session still has MIDI input | N/A |
| Sound source changed at runtime | User picks new instrument in Settings | Recreated session still has MIDI input | N/A |
| Compile-time safety | Call site omits `midiInput` | Compiler error — missing argument | N/A |

</frozen-after-approval>

## Code Map

- `Peach/App/PeachApp.swift` -- factory methods and `onChange` handler with the bug

## Tasks & Acceptance

**Execution:**
- [ ] `Peach/App/PeachApp.swift` -- Remove `= nil` default from `createPitchMatchingSession` `midiInput` parameter; remove `= nil` default from `createContinuousRhythmMatchingSession` `midiInput` parameter; pass `midiAdapter` in `onChange(of: soundSource)` handler

**Acceptance Criteria:**
- Given a non-default sound source stored in UserDefaults, when the app launches, then the pitch matching session has MIDI pitch bend support
- Given the user changes sound source at runtime, when a new pitch matching session is created, then it retains MIDI pitch bend support
- Given a call to `createPitchMatchingSession` or `createContinuousRhythmMatchingSession` that omits `midiInput`, when compiled, then the compiler emits an error

## Verification

**Commands:**
- `bin/build.sh` -- expected: compiles with no errors
- `bin/test.sh` -- expected: all tests pass

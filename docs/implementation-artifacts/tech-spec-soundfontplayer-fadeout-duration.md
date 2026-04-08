---
title: 'Rename stopPropagationDelay to fadeOutDuration and make it preset-aware'
type: 'refactor'
created: '2026-04-08'
status: 'done'
baseline_commit: '4477d10'
context:
  - docs/project-context.md
---

# Rename stopPropagationDelay to fadeOutDuration and make it preset-aware

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `stopPropagationDelay` is a clumsy implementation-detail name for what is simply a fade-out duration. The SoundFontPlayer initializer still uses default parameters, violating the project convention that required dependencies must be explicit. The Sine Wave preset (`sf2:8:80`) clicks on stop because its fade-out is hardcoded to `.zero` like all other presets, even though the mechanism to prevent this already exists.

**Approach:** Rename `stopPropagationDelay` → `fadeOutDuration` across the entire audio layer. Remove default parameters from `SoundFontPlayer.init`. Add a `determineFadeOutDuration` method on `PeachApp` that returns the correct `Duration` per preset (`.milliseconds(25)` for Sine Wave, `.zero` for everything else). Update all call sites.

## Boundaries & Constraints

**Always:** Rename consistently — every occurrence of `stopPropagationDelay` in production and test code becomes `fadeOutDuration`. All SoundFontPlayer init call sites must provide every parameter explicitly.

**Ask First:** Expanding the set of presets that get a non-zero fade-out duration.

**Never:** Change the actual fade-out mechanism in `SoundFontPlaybackHandle` or `SoundFontEngine`. Change the rhythm/percussion player's fade-out behavior (stays `.zero`).

</frozen-after-approval>

## Code Map

- `Peach/Core/Audio/SoundFontPlayer.swift` -- owns property + init with defaults to remove
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` -- receives renamed parameter
- `Peach/Core/Audio/SoundFontEngine.swift` -- `stopNotes(channel:stopPropagationDelay:)` parameter rename
- `Peach/Core/Audio/SoundFontRhythmPlaybackHandle.swift` -- call site using `.zero`
- `Peach/Core/Audio/SoundFontStepSequencer.swift` -- call site using `.zero`
- `Peach/App/PeachApp.swift` -- call sites + new `determineFadeOutDuration` method
- `PeachTests/Core/Audio/SoundFontPlaybackHandleTests.swift` -- factory + comments
- `PeachTests/Core/Audio/SoundFontPlayerTests.swift` -- factory + comments
- `PeachTests/Core/Audio/SoundFontPresetStressTests.swift` -- factory
- `PeachTests/Core/Audio/SoundFontEngineTests.swift` -- test call sites
- `PeachTests/Mocks/MockStepSequencerEngine.swift` -- mock signature

## Tasks & Acceptance

**Execution:**
- [ ] `SoundFontPlayer.swift` -- Rename property and init parameter `stopPropagationDelay` → `fadeOutDuration`. Remove defaults from `channel` and `fadeOutDuration` parameters. Update doc comment.
- [ ] `SoundFontPlaybackHandle.swift` -- Rename property and init parameter.
- [ ] `SoundFontEngine.swift` -- Rename `stopPropagationDelay` parameter in `stopNotes` method.
- [ ] `SoundFontRhythmPlaybackHandle.swift` + `SoundFontStepSequencer.swift` -- Update call sites.
- [ ] `PeachApp.swift` -- Add `static func determineFadeOutDuration(for preset: SF2Preset) -> Duration`. Returns `.milliseconds(25)` for `sf2:8:80`, `.zero` otherwise. Update `setupPlayers` and `handleSoundSourceChanged` to call it. Provide `channel:` explicitly at all SoundFontPlayer init sites.
- [ ] Test files -- Update all 4 test files: provide explicit `channel:` and `fadeOutDuration:` in factories, update parameter names and comments.

**Acceptance Criteria:**
- Given any SoundFontPlayer init call, when I inspect it, then all parameters are provided explicitly (no defaults).
- Given the Sine Wave preset (`sf2:8:80`), when `determineFadeOutDuration` is called, then it returns `.milliseconds(25)`.
- Given any other preset, when `determineFadeOutDuration` is called, then it returns `.zero`.
- Given a clean build, when `bin/build.sh && bin/build.sh -p mac` runs, then zero errors.
- Given the test suite, when `bin/test.sh && bin/test.sh -p mac` runs, then all tests pass.

## Verification

**Commands:**
- `bin/build.sh && bin/build.sh -p mac` -- expected: zero errors
- `bin/test.sh && bin/test.sh -p mac` -- expected: all tests pass
- `grep -r stopPropagationDelay Peach/ PeachTests/` -- expected: zero matches

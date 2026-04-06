# Peach Codebase Walkthrough

## Overview

Peach is an ear training app for musicians. It helps users develop four core skills:
- **Pitch discrimination** — hearing two notes and deciding which is higher/lower
- **Pitch matching** — adjusting a slider to tune one note to match another
- **Rhythm offset detection** — hearing a rhythmic pattern and identifying whether the offset note is early or late
- **Continuous rhythm matching** — tapping in time with a metronome to fill rhythmic gaps

Six training disciplines (unison/interval variants for both pitch modes, plus two rhythm modes) share a common architecture of discipline descriptors, session state machines, and observer-based persistence.

Built as a zero-dependency Swift 6.2 / SwiftUI app targeting iOS 26, iPad, and Mac (native).

## Walkthrough Plan

We follow a bottom-up order: foundations first, then the systems built on them, then the UI.

| # | Layer | Key files / directories | Status |
|---|-------|------------------------|--------|
| 1 | [Domain types](./1-domain-types.md) | `Core/Music/` | done |
| 2 | [Audio engine](./2-audio-engine.md) | `Core/Audio/`, `Core/Ports/` | done |
| 3 | [Training sessions](./3-training-sessions.md) | `Core/Training/`, `PitchDiscrimination/`, `PitchMatching/`, `RhythmOffsetDetection/`, `ContinuousRhythmMatching/` | done |
| 4 | [Data & profiles](./4-data-and-profiles.md) | `Core/Data/`, `Core/Profile/`, `Profile/` | done |
| 5 | [Composition root](./5-composition-root.md) | `App/` (PeachApp, coordinators, platform abstractions) | done |
| 6 | [Screens & navigation](./6-screens-and-navigation.md) | `Start/`, `PitchDiscrimination/`, `PitchMatching/`, `RhythmOffsetDetection/`, `ContinuousRhythmMatching/`, `Profile/`, `Settings/`, `Info/` | done |
| 7 | [Tests](./7-tests.md) | `PeachTests/` | pending |

## Conventions

- **Branch:** all walkthrough work happens on the `walkthrough` branch (branched from `main`)
- **Code annotations:** observations and questions are marked with `// WALKTHROUGH:` comments in the source code — no actual code changes
- **Before merging back to main:** strip all `// WALKTHROUGH:` comments

## How to use

- Each session covers one or two layers
- Discussion notes go into the per-layer files linked above
- Mark layers "done" here as we complete them
- Questions or topics to revisit get added to [open-questions.md](./open-questions.md)

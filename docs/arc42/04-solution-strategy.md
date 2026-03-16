# 4. Solution Strategy

## Technology Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Language & runtime** | Swift 6.2, iOS 26 | Latest-only. No backward compatibility burden. Access to `@Observable`, `@Entry`, structured concurrency, strict sendability. |
| **UI framework** | SwiftUI | Declarative, state-driven. Sufficient for the app's deliberately simple UI. No UIKit except for haptic feedback. |
| **Testing** | Swift Testing (`@Test`, `#expect()`) | Modern, parallel by default, async-native. XCTest reserved for UI tests only. |
| **Data persistence** | SwiftData | Native SwiftUI integration. Atomic writes backed by SQLite. Minimal boilerplate for the flat record models. |
| **Audio engine** | AVAudioEngine + AVAudioUnitSampler | SoundFont (.sf2) instrument playback. Sub-10ms latency. Real-time pitch bend for pitch matching slider. No third-party audio libraries. |
| **Settings storage** | `@AppStorage` (UserDefaults) | Lightweight key-value storage. Changes propagate immediately via SwiftUI bindings. Appropriate for ~10 scalar settings. |
| **Localization** | String Catalogs (.xcstrings) | Xcode-native. English + German. |
| **Dependencies** | Zero third-party | Entire stack is first-party Apple. No SPM packages, no CocoaPods, no Carthage. |

## Top-Level Decomposition

The app follows a **feature-based organization** with a shared `Core/` layer:

- **Feature modules** (`PitchComparison/`, `PitchMatching/`, `Profile/`, `Settings/`, `Start/`, `Info/`) contain screens and feature-specific UI components
- **Core** (`Core/`) contains domain logic, protocols, and services shared across features — subdivided into `Audio/`, `Algorithm/`, `Data/`, `Profile/`, and `Training/`
- **App** (`App/`) contains the composition root (`PeachApp.swift`) and navigation shell (`ContentView.swift`)

The `TrainingSession` protocol unifies both training modes. `PitchComparisonSession` and `PitchMatchingSession` are independent state machines sharing the same `NotePlayer`, `PerceptualProfile`, and `TrainingDataStore`.

## Key Quality Strategies

| Quality Goal | Architectural Approach |
|---|---|
| **Low-friction training** | No onboarding, no session boundaries. Single-tap start. Navigation away stops training silently. App backgrounding returns to Start Screen. |
| **Audio precision** | SoundFont playback via AVAudioUnitSampler. Pitch bend with 14-bit MIDI resolution (±200 cent range). Frequency decomposition to nearest MIDI note + cent offset. |
| **Data integrity** | SwiftData atomic writes. Only completed results are persisted — incomplete comparisons/matches are discarded on interruption. |
| **Testability** | Protocol-first design at every service boundary. Composition root wires all dependencies. Views never instantiate services. Full mock coverage in test target. |
| **Adaptability** | Kazez psychoacoustic staircase algorithm adjusts difficulty continuously. Perceptual profile rebuilt from raw records at startup; incremental Welford updates during training. No session-level caching. |

## Organizational Decisions

- **AI-assisted development workflow:** Features are specified as tech specs (implementation artifacts). AI agents implement against the architecture document and project conventions.
- **Test-first, always:** Every feature begins with tests. The `bin/test.sh` script is the primary feedback loop.
- **Lean documentation:** Architecture docs describe decisions and rationale. Code is the authoritative source for implementation details.
- **Sharing via iOS share sheet:** Users can share training data (CSV) and progress chart snapshots (PNG) through native `ShareLink` integration. No custom sharing infrastructure.

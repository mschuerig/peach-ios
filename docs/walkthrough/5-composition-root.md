# Layer 5: Composition Root

**Status:** done
**Session date:** 2026-04-06

## Architecture Overview

The `App/` directory serves as the composition root — the single place where all dependencies are constructed, wired together, and injected into the SwiftUI view hierarchy via `@Environment`.

```
PeachApp.swift (423 lines)
    │
    ├── init() — constructs ALL objects: ModelContainer, DataStore, SoundFontEngine,
    │            sessions, profile, coordinators, MIDI adapter
    │
    ├── body: Scene — injects ~15 environment values into ContentView
    │
    └── create*Session() — static factories, one per session type
             └── platform-conditional #if os(iOS) / os(macOS) for haptics, audio, policies

ContentView.swift — NavigationStack shell + scene phase handling
EnvironmentKeys.swift — ~15 custom environment keys
TrainingLifecycleCoordinator.swift — session start/stop + background/foreground policy
SettingsCoordinator.swift — settings actions (reset, sound preview, import/export)
PreviewDefaults.swift — stub types + .previewEnvironment() modifier
Platform/ — 11 platform-specific implementations
```

## `PeachApp.swift` (423 lines)

The monolithic composition root. `init()` runs ~180 lines constructing the entire dependency graph:

1. **SwiftData container** — `ModelContainer` with `SchemaV1` + migration plan
2. **Data store** — `TrainingDataStore` wrapping `container.mainContext`
3. **Audio engine** — `SoundFontEngine` with platform-specific `AudioSessionConfiguring`
4. **Sound font library** — SF2 file discovery, preset resolution
5. **Note player** — `SoundFontPlayer` on channel 0 (melodic)
6. **Rhythm player** — `SoundFontPlayer` on channel 1 (percussion)
7. **Step sequencer** — `SoundFontStepSequencer` for continuous rhythm matching
8. **Profile** — `PerceptualProfile` loaded from store via discipline registry (timed)
9. **Progress timeline** — `ProgressTimeline(profile:)`
10. **Transfer service** — `TrainingDataTransferService` with `onDataChanged` callback that triggers full profile rebuild
11. **4 sessions** — each via `create*Session()` factory methods
12. **MIDI adapter** — `MIDIKitAdapter` for external MIDI input
13. **Lifecycle coordinator** — `TrainingLifecycleCoordinator` with all sessions + background policy
14. **Settings coordinator** — `SettingsCoordinator` with data store, profile, transfer service

Each `create*Session()` method handles platform-conditional observer wiring:
- iOS: `HapticFeedbackManager` (real haptics) + `IOSAudioInterruptionObserver`
- macOS: `NoOpHapticFeedbackManager` + `NoOpAudioInterruptionObserver`

**Sound source change:** When the user switches instrument, `handleSoundSourceChanged()` recreates the `NotePlayer`, both pitch sessions, and both coordinators. Rhythm sessions are unaffected (they use the percussion channel).

**Active session tracking:** Four `onChange(of: *.isIdle)` handlers maintain a single `activeSession` reference. Starting any session stops the previously active one — mutual exclusion enforced at the app level.

## `EnvironmentKeys.swift` (83 lines)

~15 custom environment keys split into two patterns:

1. **`@Entry` macro** (new Swift syntax) — for simple types: `progressTimeline`, `activeSession`, `perceptualProfile`, `rhythmPlayer`, `stepSequencer`, `midiInput`, `audioSampleRate`
2. **Manual `EnvironmentKey` structs** — for existential types (`any SoundSourceProvider`, `any UserSettings`) and concrete sessions. Each has a `.stub` default value for previews.

All session keys use concrete types (`PitchDiscriminationSession`, not `any TrainingSession`). Views access sessions by type, not by protocol.

## `ContentView.swift` (128 lines)

Thin shell: `NavigationStack` wrapping `StartScreen()` + scene phase handling.

- **iOS:** Delegates `scenePhase` changes to `TrainingLifecycleCoordinator`
- **macOS:** Additional `NSApplication.didResignActive`/`didBecomeActive` observers, `FocusedSceneValue` for menu commands, `MainWindowReader` for window-close-terminates-app behavior, file importer for CSV import

## `TrainingLifecycleCoordinator.swift` (200 lines)

`@Observable` class managing session start/stop lifecycle across the app. Key responsibilities:

- **Scene phase handling:** Stops training when app backgrounds (iOS) or becomes inactive (macOS). Auto-restarts on return based on `BackgroundPolicy`.
- **Training screen lifecycle:** `trainingScreenAppeared()` / `trainingScreenDisappeared()` — auto-starts on appear if policy allows
- **Help sheet:** Stops training when help opens, restarts on dismiss
- **Toggle:** `toggleTraining()` for macOS menu command
- **Start/stop dispatch:** `startCurrentSession()` / `stopCurrentSession()` switch on `currentTrainingDestination` to call the right session with settings built from `UserSettings`
- **Menu navigation:** `navigate(to:)` stops active session, waits for idle (via `withObservationTracking`), then sets resolved navigation

**`BackgroundPolicy` protocol** (in Core/Ports/) abstracts platform differences:
- iOS: stop only on `.background`, auto-start always true
- macOS: stop on `.background` or `.inactive`, auto-start false (explicit control)

## `SettingsCoordinator.swift` (78 lines)

Facade for settings-related actions:
- `resetAllData()` — deletes all records, resets session data, resets profile, refreshes export
- `playSoundPreview()` / `stopSoundPreview()` — plays A4 at mezzo-piano for instrument preview
- Import/export delegation to `TrainingDataTransferService`

## `PreviewDefaults.swift` (193 lines)

Stub implementations for SwiftUI previews:
- `StubNotePlayer`, `StubRhythmPlayer`, `StubStepSequencer` — inert, non-crashing
- `StubUserSettings` — hardcoded sensible defaults
- `StubSoundSourceProvider`, `StubPitchDiscriminationStrategy`, `StubRhythmOffsetDetectionStrategy`
- `.stub` factories on all 4 sessions + both coordinators
- `View.previewEnvironment()` — injects all stubs at once

## `NavigationDestination.swift`

6-case enum for hub-and-spoke navigation: 4 training modes (pitch discrimination/matching have `isIntervalMode` parameter) + settings + profile.

## `PeachCommands.swift` (200 lines, macOS only)

macOS menu bar: Training menu (start/stop, auto-start toggle, navigation to all 6 disciplines), Profile menu, File commands (export/import), Help commands (per-discipline help sheets).

Uses `@FocusedValue(MenuCommandState.self)` to communicate between menu commands and the content view. `MenuCommandState` carries navigation requests, help sheet content, file importer state.

## `TrainingIdleOverlay.swift`

macOS-specific view modifier: dims the training UI and shows a "Start Training" button when training is not active and auto-start is off.

## `TrainingStatsView.swift`

Shared view showing latest result + session best with trend arrow. Used by pitch training screens.

## Platform Abstractions (`App/Platform/`)

| File | Purpose |
|------|---------|
| `IOSAudioInterruptionObserver` | AVAudioSession interruption + route change handling |
| `NoOpAudioInterruptionObserver` | macOS no-op (no audio session interruptions) |
| `IOSAudioSessionConfigurator` | Sets `.playback` category, 5ms buffer |
| `MacOSAudioSessionConfigurator` | No-op (macOS handles audio sessions automatically) |
| `IOSBackgroundPolicy` | Stop on background, auto-start always |
| `MacOSBackgroundPolicy` | Stop on background/inactive, no auto-start |
| `HapticFeedbackManager` | UIKit haptics for incorrect answers (double tap pattern) |
| `NoOpHapticFeedbackManager` | macOS no-op |
| `PlatformNotifications` | Maps background/foreground to platform notification names |
| `PlatformModifiers` | `.inlineNavigationBarTitle()`, `.platformFormStyle()`, `.platformBackground` |
| `PlatformImage` | Platform-specific PNG encoding from `CGImage` |

The platform abstraction strategy is consistent: Core defines protocols (`AudioInterruptionObserving`, `AudioSessionConfiguring`, `BackgroundPolicy`, `HapticFeedback`), and `App/Platform/` provides platform-specific implementations selected via `#if os(iOS)` / `os(macOS)` at the composition root.

## Other App/ Files

- `CentsFormatting.swift` — `Cents.formatted()` extension using `NumberFormatter` (1 decimal place)
- `HelpContentView.swift` — Reusable markdown-rendered help sections (used by both macOS help sheets and iOS info screen)

## Files to read (suggested order)

1. `PeachApp.swift` — the big init, session factories, sound source change, active session tracking
2. `EnvironmentKeys.swift` — all custom environment keys
3. `ContentView.swift` — navigation shell, scene phase
4. `TrainingLifecycleCoordinator.swift` — start/stop logic, background policy
5. `SettingsCoordinator.swift` — settings actions facade
6. `PreviewDefaults.swift` — stub types, preview environment
7. `NavigationDestination.swift` — routing enum
8. `PeachCommands.swift` — macOS menu bar (skim)
9. `Platform/` — browse for platform abstraction patterns

## Observations and questions

1. **`PeachApp.init()` is a 180-line monolith with duplicated coordinator construction.** Every dependency is constructed inline at the same abstraction level. `rebuildCoordinators()` duplicates the `TrainingLifecycleCoordinator(...)` and `SettingsCoordinator(...)` construction from `init()`, including the `#if os()` conditional for `BackgroundPolicy`. Decompose `init()` into named methods (e.g., `setupAudio()`, `createSessions()`, `buildCoordinators()`) so `rebuildCoordinators()` reuses `buildCoordinators()` instead of duplicating it. The duplication would vanish by construction.

2. **Sound source change recreates sessions and coordinators.** `handleSoundSourceChanged()` builds new `PitchDiscriminationSession`, `PitchMatchingSession`, `TrainingLifecycleCoordinator`, and `SettingsCoordinator` from scratch. This is because sessions hold a reference to their `NotePlayer`, which can't be swapped after creation. The cascade is correct but fragile — adding a new dependency to any session requires updating this method too.

3. **`TrainingLifecycleCoordinator` dispatches on `NavigationDestination` with switch.** `startCurrentSession()` and `stopCurrentSession()` have 6-case switch statements mapping destinations to sessions. Adding a training mode requires updating both methods, plus `isTrainingActive`. This is the same enum-switch coupling pattern — consider a `[NavigationDestination: any TrainingSession]` dictionary.

4. **`HapticFeedbackManager` conforms to discipline-specific observer protocols.** It implements `PitchDiscriminationObserver` and `RhythmOffsetDetectionObserver` directly, but not `PitchMatchingObserver` or `ContinuousRhythmMatchingObserver`. This means only two of four training modes get haptic feedback on incorrect answers. If intentional (matching modes don't have "correct/incorrect"), this should be documented.

5. **Two environment key styles coexist.** `@Entry` macro (modern) vs manual `EnvironmentKey` structs. The manual keys exist because they need existential defaults (`any SoundSourceProvider`) or `.stub` factories. This is fine but worth noting — as Swift evolves, `@Entry` may support existentials and the manual keys could be migrated.
6. **`audioSampleRate` environment key has a concrete default that masks missing injection.** `@Entry var audioSampleRate: SampleRate = .standard48000` silently falls back to 48kHz if the environment injection is ever missed. A sample rate mismatch would cause subtle timing bugs in rhythm calculations. The default should be removed — make it optional or use a `fatalError` sentinel so missing injection fails loudly instead of silently producing wrong results.

7. **`SettingsCoordinator` preview constants are disconnected from training.** `previewNote` uses raw `69` instead of a `MIDINote.a4` constant (same raw-literal issue noted in Layer 1). `previewVelocity` is hardcoded to 63 (mezzo-piano) while training sessions use `settings.velocity` from `UserSettings` — the preview should use the same velocity so the user hears what training will actually sound like.

8. **`ContentView` should be split into platform-specific files.** ~75% of the file is macOS-only: 4 extra `@State` properties, 7 modifiers (menu command wiring, window lifecycle, file import), two helper methods, and the `MainWindowReader` representable. The shared code is just `NavigationStack(path:) { StartScreen() }` + `.onChange(of: scenePhase)`. Two separate ContentViews (one per platform) would eliminate all `#if os()` guards, making each version straightforward to read and maintain independently.

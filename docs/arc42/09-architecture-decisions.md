# 9. Architecture Decisions

## AD-1: In-Memory Profile, Not Persisted

**Context:** The perceptual profile aggregates per-note statistics from comparison records. It could be persisted as a separate SwiftData model or kept in memory.

**Decision:** `PerceptualProfile` is never persisted. It is rebuilt from all `ComparisonRecord`s on every app launch, then updated incrementally during training.

**Rationale:**
- Keeps the data model flat (one `@Model` only)
- Avoids synchronization between profile and records
- Profile computation can change (e.g., switch from lifetime average to rolling window) without data migration
- Rebuild from hundreds/thousands of records takes < 100ms

**Trade-off:** Convergence chain state (the last cent offset used by Kazez formulas) is lost on restart. The algorithm bootstraps from neighbor-weighted difficulty, which introduces a brief re-convergence period. This is a [known issue](../implementation-artifacts/future-work.md#convergence-chain-state-not-persisted-across-app-restarts).

## AD-2: Single Orchestrator (TrainingSession)

**Context:** The training loop involves audio playback, algorithm selection, data persistence, profile updates, and UI feedback. These could be coordinated by the view, by multiple collaborating services, or by a single orchestrator.

**Decision:** `TrainingSession` is the sole orchestrator. It is the only component that knows a "comparison" is two notes played in sequence with a user answer.

**Rationale:**
- Clear single responsibility for the training flow
- Error boundary: catches all service errors in one place
- Services stay focused: `NotePlayer` knows frequencies, `NextNoteStrategy` knows note selection, neither knows about the loop
- Views stay thin: observe `TrainingSession` state, send actions, render

## AD-3: Observer Pattern for Side Effects

**Context:** When a comparison is completed, multiple things must happen: persist the record, update the profile, trigger haptic feedback, update trend analysis. These could be direct method calls from `TrainingSession` or an observer/event pattern.

**Decision:** `ComparisonObserver` protocol with an array of observers injected into `TrainingSession`.

**Rationale:**
- `TrainingSession` doesn't know (or care) about the concrete observers
- Adding a new side effect means creating a new observer and wiring it in `PeachApp.swift`
- Each observer handles its own errors independently
- Easy to test: inject only the observers relevant to the test

## AD-4: Protocol-First Design

**Context:** Services could be concrete classes (simpler) or protocol-backed (more testable).

**Decision:** Every service defines a protocol first, then an implementation. `NotePlayer` → `SoundFontNotePlayer`. `NextComparisonStrategy` → `KazezNoteStrategy`.

**Rationale:**
- Enables test mocking without frameworks or subclassing
- Keeps service boundaries explicit and documented
- Supports future swappable implementations (e.g., sampled instrument sounds via `NotePlayer` protocol)
- Small overhead for a small codebase

## AD-5: AVAudioEngine with Pre-Generated Buffers

**Context:** Sine waves could be generated with `AVAudioSourceNode` (real-time callback), `AVAudioPlayerNode` (pre-generated buffer), or `AVTonePlayerUnit` / AudioKit.

**Decision:** `AVAudioPlayerNode` with pre-generated `AVAudioPCMBuffer`. Single engine instance created at startup.

**Rationale:**
- Pre-generated buffers allow precise envelope shaping (5ms attack/release)
- No real-time audio callback complexity
- 44.1kHz mono, ~1.5ms effective latency
- Single engine instance avoids resource conflicts
- No third-party dependency needed for sine wave generation

## AD-6: SwiftData Over Core Data

**Context:** Persistence options include SwiftData, Core Data, SQLite directly, or file-based storage.

**Decision:** SwiftData with `ComparisonRecord` and `PitchMatchingRecord` models.

**Rationale:**
- Native SwiftUI integration (`@Model`, `ModelContainer` via environment)
- Atomic writes via underlying SQLite
- Minimal boilerplate for the simple flat data model
- Crash resilience handled by the framework

## AD-7: @AppStorage for Settings (Not SwiftData)

**Context:** User preferences (slider value, note range, duration, pitch) could live in SwiftData alongside comparison records, or in UserDefaults.

**Decision:** `@AppStorage` (UserDefaults wrapper) with keys centralized in `SettingsKeys.swift`.

**Rationale:**
- Settings are simple key-value pairs, not relational data
- `@AppStorage` provides direct SwiftUI binding — views update automatically
- `TrainingSession` reads settings via `UserDefaults.standard` on each comparison, no injection needed
- Keeps SwiftData focused on the single domain entity

## AD-8: Kazez Convergence with Chain-Based Difficulty

**Context:** The adaptive algorithm needs to adjust difficulty based on user performance. Options include fixed step sizes, percentage adjustments, or psychophysical staircase methods.

**Decision:** Kazez (2001) sqrt(P)-scaled formulas applied to a chain of comparisons. Correct answer: `N = P × [1 - 0.08 × √P]`. Wrong answer: `N = P × [1 + 0.09 × √P]`.

**Rationale:**
- Large initial steps that slow down as difficulty increases (sqrt scaling)
- Single smooth convergence chain regardless of which note is selected
- Per-note difficulty still tracked in profile for weak spot analysis
- Coefficients tuned empirically: 0.08 narrowing (up from original 0.05) for faster convergence, 0.09 widening for stability
- See [hotfix-tune-kazez-convergence.md](../implementation-artifacts/hotfix-tune-kazez-convergence.md) for tuning rationale

## AD-9: Feature-Based Directory Organization

**Context:** Code could be organized by layer (models/, views/, services/) or by feature (Training/, Profile/, Settings/).

**Decision:** Feature-based with a shared `Core/` layer for cross-feature services.

**Rationale:**
- Each feature is self-contained: screen + supporting views in one directory
- `Core/` subdirectories group by domain (Audio, Algorithm, Data, Profile, Training)
- `Core/Training/` holds shared domain types (Comparison, observers, Resettable) used by multiple features
- Test target mirrors source structure exactly
- Clear answer to "where does this file go?" for AI agents and future contributors

## AD-10: Dependency Direction Discipline

**Context:** Peach is a single-module Swift app with no compiler-enforced module boundaries. Without explicit rules, dependency arrows naturally become tangled: Core/ files imported SwiftUI for `@Entry` definitions, feature modules referenced types from other feature modules, and views created service instances directly. These violations were found by adversarial code review (Epic 19) and addressed systematically in Epic 20.

**Decision:**
1. Core/ never depends on feature modules — shared types live in `Core/Training/`
2. Core/ never imports SwiftUI or UIKit — `@Entry` definitions live in `App/EnvironmentKeys.swift`
3. Feature modules do not depend on each other — each defines its own constants
4. Views depend on protocols, not implementations, for all service interactions

**Rationale:**
- Dependency direction is maintained by convention, enforced by code review and adversarial audits
- Prepares the codebase for potential future modularization without requiring it now
- Makes violations visible and intentional rather than accidental
- Small cost: `EnvironmentKeys.swift` consolidation, a few type moves to Core/

**Trade-off:** Some files move away from their "natural" home (e.g., `SoundSourceID` from Settings/ to Core/Audio/) to satisfy the dependency rule. This is acceptable because the rule prevents a larger class of architectural erosion.

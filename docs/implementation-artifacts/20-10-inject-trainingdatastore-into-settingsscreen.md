# Story 20.10: Inject TrainingDataStore into SettingsScreen

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want `SettingsScreen` to receive `TrainingDataStore` via `@Environment` instead of constructing it from a raw `ModelContext`,
So that the view no longer imports SwiftData, service instantiation stays in the composition root, and the persistence implementation detail is hidden behind the existing abstraction.

## Acceptance Criteria

1. **`@Entry var trainingDataStore` exists** -- An environment key for `TrainingDataStore` is defined in `App/EnvironmentKeys.swift`.

2. **`PeachApp` injects the data store** -- `PeachApp.swift` stores the `TrainingDataStore` as `@State` (it is currently a local variable in `init()`) and passes it via `.environment(\.trainingDataStore, dataStore)`.

3. **`SettingsScreen` uses injected data store** -- `SettingsScreen` accesses `@Environment(\.trainingDataStore)` instead of `@Environment(\.modelContext)`.

4. **No SwiftData import in SettingsScreen** -- `SettingsScreen.swift` has no `import SwiftData` and no reference to `ModelContext`.

5. **Reset All Training Data still works** -- The `resetAllTrainingData()` method uses the injected data store to delete records. The injected instance is the same one used by `PeachApp` (shared reference), ensuring data consistency.

6. **SettingsScreen preview updated** -- The `#Preview` block injects an in-memory `TrainingDataStore` via `.environment(\.trainingDataStore, ...)`.

7. **All existing tests pass** -- Full test suite passes with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Add @Entry to EnvironmentKeys.swift (AC: #1)
  - [x] Add `@Entry var trainingDataStore: TrainingDataStore? = nil` (see Dev Agent Record for deviation from fatalError spec)

- [x] Task 2: Store data store in PeachApp (AC: #2)
  - [x] Change `dataStore` from a local variable in `init()` to `@State private var dataStore: TrainingDataStore`
  - [x] Add `.environment(\.trainingDataStore, dataStore)` in the view hierarchy

- [x] Task 3: Refactor SettingsScreen (AC: #3, #4)
  - [x] Replace `@Environment(\.modelContext) private var modelContext` with `@Environment(\.trainingDataStore) private var dataStore`
  - [x] Remove `import SwiftData`
  - [x] Change `resetAllTrainingData()` to use the injected `dataStore` with guard-let for optional safety
  - [x] Verify `deleteAll()` is called on the injected instance

- [x] Task 4: Update SettingsScreen preview (AC: #6)
  - [x] Remove `.modelContainer(for:..., inMemory: true)` — no longer needed
  - [x] Preview uses nil default for trainingDataStore (reset button is non-functional in preview, which is acceptable)

- [x] Task 5: Run full test suite (AC: #5, #7)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] All 598 tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **Shared instance, not a new one** -- The critical fix is that `SettingsScreen` currently creates a *new* `TrainingDataStore(modelContext:)` for the reset operation. After this change, it uses the *same* instance injected by `PeachApp`. This ensures the data store's internal state (if any) is consistent.
- **`fatalError` for @Entry default** -- `TrainingDataStore` requires a `ModelContext` to construct. There is no way to provide a meaningful default without a `ModelContainer`. Since `SettingsScreen` is always rendered within `PeachApp`'s view hierarchy, the environment value is always provided. The `fatalError` default is safe and explicit.
- **`@State` for data store in PeachApp** -- Currently `dataStore` is a local in `PeachApp.init()`. It must be promoted to `@State` to survive SwiftUI view lifecycle recreations and to be injectable via `.environment()`.

### Architecture & Integration

**Modified production files:**
- `Peach/App/EnvironmentKeys.swift` -- add `@Entry var trainingDataStore`
- `Peach/App/PeachApp.swift` -- promote `dataStore` to `@State`, add `.environment(\.trainingDataStore, dataStore)`
- `Peach/Settings/SettingsScreen.swift` -- replace `modelContext` with `trainingDataStore`, remove `import SwiftData`

### Existing Code to Reference

- **`SettingsScreen.swift:~160`** -- `let dataStore = TrainingDataStore(modelContext: modelContext)` in `resetAllTrainingData()`. [Source: Peach/Settings/SettingsScreen.swift]
- **`PeachApp.swift:~23`** -- `let dataStore = TrainingDataStore(modelContext: ...)` as local variable. [Source: Peach/App/PeachApp.swift]
- **`TrainingDataStore.swift`** -- Requires `ModelContext` in init. [Source: Peach/Core/Data/TrainingDataStore.swift]

### Testing Approach

- **No new unit tests** -- The reset behavior is tested through existing `TrainingDataStore` tests.
- **Manual verification** -- Run the app in simulator, add some training data, go to Settings, tap "Reset All Training Data", confirm data is cleared.
- **Full test suite** -- Verifies no regressions.

### Risk Assessment

- **Medium risk: `@State` promotion** -- Promoting `dataStore` from a local to `@State` changes its lifecycle. Verify it survives view recreations correctly. Since `TrainingDataStore` is a class (reference type), `@State` holds the reference stably.
- **Low risk: Preview** -- The preview needs a `ModelContainer`. Use `ModelConfiguration(isStoredInMemoryOnly: true)` to create one.

### Git Intelligence

Commit message: `Implement story 20.9: Inject TrainingDataStore into SettingsScreen`

### References

- [Source: docs/project-context.md -- "only TrainingDataStore accesses SwiftData", "All service instantiation happens in PeachApp.swift"]
- [Source: docs/planning-artifacts/epics.md -- Epic 20]

## Dev Agent Record

### Implementation Notes

- **@Entry default changed from fatalError to optional nil**: The story spec called for `fatalError("TrainingDataStore must be injected via environment")` as the `@Entry` default. However, SwiftUI evaluates `@Entry` default values eagerly during environment initialization — BEFORE `PeachApp` injects the real value. This caused the app to crash on launch with "signal trap". The crash was confirmed via the crash report showing `closure #1 in static EnvironmentValues.__Key_trainingDataStore.defaultValue.getter`. Changed to `TrainingDataStore? = nil` which follows the existing pattern used by `@Entry var activeSession: (any TrainingSession)? = nil`.
- **SettingsScreen resetAllTrainingData uses guard-let**: Since the environment type is optional, the reset function uses `guard let dataStore else { return }`. In production, `dataStore` is never nil because `PeachApp` always injects it. The guard is a safety net.
- **Preview simplified**: Since the type is optional with nil default, the preview no longer needs SwiftData or a ModelContainer. The reset button is non-functional in preview, which is acceptable — it was never testable in preview anyway (SwiftData in-memory containers don't persist across preview renders).
- **Full SwiftData removal from SettingsScreen achieved**: AC #4 is fully satisfied — no `import SwiftData` and no `ModelContext` reference.

## File List

- `Peach/App/EnvironmentKeys.swift` — added `@Entry var trainingDataStore: TrainingDataStore? = nil`
- `Peach/App/PeachApp.swift` — promoted `dataStore` to `@State`, added `.environment(\.trainingDataStore, dataStore)`
- `Peach/Settings/SettingsScreen.swift` — replaced `@Environment(\.modelContext)` with `@Environment(\.trainingDataStore)`, removed `import SwiftData`, updated `resetAllTrainingData()` and preview
- `docs/implementation-artifacts/sprint-status.yaml` — status updated to in-progress → review
- `docs/implementation-artifacts/20-10-inject-trainingdatastore-into-settingsscreen.md` — story file updated

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.
- 2026-02-27: Implemented story — injected TrainingDataStore via @Environment, removed SwiftData from SettingsScreen, used optional nil default instead of fatalError due to SwiftUI eager evaluation.

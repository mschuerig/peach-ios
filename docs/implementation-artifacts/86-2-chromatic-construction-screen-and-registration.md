---
title: 'Story 86.2: Chromatic Construction training screen and PEACH_RESEARCH-gated registration'
type: 'feature'
created: '2026-06-13'
status: 'in-review'
baseline_commit: '875febcc3abbf11bc9ee640595a71847ad55d72c'
context:
  - '{project-root}/docs/planning-artifacts/chromatic-construction-discipline-direction.md'
  - '{project-root}/docs/planning-artifacts/epics.md'
  - '{project-root}/docs/implementation-artifacts/86-1-chromatic-construction-domain-and-session.md'
  - '{project-root}/docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 86.1 landed the Chromatic Construction session and `MonotonicPath` strategy as pure Swift in `Peach/Training/ChromaticConstruction/`. None of it is reachable from the Start screen, the lifecycle coordinator does not know about it, and there is no UI. Michael cannot live with the discipline until it is end-to-end usable behind `PEACH_RESEARCH`.

**Approach:** Mirror TOD's discipline + screen + lifecycle scaffold against the existing 86.1 session. Introduce `NavigationDestination.chromaticConstruction`, `TrainingDisciplineID.chromaticConstruction`, an empty `ChromaticConstructionPayload`, a `ChromaticConstructionDiscipline: TrainingDisciplineUI` with no-op CSV / profile / settings conformances, a `ChromaticConstructionScreen` rendering the 2D contour described in the direction document's *Visualization* section, six supporting subviews, and `ChromaticConstructionLifecycleContribution`. Register inside the existing `#if PEACH_RESEARCH` block in `DisciplineBootstrap.allDisciplines`; wire the session into `PeachApp.swift` behind `#if PEACH_RESEARCH` for state, environment, `trackActiveSession`, and the lifecycle builder.

## Boundaries & Constraints

**Always:**
- Mirror the **actual 86.1 code**, not the epic's pre-redesign terminology. The code uses `ChromaticPath`, `ChromaticConstructionTrial`, `ActivePosition` (1-based `index`), `path.targetOffsetCents(at:)`, `Set<DirectedInterval>`, single `MonotonicPath` strategy (direction encoded in `DirectedInterval`). The epic's `Slot` / `Ladder` / `directionPolicy` do not exist; do not reintroduce them.
- `TrainingCategory` for this discipline is `.intervals` (closest existing fit; reviewable when scoring/persistence lands).
- The training screen's three user-facing controls are view-local `@State` only — no `@AppStorage`, no `SettingsKeys` entry, no `UserSettings` extension. Defaults: `lowerAnchor = MIDINote(60)` (C4), outer interval = `Interval.perfectFifth` (7 semitones), direction mode = mix. Allowed lower anchors: `MIDINote(48)` / `MIDINote(60)` / `MIDINote(72)` (C3/C4/C5). Allowed outer intervals: `.majorSecond` through `.octave` (semitones 2…12 inclusive). Direction mode: `ascending` / `descending` / `mix` (a view-local enum that resolves to a `Set<DirectedInterval>` containing one or both directions).
- Discipline conforms to `TrainingDisciplineUI` with `statisticsKeys = []`, `helpSections = []`, and a no-op `feedRecords(_:into:)`. All four `TrainingDisciplineUI` extension defaults apply (`profileCard = ProgressChartView(mode: id)`, `settingsSections = []`, `settingsHelp = []`, `profileHelp = []`) — do not override. CSV protocol conformance is no-op: `csvTrainingType = "chromaticConstruction"`, `csvColumns = []`, `csvKeyValuePairs` returns `[]`, `parseCSVRow` returns `.failure(.invalidRowData(..., reason: "chromatic-construction has no CSV columns in the experimental cut"))`, `fetchExportRecords` and `parsedRecords` return `[]`, `mergeImportRecords` returns `(0, 0)`, `csvHistory = ChromaticConstructionCSVHistory.history` (a single-version history with no columns, mirroring the CRM CSVHistory file shape).
- `ChromaticConstructionPayload: TrainingDisciplinePayload` is an empty `Codable, Sendable` struct only to satisfy the protocol's `associatedtype Payload`. `disciplineIdentifier = "chromaticConstruction"`, `currentPayloadVersion = 1`. Never persisted in this cut.
- Registration in `DisciplineBootstrap.allDisciplines` goes **inside the existing `#if PEACH_RESEARCH` block** alongside `ContinuousRhythmMatchingDiscipline()` (closure-builder form per `[[project_context]]`). Registration in `DisciplineBootstrap.allCSVHistories` is **unconditional** (matches CRM precedent — migration runner discovers every historical discipline regardless of build).
- `DisciplineIDs.swift`: add `chromaticConstruction = TrainingDisciplineID("chromatic-construction")` and append to `canonicalIDs`. Both edits unconditional (types defined in all builds per the gating-mechanism pattern in `[[project_context]]`).
- In `PeachApp.swift`, **the entire chromatic-construction wiring** — `@State` property, `createAllSessions` tuple field, environment injection, `trackActiveSession` `onChange`, and the lifecycle builder's `contribute(...)` call — is gated by `#if PEACH_RESEARCH`. Non-research builds must compile with zero chromatic-construction references reachable from `PeachApp.body`. `createChromaticConstructionSession(...)` factory is also inside `#if PEACH_RESEARCH`. `EnvironmentKeys.swift` entry is **unconditional** (the key's default `.stub` lets the screen previews and unit tests compile in all builds; the entry mirrors how every other discipline session key is unconditionally present).
- **Dots-only contour (post-review-1 redesign):** horizontal axis = step index 0…N+1 (`N = path.interiorPositionCount`); vertical axis = cents from lower anchor. **No connecting line** between dots — visual line would enable visual-pattern matching. Each step is rendered as a single dot: the two anchors at fixed endpoints; pending positions as dim dots at their **target** Y (`path.targetOffsetCents(at: k)`); placed positions as bright dots at the user's recorded Y (`trial.placed[k-1].offset`). The most-recently-placed position is rendered with a **larger** dot diameter (mirrors the lit-marker convention from `TimingDotView`). During an active touch-and-drag (see *Touch interaction* below), pending dots at indices > active are hidden so the user cannot use them as visual references.
- **Touch interaction (no buttons):** the user adjusts via gesture, not Place/Step Back buttons. Touching any dot at index `k` with `1 ≤ k ≤ session.currentTrial.active?.index` (an interior position, placed or active) (a) reverts the session to position `k` (drops all placed entries `> k` back to pending), (b) starts an orienting playback at the previous-committed pitch (or the lower anchor for `k = 1`), and (c) overlays a short vertical slider on the dot. While dragging, the slider's value is the position's `Cents` offset from the lower anchor; the active dot's Y tracks the slider value; the note plays continuously (cent-debounced replay, see below). Releasing the touch commits the value via `session.place(offset: currentSliderValue)`. Releasing on the final interior position (k = N) implicitly completes the trial (session transitions to `.showingResult`).
- **Slider range and visual:** the slider is centered on the previous-committed pitch (or lower anchor for k = 1) with a **bidirectional ±300 cents** range. Visual height ≈ 60 pt → ~10 c/pt, enough to see direction-of-drag but **too coarse for visual targeting at the 5–10 c precision the discipline trains**. No numeric cent display while walking. The slider's track and thumb are drawn over the active dot's vertical column.
- **No cent numbers while walking; full numbers on result:** during `.walking` no Cents value is shown anywhere on screen (per the design rule "discipline is ear-only, not eye-readable"). In `.showingResult`, each placed dot displays its **absolute** cent offset (from the lower anchor) and **relative** cent offset (from the previous placed). Anchors display their MIDI-note name (e.g. "C4").
- **Result view auto-playback + auto-advance:** on entering `.showingResult` the screen automatically plays back the user's chromatic path: lower anchor → placed[1] → placed[2] → … → placed[N], each note ~500 ms with a ~50 ms inter-note gap, routed through `session.replay(frequency:)`. After playback finishes plus a 1.5 s settling delay, the screen calls `session.nextTrial()` then `session.start(settings:)` with current view-local controls to auto-advance to the next trial. No "Next trial" button. While in `.showingResult` the user can still touch any dot to interrupt the auto-playback and replay that single pitch on tap.
- Audio: cent-debounced replay during drag (~120 ms cancel-and-replace, mirrors 86.1's `playCue` cancellation semantics). Frequency derivation routes through `TuningSystem.equalTemperament.frequency(for: DetunedMIDINote(note: path.lowerAnchor, offset: cents), referencePitch:)` — uses the project's two-world bridge, never the inline `pow(2, cents / Cents.perOctave)` formula. **All audio routes through the session's existing `notePlayer`** so the `scheduleStopAll()` discipline stays inside the session; the session exposes `replay(frequency: Frequency)`.
- Lifecycle: `ChromaticConstructionLifecycleContribution` registers `session: chromaticConstructionSession, destination: .chromaticConstruction`. The `start` closure passed to the builder constructs default settings (`lowerAnchor = MIDINote(60)`, `outerIntervals = [.up(.perfectFifth)]`, `referencePitch = userSettings.referencePitch`) — view-local defaults match these so first-appear is a no-flash happy path. The screen's `onAppear` detects whether `session.currentTrial` matches its view-local controls and, if not, calls `session.stop()` followed by `session.start(settings:)` with view-local values. `pause()` preserves `currentTrial`; `resume()` re-plays the orienting cue (already implemented); `stop()` returns to idle.
- Localization: every user-facing string added to `Localizable.xcstrings` via `bin/add-localization.swift` (English + informal-`du` German per `[[feedback_german_informal]]`). Copy is sober and factual per `[[feedback_sober_factual_copy]]`. Screen displayName / shortLabel: "Walk the Steps" / "Walk" (matches the epic theme).
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` **and** `bin/test.sh --research && bin/test.sh --research -p mac` — all four schemes green. Plus iOS Simulator `Debug (Research)` smoke test per `[[feedback_verify_visual_features]]` + `[[feedback_verify_audio_features]]`: full ascending P5 trial, step-back from walking, step-back from `.showingResult`, "Next trial" flow, anchor + position tap-replay sanity (Grand Piano + Sine Wave at default duration).
- SwiftUI consultations: invoke `/swiftui-pro` for the contour visualization + slider composition; invoke `/swiftui-view-refactor` before the screen body grows past ~40 lines; invoke `/audio-programming` for tap-replay + debounced active-slider playback design.

**Ask First:**
- If `ChromaticConstructionSession`'s tap-replay surface requires more than a single `replay(frequency: Frequency)` method — e.g. distinct `replayLowerAnchor()` / `replayUpperAnchor()` / `replayPlaced(at:)` — pause before adding. **Default plan:** add one `replay(frequency: Frequency)` method that mirrors `playCue(at:)` and routes through `scheduleStopAll()` + `lifecycle?.setTrainingTask`; the screen resolves cents → Frequency.
- If the cent-debounce window for the active-drag replay (~120 ms) feels wrong during smoke test, surface the alternative. **Default plan:** ~120 ms `.task(id:)` cancel-and-replace pattern around the active drag's cent state; mirrors 86.1's `playCue` lifecycle.
- If the lifecycle's default-settings auto-start causes a visible flash when the user lands with default view-local controls (and the screen immediately stops + restarts), surface before tuning. **Default plan:** the screen compares `session.currentTrial?.path`'s `lowerAnchor` + `outerInterval` to view-local controls; if they match, no stop+restart; if they differ, one stop+restart on appear. First-appear with defaults is the happy path.
- If the slider range (±300 cents around the previous committed pitch) lets the user place catastrophically outside the trial (e.g. a position lands more than a semitone off-target), surface before tuning. **Default plan:** keep ±300 c symmetric range; do not constrain monotonicity — wrong-direction placement is a legitimate user error the discipline must permit so the result view can communicate it.
- If `session.revertTo(positionIndex:)` introduces a state machine reachability that 86.1's session contract didn't envisage, surface before adding. **Default plan:** add a session-internal helper that drops all `placed` entries beyond `k` and re-activates position `k`, without playing audio (the touch handler plays the orienting pitch directly via `replay(frequency:)`).

**Never:**
- No `@AppStorage`, no new `SettingsKeys`, no `UserSettings` extension. No persistence of view-local controls across launches.
- No SwiftData `@Model` for chromatic-construction records. No `ChromaticConstructionObserver` protocol. No observer wiring to `TrainingDataStore`, `ProgressTimeline`, or `PerceptualProfile`. `feedRecords` is a no-op; `feedRecords(from:into:)` does not read from the store.
- No `profileCard` / `settingsSections` / `settingsHelp` / `profileHelp` overrides — accept the protocol defaults.
- No discipline-local help namespace (`ChromaticConstructionHelp`). Help is deferred until the discipline graduates from research.
- No hard-coded "100" or "1200" anywhere in view code — derive every cent value from `ChromaticPath` accessors and `Cents.perSemitone` / `Cents.perOctave`. Hidden assumption #3.
- No rounding of placed cent values to nearest MIDI note when computing tap-replay frequency. Hidden assumption #10.
- No new files outside `Peach/Training/ChromaticConstruction/` (except the cross-cutting edits to `NavigationDestination.swift`, `DisciplineIDs.swift`, `DisciplineBootstrap.swift`, `EnvironmentKeys.swift`, `PeachApp.swift`). Discipline file goes under `Peach/Training/ChromaticConstruction/Discipline/` (matches TOD/CRM placement).
- **No "Place" or "Step Back" buttons in any walking-state UI.** Both actions are gesture-implicit: Place = release of the active dot's drag gesture; Step Back = touch on a placed dot at index `< active.index` (which atomically reverts the session to that index). The trial-end "Next trial" button is also removed in favor of auto-advance.
- **No connecting line** between dots in the contour view. The connecting line would let the user read direction and step size visually; the dots-only rendering is the visual contract for the discipline.
- **No cent values displayed during `.walking`** — anywhere on screen, including the slider thumb label, axis tick marks, or accessibility values. Cent values appear only in `.showingResult`.
- No inline `pow(2, cents / Cents.perOctave)` formula in any view file. All cent → Frequency conversion routes through `TuningSystem.equalTemperament.frequency(for: DetunedMIDINote(note: lowerAnchor, offset: cents), referencePitch: settings.referencePitch)`.

</frozen-after-approval>

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fresh ascending P5 trial, gesture-driven placement of all positions at target | `lowerAnchor=C4`, `outerIntervals={.up(.perfectFifth)}`, user drags & releases each active dot at +100c, +200c, …, +600c | Each release commits via `session.place(offset:)`; on the sixth release, session transitions to `.showingResult` and the result view auto-plays the user's path | N/A |
| Touch on a previously placed dot (step-back) | Walking, positions 1–3 placed, active at position 4. User touches dot index 2. | Session reverts to position 2 (drops placed[2..] back to pending); plays prior-committed pitch as orienting cue; slider overlay appears on dot 2 centered on placed[0] | N/A |
| Touch on the current active dot | Walking, active at position k, user touches dot k | Slider overlay appears on dot k; orienting playback at prior-committed pitch; drag adjusts; release commits | N/A |
| Touch on a future (still-pending) dot | Walking, active at position 4, user touches dot 6 | Ignored — touch outside the addressable range; visual feedback only if any | N/A |
| Drag the active dot's slider beyond ±300c | The slider's `in:` range is symmetric around prior-committed; SwiftUI clamps to the range | Active dot's Y reaches the slider edge; release commits at the clamped value | N/A |
| Release on the final interior position | Active at position N, user releases drag | `session.place(offset:)` completes the trial; state → `.showingResult`; result view begins auto-playback after a short delay | N/A |
| Result view auto-playback finishes, auto-advance fires | `.showingResult`, ~1.5 s after the last note of the user's path stops | Screen calls `session.nextTrial()` (state → `.walking`, beginNextTrial fires) **followed by `session.stop()` + `session.start(settings:)`** so the new trial uses the current view-local controls | If `session.nextTrial()` is interrupted (e.g., user navigates away mid-delay), the lifecycle coordinator owns cleanup |
| Tap a dot in `.showingResult` | `.showingResult` view, user taps any dot | Cancels the auto-playback; replays the tapped dot's pitch via `session.replay(frequency:)` | Auto-advance timer is also cancelled until the user is idle for another delay |
| View-local control changes mid-trial | Walking, user changes outer-interval picker | Screen calls `session.stop()` then `session.start(settings:)`; current trial discarded | No partial credit; new trial replaces old |
| Direction mode = mix | `outerIntervals = {.up(.perfectFifth), .down(.perfectFifth)}` | Each new trial draws via `randomElement()`; the contour orientation (ascending vs descending) adapts; slider direction is symmetric around prior-committed (sign of pitch change is user-determined) | N/A |
| App backgrounded mid-trial | Walking with partial trial | `TrainingLifecycleCoordinator` calls `session.stop()`; session returns to `.idle`; foregrounding leads to a fresh trial via the screen's `onAppear` | N/A |
| Help-sheet presentation (future) | Walking | Coordinator calls `session.pause()`; trial state preserved; on dismiss, `session.resume()` re-plays orienting cue | N/A (no help sheet in this cut, but the wiring must not regress for other disciplines) |

## Code Map

- `Peach/Core/NavigationDestination.swift` — add `case chromaticConstruction`.
- `Peach/App/Training/DisciplineIDs.swift` — add static `chromaticConstruction` ID, append to `canonicalIDs`.
- `Peach/App/Training/DisciplineBootstrap.swift` — register inside `#if PEACH_RESEARCH` block; add CSV history to `allCSVHistories` unconditionally.
- `Peach/App/EnvironmentKeys.swift` — unconditional `ChromaticConstructionSessionKey` + extension accessor; `.stub` default.
- `Peach/App/PeachApp.swift` — gated `@State`, `createAllSessions` tuple member, environment injection, `trackActiveSession` `onChange`, lifecycle builder contribute call; `createChromaticConstructionSession` factory (gated).
- `Peach/Training/ChromaticConstruction/ChromaticConstructionSession.swift` — extend with one `replay(frequency: Frequency)` method (mirrors `playCue(at:)`); add a `static let stub` for the environment-key default.
- `Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionDiscipline.swift` — `TrainingDisciplineUI, Sendable`; minimal no-op CSV conformances.
- `Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionPayload.swift` — empty `TrainingDisciplinePayload`.
- `Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionCSVHistory.swift` — single-version no-columns history, mirroring CRM's CSVHistory file.
- `Peach/Training/ChromaticConstruction/ChromaticConstructionLifecycleContribution.swift` — `extension ChromaticConstructionSession { func contribute(to:, userSettings:) }`.
- `Peach/Training/ChromaticConstruction/ChromaticConstructionScreen.swift` — entry view; pulls `@Environment(\.chromaticConstructionSession)`; owns three `@State` properties; applies `.trainingScreen(helpSections:destination:)` modifier.
- `Peach/Training/ChromaticConstruction/ChromaticDirectionMode.swift` — view-local enum {`ascending`, `descending`, `mix`} with `var outerIntervals: (Interval) -> Set<DirectedInterval>`.
- `Peach/Training/ChromaticConstruction/ChromaticContourView.swift` — 2D contour visualization.
- `Peach/Training/ChromaticConstruction/ChromaticPositionSlider.swift` — cent-linear slider for the active position.
- `Peach/Training/ChromaticConstruction/ChromaticOuterIntervalControl.swift` — outer-interval picker (`Interval.majorSecond`…`.octave`).
- `Peach/Training/ChromaticConstruction/ChromaticLowerAnchorSelector.swift` — anchor picker (C3 / C4 / C5).
- `Peach/Training/ChromaticConstruction/ChromaticDirectionSelector.swift` — segmented control for direction mode.
- `Peach/Training/ChromaticConstruction/ChromaticTrialResultView.swift` — trial-end overlay; "Next trial" button.
- `PeachTests/Training/ChromaticConstruction/Discipline/ChromaticConstructionDisciplineTests.swift` — discipline-protocol conformance + empty CSV/profile invariants.
- `PeachTests/Training/ChromaticConstruction/ChromaticConstructionLifecycleContributionTests.swift` — registration smoke test.
- `PeachTests/Training/ChromaticConstruction/ChromaticContourViewTests.swift` — `static` layout method coverage (anchor-coordinate math).
- `PeachTests/Training/ChromaticConstruction/ChromaticDirectionModeTests.swift` — direction-mode → `Set<DirectedInterval>` mapping.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Core/NavigationDestination.swift` — add `case chromaticConstruction` — routing entry the lifecycle coordinator + start screen card navigate to.
- [x] `Peach/App/Training/DisciplineIDs.swift` — add static ID + append to `canonicalIDs` — stable wire identifier; types stay unconditional per gating pattern.
- [x] `Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionPayload.swift` — empty `TrainingDisciplinePayload` — satisfies the `Payload` associated type without persistence.
- [x] `Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionCSVHistory.swift` — single-version history with no columns — needed for the unconditional `allCSVHistories` entry.
- [x] `Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionDiscipline.swift` — `TrainingDisciplineUI` conformance with empty `statisticsKeys` / `helpSections`, no-op CSV methods, no-op `feedRecords` — discipline surface for registry + Start screen card.
- [x] `Peach/Training/ChromaticConstruction/ChromaticConstructionSession.swift` — add `replay(frequency: Frequency)` + `static let stub` — tap-replay entry point + environment-key default.
- [x] `Peach/Training/ChromaticConstruction/ChromaticDirectionMode.swift` — view-local enum mapping to `Set<DirectedInterval>` — keeps the direction concept colocated with the screen.
- [x] `Peach/Training/ChromaticConstruction/ChromaticConstructionLifecycleContribution.swift` — `contribute(to:userSettings:)` extension — registers session with the lifecycle builder using default settings.
- [x] `Peach/Training/ChromaticConstruction/ChromaticContourView.swift` — 2D contour SwiftUI view with `static` layout helpers — per direction-doc *Visualization*; layout math testable in isolation.
- [x] `Peach/Training/ChromaticConstruction/ChromaticPositionSlider.swift` — cent-linear slider for the active `ActivePosition` — places the value in cents from lower anchor.
- [x] `Peach/Training/ChromaticConstruction/ChromaticOuterIntervalControl.swift` — outer-interval picker for `Interval.majorSecond`…`.octave` — view-local @Binding.
- [x] `Peach/Training/ChromaticConstruction/ChromaticLowerAnchorSelector.swift` — anchor picker for C3 / C4 / C5 — view-local @Binding.
- [x] `Peach/Training/ChromaticConstruction/ChromaticDirectionSelector.swift` — segmented control for `ChromaticDirectionMode` — view-local @Binding.
- [x] `Peach/Training/ChromaticConstruction/ChromaticTrialResultView.swift` — trial-end overlay + "Next trial" button — reuses contour view with target overlay.
- [x] `Peach/Training/ChromaticConstruction/ChromaticConstructionScreen.swift` — screen assembly; three `@State` properties; `.trainingScreen(helpSections: [], destination: .chromaticConstruction)` modifier — body ≤ 40 lines after `/swiftui-view-refactor` consult.
- [x] `Peach/App/EnvironmentKeys.swift` — unconditional `ChromaticConstructionSessionKey` + accessor — mirrors every other discipline session key.
- [x] `Peach/App/PeachApp.swift` — `#if PEACH_RESEARCH`-gated wiring (state, factory, environment, `trackActiveSession`, lifecycle builder) — non-research builds compile with zero references.
- [x] `Peach/App/Training/DisciplineBootstrap.swift` — register inside `#if PEACH_RESEARCH` block; add CSV history unconditionally — matches CRM precedent.
- [x] `Localizable.xcstrings` — English + German strings via `bin/add-localization.swift` — informal-`du`, sober copy.
- [x] `PeachTests/Training/ChromaticConstruction/Discipline/ChromaticConstructionDisciplineTests.swift` — assert no-op CSV/profile invariants and `statisticsKeys.isEmpty` — guards against accidental persistence wiring.
- [x] `PeachTests/Training/ChromaticConstruction/ChromaticConstructionLifecycleContributionTests.swift` — assert registry has entry for `.chromaticConstruction` with the session — guards lifecycle routing.
- [x] `PeachTests/Training/ChromaticConstruction/ChromaticContourViewTests.swift` — `static` layout helpers exercised against representative paths (P5 ascending, octave ascending, P5 descending) — pure-Swift checks of anchor/slot coordinate math.
- [x] `PeachTests/Training/ChromaticConstruction/ChromaticDirectionModeTests.swift` — mapping `(.ascending, .perfectFifth)` → `{.up(.perfectFifth)}`, etc., across all three modes — closes the view-local enum's contract.

**Acceptance Criteria:**
- Given a `Debug (Research)` build, when the app launches, then the Start screen shows a "Walk the Steps" card in the `.intervals` category (auto-discovered by `StartScreen.categorySection`).
- Given the user taps the card, when the navigation pushes `.chromaticConstruction`, then `ChromaticConstructionScreen` renders with C4 / P5 / mix defaults and a fresh trial starts.
- Given a fresh ascending P5 trial, when the user touch-and-drags each active dot in turn and releases at the target, then each release commits via `session.place(offset:)`; after the sixth release the session transitions to `.showingResult` and the result view begins auto-playback of the user's path.
- Given walking with positions 1–3 placed and active at position 4, when the user touches dot 2, then the session reverts to position 2 (placed entries 2, 3 dropped to pending) and the slider overlay appears on dot 2 centered on placed[0].
- Given `.showingResult` is presented, when the auto-playback of the user's path completes plus a 1.5 s settling delay, then `session.stop()` + `session.start(settings:)` runs with current view-local controls and a new trial begins automatically — without any user tap.
- Given `.showingResult` is presented, when the user taps any dot, then the auto-playback is cancelled and only the tapped dot's pitch plays via `session.replay(frequency:)`; the auto-advance timer resets.
- Given any of the three view-local controls changes mid-trial, when the change commits, then the current trial discards and a new trial begins with the new parameters.
- Given the app backgrounds mid-trial, when foregrounded, then a fresh trial starts on the screen's `onAppear`.
- Given `.walking` state, no cent value appears anywhere on screen (no slider label, no axis tick, no accessibility value containing a numeric cent value).
- Given `.showingResult` state, each placed dot displays both an absolute cent value (offset from lower anchor) and a relative cent value (offset from the previous placed dot, or from 0 for placed[1]).
- Given a `Debug` (non-research) build, when the app builds and launches, then no Chromatic Construction symbol is referenced and no card appears on the Start screen.
- Pre-commit gate: `bin/test.sh && bin/test.sh -p mac` and `bin/test.sh --research && bin/test.sh --research -p mac` all green; iOS Simulator `Debug (Research)` smoke test passes per Audio Verification rule.

## Spec Change Log

- **2026-06-13 — Iteration 4: continuous tone + audible offsets + step-count picker (post-screenshot feedback).** After Sally consulted, replaced the per-tick discrete-replay slider with a `PlaybackHandle`-driven continuous tone mirroring PitchMatching (`session.startContinuousTone(at:)` / `adjustContinuousTone(to:)` / `stopContinuousTone()`). Replaced per-slider visual Y jitter with per-slider **audible offset** in `[-50, +50]¢` — pending dots now sit on a clean straight baseline (`sliderYOffsets` renamed to `audibleOffsets`). Audio during drag = `drag + offset`; committed value = `drag + offset` (the user's ear-target). Walking-view placed dot Y = `committed − offset` (= drag Y the user saw). Replaced outer-interval picker with `ChromaticStepCountControl` (2…12 steps). Single container `DragGesture` dispatched by location (28 pt hit radius) replaced per-dot `.position()`. Touch-down value set to `priorCommitted − offset` so audio at touch matches "the prior step's audible pitch" (musical continuation). Removed the post-place orienting cue (redundant with the drag's continuous tone; same pitch was confusing rather than clarifying). Drag-jump bug fixed by anchoring translation math on `startingDragCents` (was using `priorCommittedCents`, which jumped the dot on the first tick after touch). Anchors enlarged to 22 pt, color `.primary` for clearer shape signal from the start. **KEEP:** PEACH_RESEARCH gating; lifecycle contribution defaults matching screen defaults; `ChromaticPath` / `ChromaticConstructionTrial` / single `MonotonicPath`; empty payload + empty CSV history; result-view auto-playback + auto-advance; tap-to-replay in result mode; iOS Simulator visual + audio verification gate. **Open for further iteration:** anchor pre-flight shape readability, the exact size of the audible-offset range vs offset distribution, the touch-down visual jump from baseline to `priorCommitted − offset` Y, the slider track length (`sliderTrackHeight = 180 pt`) and drag mapping (`centsPerDragPoint = 600 / 180`).

- **2026-06-13 — UX redesign per agile feedback (intent_gap loopback, iteration 2).** Michael flagged: (a) connecting line on the contour enables visual adjustment, defeating ear-only training; (b) cent number visible during walking is a visual crutch; (c) "Place" and "Step Back" buttons should be implicit gestures. **Amended:** replaced the connecting-line contour with dots-only rendering (bright = placed, dim = pending at target Y, largest = most-recently-placed); replaced Place/Step Back buttons with touch-and-drag gestures; replaced the "Next trial" button with auto-playback of the user's path followed by auto-advance after a 1.5 s settling delay; replaced the screen-driven slider with a per-dot overlay slider (±300 c around prior-committed pitch, ~60 pt visual, ~10 c/pt resolution); no cent numbers during walking; absolute and relative cent numbers per placed dot in `.showingResult`. **KEEP from iteration 1:** PEACH_RESEARCH gating shape; lifecycle contribution defaults matching screen defaults; `ChromaticPath` / `ChromaticConstructionTrial` / single `MonotonicPath` vocabulary; empty payload + empty CSV history shim; localization via `bin/add-localization.swift` (informal-`du`); `replay(frequency:)` session API; the `ChromaticDirectionMode` view-local enum; `ChromaticOuterIntervalControl` and `ChromaticLowerAnchorSelector` (`Interval.majorSecond`…`.octave` and C3/C4/C5 respectively). **Known-bad state avoided:** the connecting-line + cent-number combo from iteration 1 turned the discipline into a visual-matching exercise; the redesign restores the ear-only intent.

## Design Notes

**Sibling for everything:** TOD is the closest sibling — same `TrainingDisciplineUI` shape, same screen/session/lifecycle wiring, same `.trainingScreen(helpSections:destination:)` modifier. Read `TimingOffsetDetectionDiscipline.swift`, `TimingOffsetDetectionScreen.swift`, and `TimingOffsetDetectionLifecycleContribution.swift` first when filling each task. CRM is the closest sibling for **`PEACH_RESEARCH` gating shape** specifically (registration inside `#if PEACH_RESEARCH` block in `DisciplineBootstrap`).

**Why an empty `ChromaticConstructionPayload`:** the `TrainingDiscipline` protocol's `associatedtype Payload: TrainingDisciplinePayload` is non-optional; a concrete type is required even when nothing is persisted. The empty struct is the cheapest conformance that compiles. `feedRecords` simply does not iterate the store; the registry's existential-callable helpers (`csvRows`, `parsedRecordEnvelopes`) trivially produce empty results.

**Why the lifecycle builder's `start` closure uses defaults:** the canonical lifecycle pattern reads settings from persistent `UserSettings` (TOD/CRM/PD/PM). This discipline has no persistent settings — only view-local `@State`. The cheapest accommodation: the lifecycle starts with defaults that match the view's defaults; the view detects mismatches on appear and calls `stop()` + `start(settings:)` with view-local values. First-appear with default controls is the no-flash happy path. (If the visible flash is unacceptable, surface via Ask First.)

**Contour layout (golden example):**
```swift
// In ChromaticContourView, derive plot points purely from the trial + path.
// X normalized to [0, 1] across step indices 0…N+1 (anchors at the endpoints).
// Y normalized to [0, 1] across [0, |outerInterval.cents|] cents; descending
// trials flip the visual orientation (anchor at top-left, target at bottom-right).
let n = path.interiorPositionCount                // e.g. 6 for ascending P5
let placedPoints = trial.placed.enumerated().map { (i, detuned) in
    (x: Double(i + 1) / Double(n + 1), y: detuned.offset.rawValue / outerCents)
}
```

## Verification

**Commands:**
- `bin/test.sh` — expected: zero failures on default iOS scheme.
- `bin/test.sh -p mac` — expected: zero failures on default macOS scheme.
- `bin/test.sh --research` — expected: zero failures on iOS `Debug (Research)`.
- `bin/test.sh --research -p mac` — expected: zero failures on macOS `Debug (Research)`.
- `bin/build.sh` — expected: zero warnings on default iOS scheme (confirms non-research compiles with no references to chromatic-construction wiring inside `PeachApp.body`).

**Manual checks:**
- iOS Simulator `Debug (Research)`: launch app → Start screen shows "Walk the Steps" card → tap → fresh trial → place 6 positions at target → trial-end view → tap "Next trial" → trial restarts. Step-back from walking + from `.showingResult` both work. Tap-replay sounds correct on Grand Piano and Sine Wave (`[[feedback_verify_audio_features]]`). Visual contour matches the direction document's described shape (`[[feedback_verify_visual_features]]`).
- iOS Simulator `Debug` (non-research): launch app → Start screen does **not** show "Walk the Steps" card → navigation enum's `.chromaticConstruction` case is unreferenced from the body (confirmed by build log).

## Suggested Review Order

**Discipline registration & gating**

- `PEACH_RESEARCH`-gated card and unconditional CSV history slot (mirrors CRM precedent).
  [`DisciplineBootstrap.swift:36`](../../Peach/App/Training/DisciplineBootstrap.swift#L36)
- Empty-conformance `TrainingDisciplineUI` for the experimental cut — no statistics, no help, no overrides.
  [`ChromaticConstructionDiscipline.swift:9`](../../Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionDiscipline.swift#L9)
- Empty payload only to satisfy the protocol's `associatedtype Payload`.
  [`ChromaticConstructionPayload.swift:9`](../../Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionPayload.swift#L9)
- Empty single-version CSV history so the migration runner sees a stable wire-format identifier.
  [`ChromaticConstructionCSVHistory.swift:11`](../../Peach/Training/ChromaticConstruction/Discipline/ChromaticConstructionCSVHistory.swift#L11)
- New navigation destination — Start screen iterates from the registry so no manual switch wiring needed.
  [`NavigationDestination.swift:12`](../../Peach/Core/NavigationDestination.swift#L12)
- New stable wire identifier slug.
  [`DisciplineIDs.swift:8`](../../Peach/App/Training/DisciplineIDs.swift#L8)

**App-layer wiring (all gated by `#if PEACH_RESEARCH`)**

- Session `@State`, factory, environment injection, `trackActiveSession` `onChange`, and lifecycle builder contribute — all gated.
  [`PeachApp.swift:25`](../../Peach/App/PeachApp.swift#L25)
- Session-key entry stays unconditional (mirrors every other discipline key); default `.stub` keeps previews + non-research compiles trivial.
  [`EnvironmentKeys.swift:48`](../../Peach/App/EnvironmentKeys.swift#L48)
- Lifecycle contribution registers with **mix-mode defaults** so the lifecycle's start matches the screen's `.mix` view-local default — kills the onAppear ordering race.
  [`ChromaticConstructionLifecycleContribution.swift:11`](../../Peach/Training/ChromaticConstruction/ChromaticConstructionLifecycleContribution.swift#L11)
- Stub + preview environment for previews and the lifecycle-coordinator stub.
  [`PreviewDefaults.swift:130`](../../Peach/App/PreviewDefaults.swift#L130)
- New Start screen routing case (`.chromaticConstruction`) — `#if PEACH_RESEARCH` guards the production screen reference.
  [`StartScreen.swift:69`](../../Peach/Start/StartScreen.swift#L69)

**Session API additions**

- One new public method `replay(frequency:)` delegating to the existing `playCue(at:)` — keeps `scheduleStopAll()` discipline inside the session.
  [`ChromaticConstructionSession.swift:252`](../../Peach/Training/ChromaticConstruction/ChromaticConstructionSession.swift#L252)

**Screen + view-local controls**

- The screen body — owns three view-local `@State` controls (anchor / outer interval / direction mode), reconciles against the lifecycle's running trial, and routes to the trial-end view when `.showingResult`.
  [`ChromaticConstructionScreen.swift:13`](../../Peach/Training/ChromaticConstruction/ChromaticConstructionScreen.swift#L13)
- Debounced active-slider playback via `.task(id: sliderDragCount)` — only user-initiated drags trigger replay; programmatic resets do not.
  [`ChromaticConstructionScreen.swift:34`](../../Peach/Training/ChromaticConstruction/ChromaticConstructionScreen.swift#L34)
- Session-swap onChange (sound source change rebuilds the session) reconciles the new idle session against view-local state.
  [`ChromaticConstructionScreen.swift:33`](../../Peach/Training/ChromaticConstruction/ChromaticConstructionScreen.swift#L33)
- `reconcileSession` — early-return when the running trial matches view-local state; stop+restart otherwise.
  [`ChromaticConstructionScreen.swift:100`](../../Peach/Training/ChromaticConstruction/ChromaticConstructionScreen.swift#L100)
- `resetSliderForActive` — clamps preserved value to the new slider range so step-back never commits an out-of-range cent value.
  [`ChromaticConstructionScreen.swift:128`](../../Peach/Training/ChromaticConstruction/ChromaticConstructionScreen.swift#L128)
- Direction-mode view-local enum mapping to `Set<DirectedInterval>`.
  [`ChromaticDirectionMode.swift:9`](../../Peach/Training/ChromaticConstruction/ChromaticDirectionMode.swift#L9)

**Visualization & subviews**

- 2D contour entry point — anchors as fixed endpoints, committed positions connected by a line, active position as a stroked marker, target line dashed underneath.
  [`ChromaticContourView.swift:13`](../../Peach/Training/ChromaticConstruction/ChromaticContourView.swift#L13)
- Degenerate-span guard pins y to mid-frame when `outerCents == 0` (unreachable from the UI but the helper is testable).
  [`ChromaticContourView.swift:102`](../../Peach/Training/ChromaticConstruction/ChromaticContourView.swift#L102)
- Cent-linear slider for the active position.
  [`ChromaticPositionSlider.swift:11`](../../Peach/Training/ChromaticConstruction/ChromaticPositionSlider.swift#L11)
- Outer-interval picker restricted to `.majorSecond` … `.octave` (excludes `.prime`).
  [`ChromaticOuterIntervalControl.swift:11`](../../Peach/Training/ChromaticConstruction/ChromaticOuterIntervalControl.swift#L11)
- Lower-anchor picker (C3 / C4 / C5).
  [`ChromaticLowerAnchorSelector.swift:9`](../../Peach/Training/ChromaticConstruction/ChromaticLowerAnchorSelector.swift#L9)
- Direction selector — uses dedicated `Ascending`/`Descending`/`Mix` strings to avoid colliding with the existing `Up`/`Down` German translations used by PD/PM.
  [`ChromaticDirectionSelector.swift:8`](../../Peach/Training/ChromaticConstruction/ChromaticDirectionSelector.swift#L8)
- Trial-end view — overlays target line, includes a "Revise final position" affordance so the session's `.showingResult` step-back path is reachable.
  [`ChromaticTrialResultView.swift:13`](../../Peach/Training/ChromaticConstruction/ChromaticTrialResultView.swift#L13)

**Tests**

- Discipline conformance invariants (empty stats / help / CSV).
  [`ChromaticConstructionDisciplineTests.swift:6`](../../PeachTests/Training/ChromaticConstruction/Discipline/ChromaticConstructionDisciplineTests.swift#L6)
- Lifecycle contribution registration smoke test.
  [`ChromaticConstructionLifecycleContributionTests.swift:6`](../../PeachTests/Training/ChromaticConstruction/ChromaticConstructionLifecycleContributionTests.swift#L6)
- Contour layout helpers — ascending / descending end-points + the degenerate-span guard.
  [`ChromaticContourViewTests.swift:6`](../../PeachTests/Training/ChromaticConstruction/ChromaticContourViewTests.swift#L6)
- Direction-mode → `Set<DirectedInterval>` mapping.
  [`ChromaticDirectionModeTests.swift:5`](../../PeachTests/Training/ChromaticConstruction/ChromaticDirectionModeTests.swift#L5)
- New `.chromaticConstruction` branch added to the lifecycle-coordinator test's switch.
  [`TrainingLifecycleCoordinatorTests.swift:701`](../../PeachTests/App/TrainingLifecycleCoordinatorTests.swift#L701)

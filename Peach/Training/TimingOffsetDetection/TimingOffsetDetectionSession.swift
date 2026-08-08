import Foundation
import Observation
import QuartzCore
import os

enum TimingOffsetDetectionSessionState {
    case idle
    case playingPatternLoop
    case awaitingAnswer
    case showingFeedback
    case waitingForGrid
}

@Observable
final class TimingOffsetDetectionSession: TrainingSession, BeatProvider {

    // MARK: - State Machine Types

    enum Event {
        case startRequested
        case answerReceived(direction: TimingDirection)
        case feedbackTimerFired
        case gridAlignmentReached
        case repetitionCapReached
        case stopRequested
        case audioError
    }

    enum Effect {
        case beginNextTrial
        case stopSequencer
        case stopSequencerAtCap
        case evaluateAnswer(direction: TimingDirection)
        case scheduleFeedbackTimer
        case stopAll
    }

    /// Pure state transition function.
    static func reduce(state: inout TimingOffsetDetectionSessionState, event: Event) -> [Effect] {
        switch (state, event) {
        case (.idle, .startRequested):
            state = .playingPatternLoop
            return [.beginNextTrial]

        case (.playingPatternLoop, .answerReceived(let direction)),
             (.awaitingAnswer, .answerReceived(let direction)):
            state = .showingFeedback
            // Mechanism (.stopSequencer) is emitted ahead of policy (.evaluateAnswer)
            // so audio silencing is ordered explicitly rather than buried inside the
            // result-computation effect. From `.awaitingAnswer` the sequencer is
            // already stopped, but emitting `.stopSequencer` again is safe — the
            // chained `enqueueSequencerStop` serializes back-to-back stops.
            return [.stopSequencer, .evaluateAnswer(direction: direction), .scheduleFeedbackTimer]

        case (.showingFeedback, .feedbackTimerFired):
            state = .waitingForGrid
            return []

        case (.waitingForGrid, .gridAlignmentReached):
            state = .playingPatternLoop
            return [.beginNextTrial]

        case (.playingPatternLoop, .repetitionCapReached):
            // Cap exits the audio-playing phase into a silent awaiting-answer phase.
            // The state transition is the idempotence latch: subsequent polls in the
            // same trial see `state != .playingPatternLoop` and the cap check is gated.
            state = .awaitingAnswer
            return [.stopSequencerAtCap]

        case (.idle, .stopRequested):
            return []

        case (.idle, .audioError):
            return []

        case (_, .stopRequested):
            state = .idle
            return [.stopAll]

        case (_, .audioError):
            state = .idle
            return [.stopAll]

        default:
            return []
        }
    }

    // MARK: - Constants

    /// Sub-perceptual UI poll cadence (~125 Hz) that keeps `litDotCount` visually in lockstep with the audio.
    private static let trackingPollingInterval: Duration = .milliseconds(8)

    /// All-rest fallback returned by `nextBeat()` when no trial is active.
    /// A sequencer refill scheduled before `stop()` may still call `nextBeat()` after teardown;
    /// returning silence ensures no audible click pattern leaks past the session's lifetime.
    /// Subdivision count tracks the catalog's default pattern.
    private static let silentBeat = Beat(
        subdivisions: Array(
            repeating: .rest,
            count: TimingOffsetDetectionPatternCatalog.defaultPattern.subdivisions.count
        )
    )

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "TimingOffsetDetectionSession")

    // MARK: - Observable State

    private(set) var state: TimingOffsetDetectionSessionState = .idle
    private(set) var showFeedback: Bool = false
    private(set) var isLastAnswerCorrect: Bool? = nil
    private(set) var litDotCount: Int = 0
    private(set) var sessionBestOffsetPercentage: Double? = nil
    private(set) var sessionBestOffsetMs: Double? = nil

    // MARK: - Dependencies

    private let beatSequencer: any BeatSequencer
    private let strategy: NextTimingOffsetDetectionStrategy
    private let profile: TrainingProfile
    private let observers: [TimingOffsetDetectionObserver]
    private let currentTime: () -> Double
    private var lifecycle: SessionLifecycle?

    // MARK: - Training State

    private var settings: TimingOffsetDetectionSettings?
    private var currentTrial: TimingOffsetDetectionTrial?
    private var lastCompletedTrial: CompletedTimingOffsetDetectionTrial?
    private var gridOrigin: Double?
    private var startTask: Task<Void, Never>?
    private var trackingTask: Task<Void, Never>?
    /// Chained stop task — serializes back-to-back sequencer stops and waits out
    /// any in-flight `startTask` so concurrent start/stop can't race on the sequencer.
    private var stopTask: Task<Void, Never>?

    /// Last subdivision index published to `litDotCount`, gating Observation churn at the 120 Hz tracking rate.
    private var lastPublishedSubdivisionIndex: Int = -1

    /// Pre-start `samplePosition` captured immediately after `beatSequencer.start(...)`
    /// returns — see PF-011 audit (Story 85.3). The post-`start()` reset to
    /// `samplePosition = 0` is observed on the render thread's next callback,
    /// not synchronously on return; until that reset is observed, the polling
    /// task would otherwise read the previous trial's tail value and trip the
    /// cap immediately. While `timing.samplePosition >= staleSamplePositionUpperBound`,
    /// `evaluatePlaybackPosition` skips cap-check and lit-dot publishing. The
    /// gate clears on the first observed transition below the bound (i.e., the
    /// render thread observed the reset) or on session lifecycle transitions
    /// that reset tracking.
    private var staleSamplePositionUpperBound: Int64?

    private var isPaused = false

    var currentOffsetPercentage: Double? {
        guard let trial = currentTrial else { return nil }
        return trial.offset.percentageOfSixteenthNote(at: trial.tempo)
    }

    var lastCompletedOffsetMs: Double? {
        lastCompletedTrial?.offset.absoluteMilliseconds
    }

    // MARK: - Initialization

    init(
        beatSequencer: any BeatSequencer,
        strategy: NextTimingOffsetDetectionStrategy,
        profile: TrainingProfile,
        observers: [TimingOffsetDetectionObserver] = [],
        currentTime: @escaping () -> Double = { CACurrentMediaTime() }
    ) {
        self.beatSequencer = beatSequencer
        self.strategy = strategy
        self.profile = profile
        self.observers = observers
        self.currentTime = currentTime
        self.lifecycle = SessionLifecycle(logger: logger)
    }

    // MARK: - Public API

    var isIdle: Bool { state == .idle }

    var canAcceptAnswer: Bool { state == .playingPatternLoop || state == .awaitingAnswer }

    /// Handles a letter-key shortcut by matching against localized Early/Late keys.
    /// Returns `true` if the key matched and the answer was accepted.
    @discardableResult
    func handleShortcutKey(_ character: String) -> Bool {
        let char = character.lowercased()
        let earlyKey = String(localized: "shortcut.early").lowercased()
        let lateKey = String(localized: "shortcut.late").lowercased()
        if char == earlyKey {
            return handleAnswer(direction: .early)
        } else if char == lateKey {
            return handleAnswer(direction: .late)
        }
        return false
    }

    func start(settings: TimingOffsetDetectionSettings) {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }
        self.settings = settings
        logger.info("Starting timing offset detection training loop")
        send(.startRequested)
    }

    @discardableResult
    func handleAnswer(direction: TimingDirection) -> Bool {
        logger.info("User answered: \(String(describing: direction))")
        let previousState = state
        send(.answerReceived(direction: direction))
        return state != previousState
    }

    func stop() {
        send(.stopRequested)
    }

    func pause() {
        guard !isPaused, state != .idle else { return }
        isPaused = true
        trackingTask?.cancel()
        trackingTask = nil
        lifecycle?.cancelAllTasks()
        enqueueSequencerStop()
        resetTracking()
        showFeedback = false
        isLastAnswerCorrect = nil
        logger.info("Session paused (preserving trial \(String(describing: self.currentTrial)))")
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        guard let settings, currentTrial != nil else {
            logger.info("Session resume called with no current trial; staying idle")
            return
        }
        logger.info("Session resuming from preserved trial")
        // Sequencer restarts at sample position 0; the grid origin was preserved.
        state = .playingPatternLoop
        launchSequencer(settings: settings)
    }

    /// Reconciles the session with the live settings snapshot. Driven by the
    /// lifecycle coordinator on two triggers:
    ///
    /// - **iOS** — returning to a paused training screen (`trainingScreenAppeared`).
    /// - **macOS** — a setting changes while the session is still actively
    ///   playing, because the Settings window is separate and the training
    ///   screen never paused.
    ///
    /// Behaviour:
    /// - Idle → no-op (the next `start()` will pick up the new settings).
    /// - Paused & unchanged → `resume()` the preserved trial (the Story 85.1
    ///   quick-excursion behaviour, e.g. peeking at Profile and back).
    /// - Changed (paused or active) → restart fresh with the new settings, so
    ///   playback reflects the new configuration exactly as returning via the
    ///   Start screen does. `start()`'s sequencer launch drains the `stop()`
    ///   enqueued here, so the back-to-back stop/start is audio-safe.
    /// - Active & unchanged → no-op (keep playing). This is what dedupes the
    ///   pattern picker's paired `selectedPatternId` + `offsetNotePosition`
    ///   writes into a single restart on macOS.
    func reconcile(with refreshed: TimingOffsetDetectionSettings) {
        guard !isIdle else { return }
        if let settings, settings == refreshed {
            if isPaused { resume() }
        } else {
            stop()
            start(settings: refreshed)
        }
    }

    /// Launches the beat sequencer for the current trial. Shared by the
    /// next-trial start path (`beginNextTrial`) and the paused-resume restart
    /// path (`resume()`).
    ///
    /// Drains any in-flight stop (the one `pause()` or `stop()` enqueued) before
    /// starting, so a back-to-back `stop()` + `start()` — as in `reconcile(with:)`'s
    /// restart branch — cannot let `beatSequencer.start` race the pending stop and
    /// leave the sequencer silenced.
    private func launchSequencer(settings: TimingOffsetDetectionSettings) {
        let priorStop = stopTask
        startTask = Task {
            await priorStop?.value
            guard state == .playingPatternLoop, !Task.isCancelled else {
                logger.info("State changed before starting sequencer, aborting")
                return
            }
            // PF-011: snapshot `samplePosition` BEFORE the await on
            // `beatSequencer.start(...)`. The render thread may observe the
            // gen-bump reset to 0 DURING the await (e.g., while `loadPreset`
            // runs); reading `timing.samplePosition` after the await can return
            // 0 even though a stale large value was in flight when start was
            // requested. The pre-await value IS the stale upper bound: while
            // `samplePosition >= bound`, the polling task knows the render
            // thread has not yet committed the post-start reset.
            let prestartSamplePosition = beatSequencer.timing.samplePosition
            do {
                try await beatSequencer.start(tempo: settings.tempo, beatProvider: self)
                guard state == .playingPatternLoop, !Task.isCancelled else {
                    logger.info("State changed while starting sequencer, aborting")
                    return
                }
                setStaleSamplePositionUpperBound(prestartSamplePosition)
                startTrackingLoop()
            } catch is CancellationError {
                logger.info("Sequencer start task cancelled")
            } catch {
                logger.error("Audio error starting sequencer: \(error.localizedDescription)")
                send(.audioError)
            }
        }
    }

    // MARK: - BeatProvider Protocol

    func nextBeat() -> Beat {
        guard let trial = currentTrial, let settings else { return Self.silentBeat }
        return settings.pattern.beat(
            offsetNotePosition: settings.offsetNotePosition,
            offsetAmount: trial.offset.duration
        )
    }

    // MARK: - State Machine Engine

    private func send(_ event: Event) {
        let previousState = state
        let effects = Self.reduce(state: &state, event: event)
        if state == previousState && effects.isEmpty && !isNoOpTransition(event) {
            logger.warning("Invalid transition: \(String(describing: event)) in state \(String(describing: previousState))")
        }
        for effect in effects {
            interpret(effect)
        }
    }

    private func isNoOpTransition(_ event: Event) -> Bool {
        if case .stopRequested = event { return true }
        return false
    }

    // MARK: - Effect Interpreter

    private func interpret(_ effect: Effect) {
        switch effect {
        case .beginNextTrial:
            beginNextTrial()

        case .stopSequencer:
            stopSequencerForAnswer()

        case .stopSequencerAtCap:
            stopSequencerAtCap()

        case .evaluateAnswer(let direction):
            evaluateAnswer(direction: direction)

        case .scheduleFeedbackTimer:
            scheduleFeedbackTimer()

        case .stopAll:
            stopAll()
        }
    }

    // MARK: - Effect Implementations

    private func beginNextTrial() {
        guard let settings else { return }

        if gridOrigin == nil {
            let origin = currentTime()
            gridOrigin = origin
            logger.info("Grid origin established at \(origin)")
        }

        let trial = strategy.nextTimingOffsetDetectionTrial(
            profile: profile,
            settings: settings,
            lastResult: lastCompletedTrial
        )
        currentTrial = trial
        resetTracking()

        launchSequencer(settings: settings)
    }

    /// Installs the PF-011 polling gate from a pre-start `samplePosition`
    /// snapshot. A non-positive observed value cannot be a stale upper bound —
    /// the gate condition is `>= bound`, so a bound of 0 would suppress every
    /// poll until the position advances above zero, which is the opposite of
    /// what we want; leave the gate nil in that case (no stale value to guard
    /// against, e.g., first-ever start after process launch).
    private func setStaleSamplePositionUpperBound(_ prestartSamplePosition: Int64) {
        staleSamplePositionUpperBound = prestartSamplePosition > 0 ? prestartSamplePosition : nil
    }

    private func startTrackingLoop() {
        trackingTask?.cancel()
        // Isolation contract (PF-011 audit, Story 85.3): this `Task` inherits
        // MainActor from `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. The
        // closure is NOT cross-actor; `evaluatePlaybackPosition()` runs on
        // MainActor on every tick. The `@Observable` writes it issues
        // (`litDotCount`, `lastPublishedSubdivisionIndex`,
        // `staleSamplePositionUpperBound`) are therefore NOT data races —
        // safety is provided by isolation, not by Sendable conformance on the
        // BeatProvider/session shape. See Audit Findings §A in
        // `docs/implementation-artifacts/85-3-audit-and-harden-sequencer-concurrency.md`.
        trackingTask = Task {
            while !Task.isCancelled {
                evaluatePlaybackPosition()
                try? await Task.sleep(for: Self.trackingPollingInterval)
            }
        }
    }

    /// Polls `beatSequencer.timing.samplePosition` and updates `litDotCount` on subdivision changes.
    /// Visible for testing.
    func evaluatePlaybackPosition() {
        let timing = beatSequencer.timing
        guard state == .playingPatternLoop,
              let settings,
              timing.samplePosition >= 0,
              timing.samplesPerBeat > 0 else { return }

        // PF-011 polling gate: while the render thread has not yet observed
        // the post-start `samplePosition` reset, the read is stale; skip
        // cap-check and lit-dot publishing. Once a value below the bound is
        // observed (reset committed), release the gate.
        if let bound = staleSamplePositionUpperBound {
            if timing.samplePosition >= bound {
                return
            }
            staleSamplePositionUpperBound = nil
        }

        let subdivisionsPerBeat = settings.pattern.subdivisions.count
        guard subdivisionsPerBeat > 0 else { return }

        let samplesPerSubdivision = timing.samplesPerBeat / Int64(subdivisionsPerBeat)
        guard samplesPerSubdivision > 0 else { return }

        let globalSubdivisionIndex = Int(timing.samplePosition / samplesPerSubdivision)

        // Detect sequencer batch-refill wrap (~every 500 beats): `samplePosition`
        // resets to 0, jumping `globalSubdivisionIndex` backwards. Reset the
        // published-index tracker so the next tick republishes from the wrap
        // without lighting a stale dot for one polling cycle.
        if globalSubdivisionIndex < lastPublishedSubdivisionIndex {
            lastPublishedSubdivisionIndex = -1
        }

        // Cap-reached check runs *before* the `litDotCount` publish so the lit-dot
        // indicator does not flash one extra tick past the cap boundary. The
        // `.repetitionCapReached` event transitions the session out of
        // `.playingPatternLoop`, so the top-of-function state guard suppresses
        // any further polling-driven re-fires.
        let completedCycles = globalSubdivisionIndex / subdivisionsPerBeat
        if completedCycles >= settings.maxRepetitions {
            send(.repetitionCapReached)
            return
        }

        if globalSubdivisionIndex != lastPublishedSubdivisionIndex {
            litDotCount = (globalSubdivisionIndex % subdivisionsPerBeat) + 1
            lastPublishedSubdivisionIndex = globalSubdivisionIndex
        }
    }

    /// Cancels tracking and stops the sequencer in response to a user answer.
    private func stopSequencerForAnswer() {
        cancelTrackingAndReset()
        enqueueSequencerStop { [weak self] in self?.send(.audioError) }
    }

    /// Cancels tracking and stops the sequencer when the per-trial repetition cap is hit.
    /// Reducer has already transitioned the state to `.awaitingAnswer`; the trial completes
    /// via the normal `.answerReceived` path from that state. Failure is teardown-style
    /// (default no-op `onFailure`) to match `stopAll`: an `.audioError` escalation here
    /// would tear down the session before the user can answer.
    private func stopSequencerAtCap() {
        cancelTrackingAndReset()
        enqueueSequencerStop()
    }

    private func cancelTrackingAndReset() {
        trackingTask?.cancel()
        trackingTask = nil
        resetTracking()
    }

    private func evaluateAnswer(direction: TimingDirection) {
        guard let trial = currentTrial else { return }

        let isCorrect = (direction == trial.offset.direction)

        let completed = CompletedTimingOffsetDetectionTrial(
            tempo: trial.tempo,
            offset: trial.offset,
            isCorrect: isCorrect
        )

        lastCompletedTrial = completed

        if isCorrect {
            let pct = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
            let ms = trial.offset.absoluteMilliseconds
            if let best = sessionBestOffsetPercentage {
                if pct < best {
                    sessionBestOffsetPercentage = pct
                    sessionBestOffsetMs = ms
                }
            } else {
                sessionBestOffsetPercentage = pct
                sessionBestOffsetMs = ms
            }
        }

        isLastAnswerCorrect = isCorrect
        showFeedback = true

        observers.forEach { observer in
            observer.timingOffsetDetectionCompleted(completed)
        }
    }

    private func scheduleFeedbackTimer() {
        guard let settings else { return }
        logger.info("Entering feedback state")

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            guard state == .showingFeedback && !Task.isCancelled else { return }

            showFeedback = false
            send(.feedbackTimerFired)

            // Wait for grid alignment
            let quarterDuration = settings.tempo.quarterNoteDuration.timeInterval
            let gridPoint = nextGridPoint(quarterNoteDuration: quarterDuration)
            let now = currentTime()
            let waitTime = gridPoint - now

            if waitTime > 0 {
                logger.info("Waiting \(waitTime)s for grid alignment")
                try? await Task.sleep(for: .seconds(waitTime))
                guard state == .waitingForGrid && !Task.isCancelled else { return }
            }

            logger.info("Grid-aligned, starting next trial")
            send(.gridAlignmentReached)
        })
    }

    private func stopAll() {
        logger.info("Training stopped")

        isPaused = false
        trackingTask?.cancel()
        trackingTask = nil
        lifecycle?.cancelAllTasks()

        // Teardown path uses the default no-op onFailure: an audio error here would re-enter
        // stopAll via the reducer (.audioError → .stopAll), looping. Logging-only is sufficient.
        enqueueSequencerStop()

        currentTrial = nil
        lastCompletedTrial = nil
        settings = nil
        gridOrigin = nil
        showFeedback = false
        isLastAnswerCorrect = nil
        resetTracking()
        sessionBestOffsetPercentage = nil
        sessionBestOffsetMs = nil
    }

    // MARK: - Private Helpers

    /// Serializes sequencer stops so an answer-driven stop followed by a teardown stop
    /// cannot race on the sequencer's internal `runLoopTask`. Each enqueued stop:
    /// awaits the previous stop, cancels-and-awaits any in-flight `startTask`, then calls
    /// `beatSequencer.stop()`. Non-cancellation errors are logged and forwarded to `onFailure`,
    /// which defaults to a no-op (suitable for teardown — errors logged and ignored) and is
    /// overridden by answer-driven stops to send `.audioError` per the spec's audio-error contract.
    private func enqueueSequencerStop(onFailure: @escaping () -> Void = {}) {
        let inflightStart = startTask
        startTask = nil
        let previousStop = stopTask
        stopTask = Task {
            await previousStop?.value
            if let inflightStart {
                inflightStart.cancel()
                await inflightStart.value
            }
            do {
                try await self.beatSequencer.stop()
            } catch is CancellationError {
                return
            } catch {
                self.logger.error("Failed to stop beat sequencer: \(error.localizedDescription)")
                onFailure()
            }
        }
    }

    private func resetTracking() {
        litDotCount = 0
        lastPublishedSubdivisionIndex = -1
        // Lifecycle transitions invalidate the stale-position gate; the next
        // `beatSequencer.start(...)` re-captures the bound.
        staleSamplePositionUpperBound = nil
    }

    private func nextGridPoint(quarterNoteDuration: Double) -> Double {
        guard let gridOrigin else { return currentTime() }
        let now = currentTime()
        let elapsed = now - gridOrigin
        let n = ceil(elapsed / quarterNoteDuration)
        return gridOrigin + n * quarterNoteDuration
    }
}

import Foundation
import Observation
import os

enum ContinuousRhythmMatchingSessionState {
    case idle
    case running
}

@Observable
final class ContinuousRhythmMatchingSession: TrainingSession, StepProvider {

    // MARK: - State Machine Types

    enum Event {
        case startRequested(ContinuousRhythmMatchingSettings)
        case sequencerReady
        case tapHit(GapResult)
        case cycleMissed
        case trialCompleted
        case stopRequested
        case audioError
    }

    enum Effect {
        case startSequencer(ContinuousRhythmMatchingSettings)
        case startTrackingLoop
        case startMIDIListening
        case playTapSound(StepPosition)
        case recordGapResult(GapResult)
        case showHitFeedback(TimingOffset)
        case advanceCycleCount
        case completeTrial
        case stopAll
    }

    /// Pure state transition function.
    static func reduce(state: inout ContinuousRhythmMatchingSessionState, event: Event) -> [Effect] {
        switch (state, event) {
        case (.idle, .startRequested(let settings)):
            state = .running
            return [.startSequencer(settings), .startMIDIListening]

        case (.running, .sequencerReady):
            return [.startTrackingLoop]

        case (.running, .tapHit(let result)):
            return [
                .playTapSound(result.position),
                .recordGapResult(result),
                .showHitFeedback(result.offset),
                .advanceCycleCount
            ]

        case (.running, .cycleMissed):
            return [.advanceCycleCount]

        case (.running, .trialCompleted):
            return [.completeTrial]

        case (.idle, .stopRequested):
            return []

        case (.running, .stopRequested):
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

    static let cyclesPerTrial = 16

    /// Polling interval for real-time cycle tracking (~120 Hz, matching the step sequencer).
    private static let trackingPollingInterval: Duration = .milliseconds(8)

    /// Brief feedback flash duration for gap hits (shorter than discrete mode's 400ms).
    static let feedbackDuration: Duration = .milliseconds(200)

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ContinuousRhythmMatchingSession")

    // MARK: - Observable State

    private(set) var state: ContinuousRhythmMatchingSessionState = .idle
    private(set) var currentStep: StepPosition?
    private(set) var currentGapPosition: StepPosition?
    private(set) var cyclesInCurrentTrial = 0
    private(set) var lastTrialResult: CompletedContinuousRhythmMatchingTrial?
    private(set) var lastHitOffsetMs: Double?
    private(set) var showFeedback = false

    var isRunning: Bool { state == .running }

    // MARK: - Dependencies

    private let stepSequencer: any StepSequencer
    private let midiInput: (any MIDIInput)?
    private let observers: [ContinuousRhythmMatchingObserver]
    private var lifecycle: SessionLifecycle?

    // MARK: - Training State

    private var settings: ContinuousRhythmMatchingSettings?
    private var gapResults: [GapResult] = []
    private var lastEvaluatedCycleIndex: Int = -1
    private var hitCycleIndices: Set<Int> = []
    private var startTask: Task<Void, Never>?
    private var trackingTask: Task<Void, Never>?
    private var midiListeningTask: Task<Void, Never>?

    /// Gap positions indexed by cycle number, populated by nextCycle() during batch scheduling.
    private var gapPositions: [StepPosition] = []

    // MARK: - Initialization

    init(
        stepSequencer: any StepSequencer,
        observers: [ContinuousRhythmMatchingObserver] = [],
        midiInput: (any MIDIInput)? = nil,
        notificationCenter: NotificationCenter = .default,
        audioInterruptionObserver: AudioInterruptionObserving,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil
    ) {
        self.stepSequencer = stepSequencer
        self.midiInput = midiInput
        self.observers = observers
        self.lifecycle = SessionLifecycle(
            logger: logger,
            notificationCenter: notificationCenter,
            audioInterruptionObserver: audioInterruptionObserver,
            backgroundNotificationName: backgroundNotificationName,
            foregroundNotificationName: foregroundNotificationName,
            onStopRequired: { [weak self] in self?.stop() }
        )
    }

    // MARK: - TrainingSession Protocol

    var isIdle: Bool { state == .idle }

    func stop() {
        send(.stopRequested)
    }

    // MARK: - Public API

    func start(settings: ContinuousRhythmMatchingSettings) {
        guard state == .idle else {
            logger.warning("start() called but already running")
            return
        }
        self.settings = settings
        self.gapResults = []
        self.gapPositions = []
        self.hitCycleIndices = []
        self.cyclesInCurrentTrial = 0
        self.lastEvaluatedCycleIndex = -1
        self.lastTrialResult = nil

        logger.info("Starting continuous rhythm matching at \(settings.tempo.value) BPM")
        send(.startRequested(settings))
    }

    func handleTap(atSamplePosition overrideSamplePosition: Int64? = nil) {
        let timing = stepSequencer.timing
        let samplePosition = overrideSamplePosition ?? timing.samplePosition

        guard state == .running else {
            logger.debug("handleTap() called but not running")
            return
        }

        guard samplePosition >= 0,
              timing.samplesPerStep > 0,
              timing.samplesPerCycle > 0 else { return }

        let playingCycleIndex = Int(samplePosition / timing.samplesPerCycle)
        guard playingCycleIndex < gapPositions.count else { return }
        guard !hitCycleIndices.contains(playingCycleIndex) else { return }

        let gapPosition = gapPositions[playingCycleIndex]
        let gapSampleOffset = Int64(playingCycleIndex * 4 + gapPosition.rawValue) * timing.samplesPerStep
        let windowHalfSamples = timing.samplesPerStep / 2

        let offsetSamples = samplePosition - gapSampleOffset

        if abs(offsetSamples) <= windowHalfSamples {
            let offset = Double(offsetSamples) / timing.sampleRate.rawValue
            let rhythmOffset = TimingOffset(.seconds(offset))
            hitCycleIndices.insert(playingCycleIndex)

            let result = GapResult(position: gapPosition, offset: rhythmOffset)
            send(.tapHit(result))
            logger.debug("Gap hit at offset \(offset * 1000, format: .fixed(precision: 1))ms")
        }
    }

    // MARK: - StepProvider Protocol

    func nextCycle() -> CycleDefinition {
        guard state == .running, let settings else {
            return CycleDefinition(gapPosition: .fourth)
        }

        let enabledPositions = settings.enabledGapPositions
        precondition(!enabledPositions.isEmpty, "enabledGapPositions must not be empty")
        let selectedPosition: StepPosition
        if enabledPositions.count == 1 {
            selectedPosition = enabledPositions[enabledPositions.startIndex]
        } else {
            selectedPosition = enabledPositions.randomElement()!
        }

        gapPositions.append(selectedPosition)
        return CycleDefinition(gapPosition: selectedPosition)
    }

    /// Evaluates completed cycles and advances the cycle counter.
    /// Visible for testing.
    func evaluatePlaybackPosition() {
        let timing = stepSequencer.timing
        guard state == .running,
              timing.samplePosition >= 0,
              timing.samplesPerStep > 0,
              timing.samplesPerCycle > 0 else { return }

        let playingCycleIndex = Int(timing.samplePosition / timing.samplesPerCycle)

        let globalStepIndex = Int(timing.samplePosition / timing.samplesPerStep)
        currentStep = StepPosition(rawValue: globalStepIndex % 4)

        if playingCycleIndex < gapPositions.count {
            currentGapPosition = gapPositions[playingCycleIndex]
        }

        while lastEvaluatedCycleIndex < playingCycleIndex - 1 {
            lastEvaluatedCycleIndex += 1
            if !hitCycleIndices.contains(lastEvaluatedCycleIndex) {
                send(.cycleMissed)
            }
        }
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
        case .startSequencer(let settings):
            startSequencer(settings: settings)

        case .startTrackingLoop:
            startTrackingLoop()

        case .startMIDIListening:
            startMIDIListening()

        case .playTapSound(let position):
            let velocity = position == .first ? StepVelocity.accent : StepVelocity.normal
            do {
                try stepSequencer.playImmediateNote(velocity: velocity)
            } catch {
                logger.warning("Failed to play tap note: \(error.localizedDescription)")
            }

        case .recordGapResult(let result):
            gapResults.append(result)

        case .showHitFeedback(let offset):
            showHitFeedback(offset)

        case .advanceCycleCount:
            cyclesInCurrentTrial += 1
            if cyclesInCurrentTrial >= Self.cyclesPerTrial {
                send(.trialCompleted)
            }

        case .completeTrial:
            completeTrial()

        case .stopAll:
            stopAll()
        }
    }

    // MARK: - Effect Implementations

    private func startSequencer(settings: ContinuousRhythmMatchingSettings) {
        startTask = Task {
            do {
                try await stepSequencer.start(tempo: settings.tempo, stepProvider: self)
                send(.sequencerReady)
            } catch is CancellationError {
                logger.info("Session task cancelled")
            } catch {
                logger.error("Failed to start step sequencer: \(error.localizedDescription)")
                send(.audioError)
            }
        }
    }

    private func startTrackingLoop() {
        trackingTask = Task {
            while !Task.isCancelled {
                evaluatePlaybackPosition()
                try? await Task.sleep(for: Self.trackingPollingInterval)
            }
        }
    }

    private func startMIDIListening() {
        guard let midiInput else { return }
        midiListeningTask = Task {
            for await event in midiInput.events {
                guard !Task.isCancelled, state == .running else { break }
                switch event {
                case .noteOn(_, _, let timestamp):
                    let samplePos = stepSequencer.samplePosition(forHostTime: timestamp)
                    handleTap(atSamplePosition: samplePos)
                case .noteOff, .pitchBend:
                    break
                }
            }
            logger.debug("MIDI listening ended")
        }
    }

    private func showHitFeedback(_ offset: TimingOffset) {
        lastHitOffsetMs = offset.duration.timeInterval * 1000.0
        showFeedback = true

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: Self.feedbackDuration)
            guard state == .running, !Task.isCancelled else { return }
            showFeedback = false
        })
    }

    private func completeTrial() {
        guard let settings else { return }

        if !gapResults.isEmpty {
            let trial = CompletedContinuousRhythmMatchingTrial(
                tempo: settings.tempo,
                gapResults: gapResults
            )

            lastTrialResult = trial
            logger.info("Trial completed: \(trial.gapResults.count) hits in \(Self.cyclesPerTrial) cycles")

            observers.forEach { observer in
                observer.continuousRhythmMatchingCompleted(trial)
            }
        } else {
            logger.info("Trial completed with no hits — skipping")
        }

        gapResults = []
        cyclesInCurrentTrial = 0
    }

    private func stopAll() {
        logger.info("Stopping continuous rhythm matching session")

        startTask?.cancel()
        startTask = nil
        trackingTask?.cancel()
        trackingTask = nil
        midiListeningTask?.cancel()
        midiListeningTask = nil
        lifecycle?.cancelFeedbackTask()

        Task {
            try? await stepSequencer.stop()
        }

        currentStep = nil
        currentGapPosition = nil
        cyclesInCurrentTrial = 0
        showFeedback = false
        lastHitOffsetMs = nil
        gapResults = []
        gapPositions = []
        hitCycleIndices = []
        settings = nil
        lastEvaluatedCycleIndex = -1
    }
}

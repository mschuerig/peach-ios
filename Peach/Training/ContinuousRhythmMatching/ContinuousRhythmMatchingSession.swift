import Foundation
import Observation
import os

enum ContinuousRhythmMatchingSessionState {
    case idle
    case running
}

@Observable
final class ContinuousRhythmMatchingSession: TrainingSession, BeatProvider {

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
        case playTapSound(BeatPosition)
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

    private static let subdivisionsPerBeat: Int64 = 4

    /// Polling interval for real-time cycle tracking (~120 Hz, matching the beat sequencer).
    private static let trackingPollingInterval: Duration = .milliseconds(8)

    /// Brief feedback flash duration for gap hits (shorter than discrete mode's 400ms).
    static let feedbackDuration: Duration = .milliseconds(200)

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ContinuousRhythmMatchingSession")

    // MARK: - Observable State

    private(set) var state: ContinuousRhythmMatchingSessionState = .idle
    private(set) var currentBeatPosition: BeatPosition?
    private(set) var gapPositionInCurrentBeat: BeatPosition?
    private(set) var cyclesInCurrentTrial = 0
    private(set) var lastTrialResult: CompletedContinuousRhythmMatchingTrial?
    private(set) var lastHitOffsetMs: Double?
    private(set) var showFeedback = false

    var isRunning: Bool { state == .running }

    // MARK: - Dependencies

    private let beatSequencer: any BeatSequencer
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

    /// Indexed by cycle number.
    private var gapPositions: [BeatPosition] = []

    /// Last index published to `currentBeatPosition` / `gapPositionInCurrentBeat`,
    /// gating Observation churn at the 120 Hz tracking rate.
    private var lastPublishedSubdivisionIndex: Int = -1
    private var lastPublishedCycleIndex: Int = -1

    // MARK: - Initialization

    init(
        beatSequencer: any BeatSequencer,
        observers: [ContinuousRhythmMatchingObserver] = [],
        midiInput: (any MIDIInput)? = nil,
        notificationCenter: NotificationCenter = .default,
        audioInterruptionObserver: AudioInterruptionObserving,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil
    ) {
        self.beatSequencer = beatSequencer
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
        self.lastPublishedSubdivisionIndex = -1
        self.lastPublishedCycleIndex = -1
        self.lastTrialResult = nil

        logger.info("Starting continuous rhythm matching at \(settings.tempo.value) BPM")
        send(.startRequested(settings))
    }

    func handleTap(atSamplePosition overrideSamplePosition: Int64? = nil) {
        let timing = beatSequencer.timing
        let samplePosition = overrideSamplePosition ?? timing.samplePosition

        guard state == .running else {
            logger.debug("handleTap() called but not running")
            return
        }

        guard samplePosition >= 0,
              timing.samplesPerBeat > 0 else { return }

        let samplesPerSubdivision = timing.samplesPerBeat / Self.subdivisionsPerBeat
        guard samplesPerSubdivision > 0 else { return }

        let playingCycleIndex = Int(samplePosition / timing.samplesPerBeat)
        guard playingCycleIndex < gapPositions.count else { return }
        guard !hitCycleIndices.contains(playingCycleIndex) else { return }

        let gapPosition = gapPositions[playingCycleIndex]
        let gapSampleOffset = Int64(playingCycleIndex) * timing.samplesPerBeat
            + Int64(gapPosition.rawValue) * samplesPerSubdivision
        let windowHalfSamples = samplesPerSubdivision / 2

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

    // MARK: - BeatProvider Protocol

    func nextBeat() -> Beat {
        guard state == .running,
              let settings,
              let gapPosition = settings.enabledGapPositions.randomElement() else {
            return Self.beat(withGapAt: .fourth)
        }
        gapPositions.append(gapPosition)
        return Self.beat(withGapAt: gapPosition)
    }

    /// Builds a flat 4-subdivision beat with one rest at `gap` and accent on beat one.
    /// Canonical source of CRM's beat shape — referenced by tests and the lifecycle mock.
    static func beat(withGapAt gap: BeatPosition) -> Beat {
        let subdivisions: [Subdivision] = BeatPosition.allCases.map { position in
            if position == gap { return .rest }
            let velocity = position == .first ? RhythmVelocity.accent : RhythmVelocity.normal
            return .note(velocity: velocity, offset: .zero)
        }
        return Beat(subdivisions: subdivisions)
    }

    /// Evaluates completed cycles and advances the cycle counter.
    /// Visible for testing.
    func evaluatePlaybackPosition() {
        let timing = beatSequencer.timing
        guard state == .running,
              timing.samplePosition >= 0,
              timing.samplesPerBeat > 0 else { return }

        let samplesPerSubdivision = timing.samplesPerBeat / Self.subdivisionsPerBeat
        guard samplesPerSubdivision > 0 else { return }

        let playingCycleIndex = Int(timing.samplePosition / timing.samplesPerBeat)
        let globalSubdivisionIndex = Int(timing.samplePosition / samplesPerSubdivision)

        // Detect sequencer batch-refill wrap (~every 500 beats): `samplePosition`
        // resets to 0, jumping the derived indices backwards. Reset the
        // published-index trackers so post-wrap state computes cleanly and
        // `cycleMissed` keeps firing after the wrap point.
        if globalSubdivisionIndex < lastPublishedSubdivisionIndex {
            lastEvaluatedCycleIndex = -1
            lastPublishedCycleIndex = -1
            lastPublishedSubdivisionIndex = -1
        }

        if globalSubdivisionIndex != lastPublishedSubdivisionIndex {
            currentBeatPosition = BeatPosition(rawValue: globalSubdivisionIndex % Int(Self.subdivisionsPerBeat))
            lastPublishedSubdivisionIndex = globalSubdivisionIndex
        }

        if playingCycleIndex != lastPublishedCycleIndex,
           playingCycleIndex < gapPositions.count {
            gapPositionInCurrentBeat = gapPositions[playingCycleIndex]
            lastPublishedCycleIndex = playingCycleIndex
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
            let velocity = position == .first ? RhythmVelocity.accent : RhythmVelocity.normal
            do {
                try beatSequencer.playImmediateNote(velocity: velocity)
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
                try await beatSequencer.start(tempo: settings.tempo, beatProvider: self)
                send(.sequencerReady)
            } catch is CancellationError {
                logger.info("Session task cancelled")
            } catch {
                logger.error("Failed to start beat sequencer: \(error.localizedDescription)")
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
                    let samplePos = beatSequencer.samplePosition(forHostTime: timestamp)
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
            try? await beatSequencer.stop()
        }

        currentBeatPosition = nil
        gapPositionInCurrentBeat = nil
        cyclesInCurrentTrial = 0
        showFeedback = false
        lastHitOffsetMs = nil
        gapResults = []
        gapPositions = []
        hitCycleIndices = []
        settings = nil
        lastEvaluatedCycleIndex = -1
        lastPublishedSubdivisionIndex = -1
        lastPublishedCycleIndex = -1
    }
}

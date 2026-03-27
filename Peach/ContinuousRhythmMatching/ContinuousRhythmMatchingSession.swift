import Foundation
import Observation
import os

@Observable
final class ContinuousRhythmMatchingSession: TrainingSession, StepProvider {

    // MARK: - Constants

    static let cyclesPerTrial = 16

    /// Polling interval for real-time cycle tracking (~120 Hz, matching the step sequencer).
    private static let trackingPollingInterval: Duration = .milliseconds(8)

    /// Brief feedback flash duration for gap hits (shorter than discrete mode's 400ms).
    static let feedbackDuration: Duration = .milliseconds(200)

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ContinuousRhythmMatchingSession")

    // MARK: - Observable State

    private(set) var isRunning = false
    private(set) var currentStep: StepPosition?
    private(set) var currentGapPosition: StepPosition?
    private(set) var cyclesInCurrentTrial = 0
    private(set) var lastTrialResult: CompletedContinuousRhythmMatchingTrial?
    private(set) var lastHitOffsetMs: Double?
    private(set) var showFeedback = false

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
        notificationCenter: NotificationCenter = .default
    ) {
        self.stepSequencer = stepSequencer
        self.midiInput = midiInput
        self.observers = observers
        self.lifecycle = SessionLifecycle(
            logger: logger,
            notificationCenter: notificationCenter,
            onStopRequired: { [weak self] in self?.stop() }
        )
    }

    // MARK: - TrainingSession Protocol

    var isIdle: Bool { !isRunning }

    func stop() {
        guard isRunning else {
            logger.debug("stop() called but already idle")
            return
        }

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

        isRunning = false
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

    // MARK: - Public API

    func start(settings: ContinuousRhythmMatchingSettings) {
        guard !isRunning else {
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
        self.isRunning = true

        logger.info("Starting continuous rhythm matching at \(settings.tempo.value) BPM")

        startMIDIListening()

        startTask = Task {
            do {
                try await stepSequencer.start(tempo: settings.tempo, stepProvider: self)
                startTrackingLoop()
            } catch is CancellationError {
                logger.info("Session task cancelled")
            } catch {
                logger.error("Failed to start step sequencer: \(error.localizedDescription)")
                stop()
            }
        }
    }

    func handleTap(atSamplePosition overrideSamplePosition: Int64? = nil) {
        let timing = stepSequencer.timing
        let samplePosition = overrideSamplePosition ?? timing.samplePosition

        guard isRunning else {
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
            let rhythmOffset = RhythmOffset(.seconds(offset))
            hitCycleIndices.insert(playingCycleIndex)

            let velocity = gapPosition == .first ? StepVelocity.accent : StepVelocity.normal
            do {
                try stepSequencer.playImmediateNote(velocity: velocity)
            } catch {
                logger.warning("Failed to play tap note: \(error.localizedDescription)")
            }

            recordGapResult(GapResult(position: gapPosition, offset: rhythmOffset))
            advanceCycleCount()
            showHitFeedback(rhythmOffset)
            logger.debug("Gap hit at offset \(offset * 1000, format: .fixed(precision: 1))ms")
        }
    }

    // MARK: - StepProvider Protocol

    func nextCycle() -> CycleDefinition {
        guard isRunning, let settings else {
            return CycleDefinition(gapPosition: .fourth)
        }

        let enabledPositions = settings.enabledGapPositions
        let selectedPosition: StepPosition
        if enabledPositions.count == 1 {
            selectedPosition = enabledPositions.first!
        } else {
            selectedPosition = enabledPositions.randomElement()!
        }

        gapPositions.append(selectedPosition)
        return CycleDefinition(gapPosition: selectedPosition)
    }

    // MARK: - MIDI Listening

    /// Iterates the MIDI input stream and routes note-on events to `handleTap`.
    /// The stream lives for the adapter's lifetime (not tied to device connection),
    /// so this task only ends on cancellation or adapter deallocation.
    private func startMIDIListening() {
        guard let midiInput else { return }
        midiListeningTask = Task {
            for await event in midiInput.events {
                guard !Task.isCancelled, isRunning else { break }
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

    // MARK: - Real-Time Tracking

    private func startTrackingLoop() {
        trackingTask = Task {
            while !Task.isCancelled {
                evaluatePlaybackPosition()
                try? await Task.sleep(for: Self.trackingPollingInterval)
            }
        }
    }

    /// Evaluates completed cycles and advances the cycle counter.
    /// Visible for testing.
    func evaluatePlaybackPosition() {
        let timing = stepSequencer.timing
        guard isRunning,
              timing.samplePosition >= 0,
              timing.samplesPerStep > 0,
              timing.samplesPerCycle > 0 else { return }

        let playingCycleIndex = Int(timing.samplePosition / timing.samplesPerCycle)

        // Update observable step position
        let globalStepIndex = Int(timing.samplePosition / timing.samplesPerStep)
        currentStep = StepPosition(rawValue: globalStepIndex % 4)

        // Update observable gap position for the currently-playing cycle
        if playingCycleIndex < gapPositions.count {
            currentGapPosition = gapPositions[playingCycleIndex]
        }

        // Advance past completed cycles — each missed one counts toward the trial limit.
        // Hit cycles are already counted immediately in handleTap, so skip them here.
        while lastEvaluatedCycleIndex < playingCycleIndex - 1 {
            lastEvaluatedCycleIndex += 1
            if !hitCycleIndices.contains(lastEvaluatedCycleIndex) {
                advanceCycleCount()
            }
        }
    }

    // MARK: - Feedback

    private func showHitFeedback(_ offset: RhythmOffset) {
        lastHitOffsetMs = offset.duration.timeInterval * 1000.0
        showFeedback = true

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: Self.feedbackDuration)
            guard isRunning, !Task.isCancelled else { return }
            showFeedback = false
        })
    }

    // MARK: - Private Implementation

    func recordGapResult(_ result: GapResult) {
        gapResults.append(result)
    }

    /// Called from `evaluatePlaybackPosition` when enough cycles have elapsed, or
    /// when a hit pushes past the cycle limit.
    private func advanceCycleCount() {
        cyclesInCurrentTrial += 1
        if cyclesInCurrentTrial >= Self.cyclesPerTrial {
            completeTrial()
        }
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
}

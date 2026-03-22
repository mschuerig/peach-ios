import Foundation
import Observation
import os
import QuartzCore

@Observable
final class ContinuousRhythmMatchingSession: TrainingSession, StepProvider {

    // MARK: - Constants

    private static let cyclesPerTrial = 16

    /// Polling interval for real-time cycle tracking (~120 Hz, matching the step sequencer).
    private static let trackingPollingInterval: Duration = .milliseconds(8)

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ContinuousRhythmMatchingSession")

    // MARK: - Observable State

    private(set) var isRunning = false
    private(set) var currentStep: StepPosition?
    private(set) var currentGapPosition: StepPosition?
    private(set) var cyclesInCurrentTrial = 0
    private(set) var lastTrialResult: CompletedContinuousRhythmMatchingTrial?

    // MARK: - Dependencies

    private let stepSequencer: any StepSequencer
    private let observers: [ContinuousRhythmMatchingObserver]
    private let currentTime: () -> Double
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Training State

    private var settings: ContinuousRhythmMatchingSettings?
    private var gapResults: [GapResult] = []
    private var sequencerStartTime: Double = 0
    private var sixteenthDuration: Double = 0
    private var cycleDuration: Double = 0
    private var lastEvaluatedCycleIndex: Int = -1
    private var hitCycleIndices: Set<Int> = []
    private var startTask: Task<Void, Never>?
    private var trackingTask: Task<Void, Never>?

    /// Gap positions indexed by cycle number, populated by nextCycle() during batch scheduling.
    private var gapPositions: [StepPosition] = []

    // MARK: - Initialization

    init(
        stepSequencer: any StepSequencer,
        observers: [ContinuousRhythmMatchingObserver] = [],
        notificationCenter: NotificationCenter = .default,
        currentTime: @escaping () -> Double = { CACurrentMediaTime() }
    ) {
        self.stepSequencer = stepSequencer
        self.observers = observers
        self.currentTime = currentTime
        self.interruptionMonitor = AudioSessionInterruptionMonitor(
            notificationCenter: notificationCenter,
            logger: logger,
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

        Task {
            try? await stepSequencer.stop()
        }

        isRunning = false
        currentStep = nil
        currentGapPosition = nil
        cyclesInCurrentTrial = 0
        gapResults = []
        gapPositions = []
        hitCycleIndices = []
        settings = nil
        sequencerStartTime = 0
        sixteenthDuration = 0
        cycleDuration = 0
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
        self.sixteenthDuration = settings.tempo.sixteenthNoteDuration.timeInterval
        self.cycleDuration = sixteenthDuration * 4.0
        self.isRunning = true

        logger.info("Starting continuous rhythm matching at \(settings.tempo.value) BPM")

        startTask = Task {
            do {
                try await stepSequencer.start(tempo: settings.tempo, stepProvider: self)
                sequencerStartTime = currentTime()
                startTrackingLoop()
            } catch is CancellationError {
                logger.info("Session task cancelled")
            } catch {
                logger.error("Failed to start step sequencer: \(error.localizedDescription)")
                stop()
            }
        }
    }

    func handleTap() {
        let tapTime = currentTime()

        guard isRunning else {
            logger.debug("handleTap() called but not running")
            return
        }

        let elapsed = tapTime - sequencerStartTime
        guard elapsed >= 0, cycleDuration > 0 else { return }

        let playingCycleIndex = Int(elapsed / cycleDuration)
        guard playingCycleIndex < gapPositions.count else { return }
        guard !hitCycleIndices.contains(playingCycleIndex) else { return }

        let gapPosition = gapPositions[playingCycleIndex]
        let gapTime = sequencerStartTime
            + Double(playingCycleIndex * 4 + gapPosition.rawValue) * sixteenthDuration
        let windowHalf = sixteenthDuration * 0.5

        let offset = tapTime - gapTime

        if abs(offset) <= windowHalf {
            let rhythmOffset = RhythmOffset(.seconds(offset))
            hitCycleIndices.insert(playingCycleIndex)
            recordGapResult(GapResult(position: gapPosition, offset: rhythmOffset))
            logger.debug("Gap hit at offset \(offset * 1000, format: .fixed(precision: 1))ms")
        }
    }

    // MARK: - StepProvider Protocol

    func nextCycle() -> CycleDefinition {
        guard isRunning, let settings else {
            let fallback = StepPosition.fourth
            gapPositions.append(fallback)
            return CycleDefinition(gapPosition: fallback)
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

    // MARK: - Real-Time Tracking

    private func startTrackingLoop() {
        trackingTask = Task {
            while !Task.isCancelled {
                evaluatePlaybackPosition()
                try? await Task.sleep(for: Self.trackingPollingInterval)
            }
        }
    }

    /// Evaluates completed cycles and records misses for gaps that were not tapped.
    /// Visible for testing.
    func evaluatePlaybackPosition() {
        guard isRunning, cycleDuration > 0 else { return }

        let now = currentTime()
        let elapsed = now - sequencerStartTime
        guard elapsed >= 0 else { return }

        let playingCycleIndex = Int(elapsed / cycleDuration)

        // Update observable step position
        let globalStepIndex = Int(elapsed / sixteenthDuration)
        currentStep = StepPosition(rawValue: globalStepIndex % 4)

        // Update observable gap position for the currently-playing cycle
        if playingCycleIndex < gapPositions.count {
            currentGapPosition = gapPositions[playingCycleIndex]
        }

        // Evaluate completed cycles — all before the currently-playing one
        while lastEvaluatedCycleIndex < playingCycleIndex - 1 {
            let cycleToEvaluate = lastEvaluatedCycleIndex + 1

            if cycleToEvaluate < gapPositions.count
                && !hitCycleIndices.contains(cycleToEvaluate) {
                let missPosition = gapPositions[cycleToEvaluate]
                recordGapResult(GapResult(position: missPosition, offset: nil))
                logger.debug("Gap missed at position \(String(describing: missPosition))")
            }

            lastEvaluatedCycleIndex = cycleToEvaluate
        }
    }

    // MARK: - Private Implementation

    func recordGapResult(_ result: GapResult) {
        gapResults.append(result)
        cyclesInCurrentTrial = gapResults.count

        if gapResults.count >= Self.cyclesPerTrial {
            completeTrial()
        }
    }

    private func completeTrial() {
        guard let settings else { return }

        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: settings.tempo,
            gapResults: gapResults
        )

        lastTrialResult = trial
        logger.info("Trial completed: \(trial.gapResults.filter(\.isHit).count)/\(trial.gapResults.count) hits")

        observers.forEach { observer in
            observer.continuousRhythmMatchingCompleted(trial)
        }

        gapResults = []
        cyclesInCurrentTrial = 0
    }
}

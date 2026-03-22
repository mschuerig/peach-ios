import Foundation
import Observation
import os
import QuartzCore

@Observable
final class ContinuousRhythmMatchingSession: TrainingSession, StepProvider {

    // MARK: - Constants

    private static let cyclesPerTrial = 16

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ContinuousRhythmMatchingSession")

    // MARK: - Observable State

    private(set) var isRunning = false
    private(set) var currentGapPosition: StepPosition?
    private(set) var cyclesInCurrentTrial = 0
    private(set) var lastTrialResult: CompletedContinuousRhythmMatchingTrial?

    // MARK: - Dependencies

    private let stepSequencer: any StepSequencer
    private let observers: [ContinuousRhythmMatchingObserver]
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Training State

    private var settings: ContinuousRhythmMatchingSettings?
    private var gapResults: [GapResult] = []
    private var sequencerStartTime: Double = 0
    private var currentCycleIndex: Int = 0
    private var currentGapHit: Bool = false
    private var evaluationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        stepSequencer: any StepSequencer,
        observers: [ContinuousRhythmMatchingObserver] = [],
        notificationCenter: NotificationCenter = .default
    ) {
        self.stepSequencer = stepSequencer
        self.observers = observers
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

        evaluationTask?.cancel()
        evaluationTask = nil

        Task {
            try? await stepSequencer.stop()
        }

        isRunning = false
        currentGapPosition = nil
        cyclesInCurrentTrial = 0
        gapResults = []
        settings = nil
        sequencerStartTime = 0
        currentCycleIndex = 0
        currentGapHit = false
    }

    // MARK: - Public API

    func start(settings: ContinuousRhythmMatchingSettings) {
        guard !isRunning else {
            logger.warning("start() called but already running")
            return
        }

        self.settings = settings
        self.gapResults = []
        self.cyclesInCurrentTrial = 0
        self.currentCycleIndex = 0
        self.currentGapHit = false
        self.lastTrialResult = nil
        self.isRunning = true

        logger.info("Starting continuous rhythm matching at \(settings.tempo.value) BPM")

        evaluationTask = Task {
            do {
                sequencerStartTime = CACurrentMediaTime()
                try await stepSequencer.start(tempo: settings.tempo, stepProvider: self)
            } catch is CancellationError {
                logger.info("Session task cancelled")
            } catch {
                logger.error("Failed to start step sequencer: \(error.localizedDescription)")
                stop()
            }
        }
    }

    func handleTap() {
        let tapTime = CACurrentMediaTime()

        guard isRunning, let settings else {
            logger.debug("handleTap() called but not running")
            return
        }

        guard !currentGapHit else {
            return
        }

        let sixteenthDuration = settings.tempo.sixteenthNoteDuration.timeInterval
        guard let gapPosition = currentGapPosition else { return }

        let gapTime = sequencerStartTime
            + Double(currentCycleIndex * 4 + gapPosition.rawValue) * sixteenthDuration
        let windowHalf = sixteenthDuration * 0.5

        let offset = tapTime - gapTime

        if abs(offset) <= windowHalf {
            let rhythmOffset = RhythmOffset(.seconds(offset))
            currentGapHit = true
            recordGapResult(GapResult(position: gapPosition, offset: rhythmOffset))
            logger.debug("Gap hit at offset \(offset * 1000, format: .fixed(precision: 1))ms")
        }
    }

    // MARK: - StepProvider Protocol

    func nextCycle() -> CycleDefinition {
        if currentCycleIndex > 0 && !currentGapHit {
            let missPosition = currentGapPosition ?? .fourth
            recordGapResult(GapResult(position: missPosition, offset: nil))
            logger.debug("Gap missed at position \(String(describing: missPosition))")
        }

        let enabledPositions = settings?.enabledGapPositions ?? [.fourth]
        let selectedPosition: StepPosition
        if enabledPositions.count == 1 {
            selectedPosition = enabledPositions.first!
        } else {
            selectedPosition = enabledPositions.randomElement()!
        }

        currentGapPosition = selectedPosition
        currentGapHit = false
        currentCycleIndex += 1

        return CycleDefinition(gapPosition: selectedPosition)
    }

    // MARK: - Private Implementation

    private func recordGapResult(_ result: GapResult) {
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
        logger.info("Trial completed: hitRate=\(trial.hitRate, format: .fixed(precision: 2)), meanOffset=\(trial.meanOffsetMs, format: .fixed(precision: 1))ms")

        observers.forEach { observer in
            observer.continuousRhythmMatchingCompleted(trial)
        }

        gapResults = []
        cyclesInCurrentTrial = 0
    }
}

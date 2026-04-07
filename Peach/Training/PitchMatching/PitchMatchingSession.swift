import Foundation
import Observation
import os

enum PitchMatchingSessionState {
    case idle
    case playingReference
    case awaitingSliderTouch
    case playingTunable
    case showingFeedback
}

@Observable
final class PitchMatchingSession: TrainingSession {

    // MARK: - State Machine Types

    enum Event {
        case startRequested
        case referenceNoteFinished
        case sliderTouched
        case pitchCommitted(userFrequency: Frequency)
        case feedbackTimerFired
        case stopRequested
        case audioError
    }

    enum Effect {
        case beginNextTrial
        case startTunablePlayback
        case stopPlayback
        case evaluateResult(userFrequency: Frequency)
        case scheduleFeedbackTimer
        case stopAll
    }

    /// Pure state transition function.
    static func reduce(state: inout PitchMatchingSessionState, event: Event) -> [Effect] {
        switch (state, event) {
        case (.idle, .startRequested):
            state = .playingReference
            return [.beginNextTrial]

        case (.playingReference, .referenceNoteFinished):
            state = .awaitingSliderTouch
            return []

        case (.awaitingSliderTouch, .sliderTouched):
            state = .playingTunable
            return [.startTunablePlayback]

        case (.awaitingSliderTouch, .pitchCommitted(let freq)):
            state = .showingFeedback
            return [.evaluateResult(userFrequency: freq), .scheduleFeedbackTimer]

        case (.playingTunable, .pitchCommitted(let freq)):
            state = .showingFeedback
            return [.stopPlayback, .evaluateResult(userFrequency: freq), .scheduleFeedbackTimer]

        case (.showingFeedback, .feedbackTimerFired):
            state = .playingReference
            return [.beginNextTrial]

        case (.idle, .stopRequested):
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

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchMatchingSession")

    // MARK: - Observable State

    private(set) var state: PitchMatchingSessionState = .idle
    private(set) var currentTrial: PitchMatchingTrial?
    private(set) var lastResult: CompletedPitchMatchingTrial?
    private(set) var sessionBestCentError: Cents?

    // MARK: - Dependencies

    private let notePlayer: NotePlayer
    private let profile: TrainingProfile
    private let observers: [PitchMatchingObserver]
    private let midiInput: (any MIDIInput)?
    private var lifecycle: SessionLifecycle?

    // MARK: - Settings

    private var settings: PitchMatchingSettings?

    var sessionTuningSystem: TuningSystem {
        settings?.tuningSystem ?? .equalTemperament
    }

    // MARK: - Interval State

    private(set) var currentInterval: DirectedInterval? = nil
    var isIntervalMode: Bool {
        guard let current = currentInterval else { return false }
        return current.interval != .prime
    }

    // MARK: - Keyboard / Slider State

    /// Tracks the current pitch slider value from all input sources (touch, keyboard, MIDI).
    private(set) var currentPitchValue: Double = 0.0

    /// When non-nil, drives the PitchSlider thumb externally (keyboard arrows).
    /// Cleared when touch input begins; reset to center on new trial.
    private(set) var keyboardPitchValue: Double?

    /// Fine pitch adjustment step for keyboard arrow keys (~1 cent at ±20 cent range).
    private static let finePitchStep: Double = 0.05

    // MARK: - MIDI State

    private var midiListeningTask: Task<Void, Never>?
    private var hasBeenDeflected = false
    private(set) var midiPitchBendValue: Double?

    // MARK: - Internal State

    private var currentHandle: PlaybackHandle?
    private(set) var referenceFrequency: Frequency?

    // MARK: - Initialization

    init(
        notePlayer: NotePlayer,
        profile: TrainingProfile,
        observers: [PitchMatchingObserver] = [],
        midiInput: (any MIDIInput)? = nil,
        notificationCenter: NotificationCenter = .default,
        audioInterruptionObserver: AudioInterruptionObserving,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil
    ) {
        self.notePlayer = notePlayer
        self.profile = profile
        self.observers = observers
        self.midiInput = midiInput

        self.lifecycle = SessionLifecycle(
            logger: logger,
            notificationCenter: notificationCenter,
            audioInterruptionObserver: audioInterruptionObserver,
            backgroundNotificationName: backgroundNotificationName,
            foregroundNotificationName: foregroundNotificationName,
            onStopRequired: { [weak self] in self?.stop() }
        )
    }

    // MARK: - Public API

    var isIdle: Bool { state == .idle }

    func start(settings: PitchMatchingSettings) {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }
        precondition(!settings.intervals.isEmpty, "intervals must not be empty")
        self.settings = settings
        logger.info("Starting training loop")
        startMIDIListening()
        send(.startRequested)
    }

    var canAdjustPitch: Bool { state == .awaitingSliderTouch || state == .playingTunable }

    func adjustPitch(_ value: Double) {
        currentPitchValue = value
        if state == .awaitingSliderTouch {
            send(.sliderTouched)
        }
        guard state == .playingTunable, let frequency = sliderFrequency(for: value) else { return }
        Task {
            try? await currentHandle?.adjustFrequency(frequency)
        }
    }

    func commitPitch(_ value: Double) {
        currentPitchValue = value
        guard let frequency = sliderFrequency(for: value) else { return }
        guard state == .awaitingSliderTouch || state == .playingTunable else { return }
        send(.pitchCommitted(userFrequency: frequency))
    }

    /// Adjusts pitch by one fine step in the given direction. Returns `true` if accepted.
    @discardableResult
    func adjustPitchByStep(up: Bool) -> Bool {
        guard canAdjustPitch else { return false }
        if up {
            currentPitchValue = min(currentPitchValue + Self.finePitchStep, 1.0)
        } else {
            currentPitchValue = max(currentPitchValue - Self.finePitchStep, -1.0)
        }
        keyboardPitchValue = currentPitchValue
        adjustPitch(currentPitchValue)
        return true
    }

    /// Commits the current pitch value. Returns `true` if accepted.
    @discardableResult
    func commitCurrentPitch() -> Bool {
        guard state == .playingTunable else { return false }
        keyboardPitchValue = nil
        commitPitch(currentPitchValue)
        return true
    }

    /// Called by the view when touch begins on the slider, clearing keyboard external value.
    func clearKeyboardPitchValue() {
        keyboardPitchValue = nil
    }

    func stop() {
        send(.stopRequested)
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

        case .startTunablePlayback:
            startTunablePlayback()

        case .stopPlayback:
            let handleToStop = currentHandle
            currentHandle = nil
            if let handleToStop {
                Task {
                    try? await handleToStop.stop()
                }
            }

        case .evaluateResult(let userFrequency):
            evaluateResult(userFrequency: userFrequency)

        case .scheduleFeedbackTimer:
            scheduleFeedbackTimer()

        case .stopAll:
            stopAll()
        }
    }

    // MARK: - Effect Implementations

    private func beginNextTrial() {
        guard let settings else { return }

        hasBeenDeflected = false
        midiPitchBendValue = nil
        currentPitchValue = 0.0
        keyboardPitchValue = 0

        guard let interval = settings.intervals.randomElement() else { return }
        currentInterval = interval
        let trial = generateTrial(settings: settings, interval: interval)
        currentTrial = trial

        let refFreq = settings.tuningSystem.frequency(
            for: trial.referenceNote, referencePitch: settings.referencePitch)
        let targetFreq = settings.tuningSystem.frequency(
            for: trial.targetNote, referencePitch: settings.referencePitch)
        self.referenceFrequency = targetFreq
        logger.info("Trial: ref=\(trial.referenceNote.rawValue) \(refFreq.rawValue)Hz, target=\(trial.targetNote.rawValue) \(targetFreq.rawValue)Hz, initialOffset=\(trial.initialCentOffset.rawValue)cents")

        lifecycle?.setTrainingTask(Task {
            do {
                try await notePlayer.play(
                    frequency: refFreq,
                    duration: .seconds(settings.noteDuration.rawValue),
                    velocity: settings.velocity,
                    amplitudeDB: AmplitudeDB(0.0)
                )

                guard state != .idle && !Task.isCancelled else { return }
                send(.referenceNoteFinished)
            } catch is CancellationError {
                logger.info("Training cancelled")
            } catch {
                logger.error("Audio error during reference note: \(error.localizedDescription)")
                send(.audioError)
            }
        })
    }

    private func startTunablePlayback() {
        guard let settings, let trial = currentTrial else { return }

        let tunableAmplitude = calculateTargetAmplitude()
        let tunableFrequency = settings.tuningSystem.frequency(
            for: DetunedMIDINote(note: trial.targetNote, offset: trial.initialCentOffset),
            referencePitch: settings.referencePitch)

        lifecycle?.setTrainingTask(Task {
            do {
                let handle = try await notePlayer.play(
                    frequency: tunableFrequency,
                    velocity: settings.velocity,
                    amplitudeDB: tunableAmplitude
                )

                guard state != .idle && !Task.isCancelled else {
                    Task { try? await handle.stop() }
                    return
                }

                currentHandle = handle
            } catch is CancellationError {
                logger.info("Training cancelled")
            } catch {
                logger.error("Audio error during tunable note: \(error.localizedDescription)")
                send(.audioError)
            }
        })
    }

    private func evaluateResult(userFrequency: Frequency) {
        guard let trial = currentTrial else { return }
        guard let referenceFrequency else { return }

        let userCentError = log2(userFrequency / referenceFrequency) * Cents.perOctave
        logger.info("Result: ref=\(trial.referenceNote.rawValue), target=\(trial.targetNote.rawValue), initialOffset=\(trial.initialCentOffset.rawValue)cents, userCentError=\(userCentError.rawValue)cents")

        let result = CompletedPitchMatchingTrial(
            referenceNote: trial.referenceNote,
            targetNote: trial.targetNote,
            initialCentOffset: trial.initialCentOffset,
            userCentError: userCentError,
            tuningSystem: sessionTuningSystem
        )
        lastResult = result
        trackSessionBest(Cents(userCentError.magnitude))

        observers.forEach { $0.pitchMatchingCompleted(result) }
    }

    private func scheduleFeedbackTimer() {
        guard let settings else { return }

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            guard state == .showingFeedback, !Task.isCancelled else { return }
            send(.feedbackTimerFired)
        })
    }

    private func stopAll() {
        logger.info("Session stopped")

        Task {
            try? await notePlayer.stopAll()
        }
        lifecycle?.cancelAllTasks()
        midiListeningTask?.cancel()
        midiListeningTask = nil
        hasBeenDeflected = false
        midiPitchBendValue = nil
        currentPitchValue = 0.0
        keyboardPitchValue = nil
        let handleToStop = currentHandle
        currentHandle = nil
        referenceFrequency = nil
        currentTrial = nil
        lastResult = nil
        sessionBestCentError = nil
        currentInterval = nil
        settings = nil
        Task {
            try? await handleToStop?.stop()
        }
    }

    // MARK: - Private Helpers

    private func sliderFrequency(for value: Double) -> Frequency? {
        guard let referenceFrequency, let trial = currentTrial, let settings else { return nil }
        let centOffset = trial.initialCentOffset + value * settings.initialCentOffsetRange.upperBound
        return referenceFrequency * pow(2.0, centOffset / Cents.perOctave)
    }

    private func generateTrial(settings: PitchMatchingSettings, interval: DirectedInterval) -> PitchMatchingTrial {
        let minNote: MIDINote
        let maxNote: MIDINote
        if interval.direction == .up {
            minNote = settings.noteRange.lowerBound
            maxNote = MIDINote(min(settings.noteRange.upperBound.rawValue, MIDINote.validRange.upperBound - interval.interval.semitones))
        } else {
            minNote = MIDINote(max(settings.noteRange.lowerBound.rawValue, MIDINote.validRange.lowerBound + interval.interval.semitones))
            maxNote = settings.noteRange.upperBound
        }
        let note = MIDINote.random(in: minNote...maxNote)
        let targetNote = note.transposed(by: interval)
        let offset = Cents(Double.random(in: settings.initialCentOffsetRange.lowerBound.rawValue...settings.initialCentOffsetRange.upperBound.rawValue))
        return PitchMatchingTrial(referenceNote: note, targetNote: targetNote, initialCentOffset: offset)
    }

    private func trackSessionBest(_ absCentError: Cents) {
        if let best = sessionBestCentError {
            if absCentError < best { sessionBestCentError = absCentError }
        } else {
            sessionBestCentError = absCentError
        }
    }

    private func calculateTargetAmplitude() -> AmplitudeDB {
        guard let settings else { return AmplitudeDB(0.0) }
        let varyLoudness = settings.varyLoudness.rawValue
        guard varyLoudness > 0.0 else { return AmplitudeDB(0.0) }
        let range = varyLoudness * settings.maxLoudnessOffsetDB.rawValue
        let offset = Double.random(in: -range...range)
        return AmplitudeDB(offset)
    }

    // MARK: - MIDI Listening

    private func startMIDIListening() {
        guard let midiInput else { return }
        midiListeningTask = Task {
            for await event in midiInput.events {
                guard !Task.isCancelled else { break }
                switch event {
                case .pitchBend(let value, _, _):
                    let normalized = value.normalizedSliderValue
                    handlePitchBendInput(value: value, normalized: normalized)
                case .noteOn, .noteOff:
                    break
                }
            }
        }
    }

    private func handlePitchBendInput(value: PitchBendValue, normalized: Double) {
        guard state == .awaitingSliderTouch || state == .playingTunable else { return }

        midiPitchBendValue = normalized

        if !value.isInNeutralZone {
            hasBeenDeflected = true
        }

        if state == .awaitingSliderTouch {
            adjustPitch(normalized)
            return
        }

        if value.isInNeutralZone && hasBeenDeflected {
            commitPitch(normalized)
            hasBeenDeflected = false
            midiPitchBendValue = nil
        } else {
            adjustPitch(normalized)
        }
    }
}

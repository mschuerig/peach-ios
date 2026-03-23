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

    // MARK: - Internal State

    private var currentHandle: PlaybackHandle?
    private(set) var referenceFrequency: Frequency?
    private var pendingTunableFrequency: Frequency?
    private var sliderTouchContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Initialization

    init(
        notePlayer: NotePlayer,
        profile: TrainingProfile,
        observers: [PitchMatchingObserver] = [],
        notificationCenter: NotificationCenter = .default,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil
    ) {
        self.notePlayer = notePlayer
        self.profile = profile
        self.observers = observers

        self.lifecycle = SessionLifecycle(
            logger: logger,
            notificationCenter: notificationCenter,
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

        lifecycle?.setTrainingTask(Task {
            await playNextTrial()
        })
    }

    func adjustPitch(_ value: Double) {
        if state == .awaitingSliderTouch {
            state = .playingTunable
            sliderTouchContinuation?.resume()
            sliderTouchContinuation = nil
            return
        }
        guard state == .playingTunable, let frequency = sliderFrequency(for: value) else { return }
        Task {
            try? await currentHandle?.adjustFrequency(Frequency(frequency))
        }
    }

    func commitPitch(_ value: Double) {
        if state == .awaitingSliderTouch {
            state = .playingTunable
            pendingTunableFrequency = nil
            sliderTouchContinuation?.resume()
            sliderTouchContinuation = nil
        }
        guard state == .playingTunable, let frequency = sliderFrequency(for: value) else { return }
        commitResult(userFrequency: frequency)
    }

    private func sliderFrequency(for value: Double) -> Double? {
        guard let referenceFrequency, let trial = currentTrial, let settings else { return nil }
        let centOffset = trial.initialCentOffset.rawValue + value * settings.initialCentOffsetRange.upperBound.rawValue
        return referenceFrequency.rawValue * pow(2.0, centOffset / Cents.perOctave)
    }

    private func commitResult(userFrequency: Double) {
        guard state == .playingTunable else { return }
        guard let trial = currentTrial, let settings else { return }

        let handleToStop = currentHandle
        currentHandle = nil
        Task {
            try? await handleToStop?.stop()
        }

        guard let referenceFrequency else { return }
        let userCentError = Cents(Cents.perOctave * log2(userFrequency / referenceFrequency.rawValue))
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

        state = .showingFeedback

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            guard !Task.isCancelled else { return }
            await playNextTrial()
        })
    }

    func stop() {
        guard state != .idle else {
            logger.debug("stop() called but already idle")
            return
        }
        logger.info("Session stopped (state was: \(String(describing: self.state)))")
        Task {
            try? await notePlayer.stopAll()
        }
        lifecycle?.cancelAllTasks()
        sliderTouchContinuation?.resume()
        sliderTouchContinuation = nil
        let handleToStop = currentHandle
        currentHandle = nil
        pendingTunableFrequency = nil
        referenceFrequency = nil
        currentTrial = nil
        lastResult = nil
        sessionBestCentError = nil
        currentInterval = nil
        settings = nil
        Task {
            try? await handleToStop?.stop()
        }
        state = .idle
    }

    // MARK: - Trial Generation

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

    // MARK: - Loudness Variation

    private func calculateTargetAmplitude() -> AmplitudeDB {
        guard let settings else { return AmplitudeDB(0.0) }
        let varyLoudness = settings.varyLoudness.rawValue
        guard varyLoudness > 0.0 else { return AmplitudeDB(0.0) }
        let range = varyLoudness * settings.maxLoudnessOffsetDB.rawValue
        let offset = Double.random(in: -range...range)
        return AmplitudeDB(offset)
    }

    // MARK: - Training Loop

    private func playNextTrial() async {
        guard let settings else { return }

        guard let interval = settings.intervals.randomElement() else { return }
        currentInterval = interval
        let trial = generateTrial(settings: settings, interval: interval)
        currentTrial = trial

        let tunableAmplitude = calculateTargetAmplitude()

        do {
            let refFreq = settings.tuningSystem.frequency(
                for: trial.referenceNote, referencePitch: settings.referencePitch)
            let targetFreq = settings.tuningSystem.frequency(
                for: trial.targetNote, referencePitch: settings.referencePitch)
            self.referenceFrequency = targetFreq
            logger.info("Trial: ref=\(trial.referenceNote.rawValue) \(refFreq.rawValue)Hz, target=\(trial.targetNote.rawValue) \(targetFreq.rawValue)Hz, initialOffset=\(trial.initialCentOffset.rawValue)cents")

            state = .playingReference
            try await notePlayer.play(
                frequency: refFreq,
                duration: .seconds(settings.noteDuration.rawValue),
                velocity: settings.velocity,
                amplitudeDB: AmplitudeDB(0.0)
            )

            guard state != .idle && !Task.isCancelled else { return }

            let tunableFrequency = settings.tuningSystem.frequency(
                for: DetunedMIDINote(note: trial.targetNote, offset: trial.initialCentOffset),
                referencePitch: settings.referencePitch)

            self.pendingTunableFrequency = tunableFrequency
            state = .awaitingSliderTouch

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.sliderTouchContinuation = continuation
            }

            guard !Task.isCancelled else { return }
            guard let tunableFreq = pendingTunableFrequency else { return }
            pendingTunableFrequency = nil
            guard state == .playingTunable else { return }

            let handle = try await notePlayer.play(
                frequency: tunableFreq,
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
        } catch let error as AudioError {
            logger.error("Audio error during pitch matching: \(error.localizedDescription)")
            stop()
        } catch {
            logger.error("Unexpected error during pitch matching: \(error.localizedDescription)")
            stop()
        }
    }
}

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
    private(set) var currentChallenge: PitchMatchingChallenge?
    private(set) var lastResult: CompletedPitchMatching?
    private(set) var sessionBestCentError: Cents?

    // MARK: - Dependencies

    private let notePlayer: NotePlayer
    private let profile: PitchMatchingProfile
    private let observers: [PitchMatchingObserver]
    private let userSettings: UserSettings
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Interval State

    private var sessionIntervals: Set<DirectedInterval> = []
    private(set) var sessionTuningSystem: TuningSystem = .equalTemperament
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
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    /// Maximum starting offset for pitch matching challenges.
    /// The tunable note begins at a random offset within this range.
    private static let initialCentOffsetRange: ClosedRange<Double> = -20.0...20.0
    private static var maxInitialCentOffset: Cents { Cents(initialCentOffsetRange.upperBound) }

    private let velocity: MIDIVelocity = TrainingConstants.velocity
    private let feedbackDuration: Duration = TrainingConstants.feedbackDuration

    // MARK: - Initialization

    init(
        notePlayer: NotePlayer,
        profile: PitchMatchingProfile,
        observers: [PitchMatchingObserver] = [],
        userSettings: UserSettings,
        notificationCenter: NotificationCenter = .default,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil
    ) {
        self.notePlayer = notePlayer
        self.profile = profile
        self.observers = observers
        self.userSettings = userSettings

        self.interruptionMonitor = AudioSessionInterruptionMonitor(
            notificationCenter: notificationCenter,
            logger: logger,
            backgroundNotificationName: backgroundNotificationName,
            foregroundNotificationName: foregroundNotificationName,
            onStopRequired: { [weak self] in self?.stop() }
        )
    }

    // MARK: - Public API

    var isIdle: Bool { state == .idle }

    func start(intervals: Set<DirectedInterval>) {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }

        precondition(!intervals.isEmpty, "intervals must not be empty")
        sessionIntervals = intervals
        sessionTuningSystem = userSettings.tuningSystem
        logger.info("Starting training loop")

        trainingTask = Task {
            await playNextChallenge()
        }
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
        guard let referenceFrequency, let challenge = currentChallenge else { return nil }
        let centOffset = challenge.initialCentOffset.rawValue + value * Self.initialCentOffsetRange.upperBound
        return referenceFrequency.rawValue * pow(2.0, centOffset / Cents.perOctave)
    }

    private func commitResult(userFrequency: Double) {
        guard state == .playingTunable else { return }
        guard let challenge = currentChallenge else { return }

        let handleToStop = currentHandle
        currentHandle = nil
        Task {
            try? await handleToStop?.stop()
        }

        guard let referenceFrequency else { return }
        let userCentError = Cents(Cents.perOctave * log2(userFrequency / referenceFrequency.rawValue))
        logger.info("Result: ref=\(challenge.referenceNote.rawValue), target=\(challenge.targetNote.rawValue), initialOffset=\(challenge.initialCentOffset.rawValue)cents, userCentError=\(userCentError.rawValue)cents")

        let result = CompletedPitchMatching(
            referenceNote: challenge.referenceNote,
            targetNote: challenge.targetNote,
            initialCentOffset: challenge.initialCentOffset,
            userCentError: userCentError,
            tuningSystem: sessionTuningSystem
        )
        lastResult = result
        trackSessionBest(Cents(userCentError.magnitude))

        observers.forEach { $0.pitchMatchingCompleted(result) }

        state = .showingFeedback

        feedbackTask = Task {
            try? await Task.sleep(for: feedbackDuration)
            guard !Task.isCancelled else { return }
            await playNextChallenge()
        }
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
        trainingTask?.cancel()
        trainingTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil
        sliderTouchContinuation?.resume()
        sliderTouchContinuation = nil
        let handleToStop = currentHandle
        currentHandle = nil
        pendingTunableFrequency = nil
        referenceFrequency = nil
        currentChallenge = nil
        lastResult = nil
        sessionBestCentError = nil
        currentInterval = nil
        sessionIntervals = []
        sessionTuningSystem = .equalTemperament
        Task {
            try? await handleToStop?.stop()
        }
        state = .idle
    }

    // MARK: - Configuration

    private var currentSettings: TrainingSettings {
        TrainingSettings(
            noteRange: userSettings.noteRange,
            referencePitch: userSettings.referencePitch
        )
    }

    private var currentNoteDuration: TimeInterval {
        userSettings.noteDuration.rawValue
    }

    // MARK: - Challenge Generation

    private func generateChallenge(settings: TrainingSettings, interval: DirectedInterval) -> PitchMatchingChallenge {
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
        let offset = Cents(Double.random(in: Self.initialCentOffsetRange))
        return PitchMatchingChallenge(referenceNote: note, targetNote: targetNote, initialCentOffset: offset)
    }

    private func trackSessionBest(_ absCentError: Cents) {
        if let best = sessionBestCentError {
            if absCentError < best { sessionBestCentError = absCentError }
        } else {
            sessionBestCentError = absCentError
        }
    }

    // MARK: - Training Loop

    private func playNextChallenge() async {
        let settings = currentSettings
        let noteDuration = currentNoteDuration
        let interval = sessionIntervals.randomElement()!
        currentInterval = interval
        let challenge = generateChallenge(settings: settings, interval: interval)
        currentChallenge = challenge

        do {
            let refFreq = sessionTuningSystem.frequency(
                for: challenge.referenceNote, referencePitch: settings.referencePitch)
            let targetFreq = sessionTuningSystem.frequency(
                for: challenge.targetNote, referencePitch: settings.referencePitch)
            self.referenceFrequency = targetFreq
            logger.info("Challenge: ref=\(challenge.referenceNote.rawValue) \(refFreq.rawValue)Hz, target=\(challenge.targetNote.rawValue) \(targetFreq.rawValue)Hz, initialOffset=\(challenge.initialCentOffset.rawValue)cents")

            state = .playingReference
            try await notePlayer.play(
                frequency: refFreq,
                duration: noteDuration,
                velocity: velocity,
                amplitudeDB: AmplitudeDB(0.0)
            )

            guard state != .idle && !Task.isCancelled else { return }

            let tunableFrequency = sessionTuningSystem.frequency(
                for: DetunedMIDINote(note: challenge.targetNote, offset: challenge.initialCentOffset),
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
                velocity: velocity,
                amplitudeDB: AmplitudeDB(0.0)
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

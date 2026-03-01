import Foundation
import Observation
import os

enum PitchMatchingSessionState {
    case idle
    case playingReference
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

    // MARK: - Dependencies

    private let notePlayer: NotePlayer
    private let profile: PitchMatchingProfile
    private let observers: [PitchMatchingObserver]
    private let userSettings: UserSettings
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Interval State

    private var sessionIntervals: Set<Interval> = []
    private var sessionTuningSystem: TuningSystem = .equalTemperament
    private(set) var currentInterval: Interval? = nil
    var isIntervalMode: Bool { currentInterval != nil && currentInterval != .prime }

    // MARK: - Internal State

    private var currentHandle: PlaybackHandle?
    private(set) var referenceFrequency: Double?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    private static let initialCentOffsetRange: ClosedRange<Double> = -100.0...100.0

    private let velocity: MIDIVelocity = 63
    private let feedbackDuration: TimeInterval = 0.4

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

    func start() {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }

        precondition(!userSettings.intervals.isEmpty, "intervals must not be empty")
        sessionIntervals = userSettings.intervals
        sessionTuningSystem = userSettings.tuningSystem

        trainingTask = Task {
            await playNextChallenge()
        }
    }

    func adjustPitch(_ value: Double) {
        guard state == .playingTunable, let referenceFrequency else { return }
        let centOffset = value * Self.initialCentOffsetRange.upperBound
        let frequency = referenceFrequency * pow(2.0, centOffset / 1200.0)
        Task {
            try? await currentHandle?.adjustFrequency(Frequency(frequency))
        }
    }

    func commitPitch(_ value: Double) {
        guard state == .playingTunable, let referenceFrequency else { return }
        let centOffset = value * Self.initialCentOffsetRange.upperBound
        let frequency = referenceFrequency * pow(2.0, centOffset / 1200.0)
        commitResult(userFrequency: frequency)
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
        let userCentError = 1200.0 * log2(userFrequency / referenceFrequency)

        let result = CompletedPitchMatching(
            referenceNote: challenge.referenceNote,
            targetNote: challenge.targetNote,
            initialCentOffset: challenge.initialCentOffset,
            userCentError: userCentError,
            tuningSystem: sessionTuningSystem
        )
        lastResult = result

        observers.forEach { $0.pitchMatchingCompleted(result) }

        state = .showingFeedback

        feedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(feedbackDuration * 1000)))
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
        let handleToStop = currentHandle
        currentHandle = nil
        referenceFrequency = nil
        currentChallenge = nil
        lastResult = nil
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
            noteRangeMin: userSettings.noteRangeMin,
            noteRangeMax: userSettings.noteRangeMax,
            referencePitch: userSettings.referencePitch
        )
    }

    private var currentNoteDuration: TimeInterval {
        userSettings.noteDuration.rawValue
    }

    // MARK: - Challenge Generation

    private func generateChallenge(settings: TrainingSettings, interval: Interval) -> PitchMatchingChallenge {
        let maxNote = MIDINote(min(settings.noteRangeMax.rawValue, 127 - interval.semitones))
        let note = MIDINote.random(in: settings.noteRangeMin...maxNote)
        let targetNote = note.transposed(by: interval)
        let offset = Double.random(in: Self.initialCentOffsetRange)
        return PitchMatchingChallenge(referenceNote: note, targetNote: targetNote, initialCentOffset: offset)
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
            self.referenceFrequency = targetFreq.rawValue

            state = .playingReference
            try await notePlayer.play(
                frequency: refFreq,
                duration: noteDuration,
                velocity: velocity,
                amplitudeDB: AmplitudeDB(0.0)
            )

            guard state != .idle && !Task.isCancelled else { return }

            let tunableFrequency = sessionTuningSystem.frequency(
                for: DetunedMIDINote(note: challenge.targetNote, offset: Cents(challenge.initialCentOffset)),
                referencePitch: settings.referencePitch)

            state = .playingTunable
            let handle = try await notePlayer.play(
                frequency: tunableFrequency,
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

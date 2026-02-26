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
final class PitchMatchingSession {

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
    private let settingsOverride: TrainingSettings?
    private let noteDurationOverride: TimeInterval?
    private let notificationCenter: NotificationCenter

    // MARK: - Internal State

    private var currentHandle: PlaybackHandle?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    private let velocity: UInt8 = 63
    private let feedbackDuration: TimeInterval = 0.4

    // MARK: - Initialization

    init(
        notePlayer: NotePlayer,
        profile: PitchMatchingProfile,
        observers: [PitchMatchingObserver] = [],
        settingsOverride: TrainingSettings? = nil,
        noteDurationOverride: TimeInterval? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.notePlayer = notePlayer
        self.profile = profile
        self.observers = observers
        self.settingsOverride = settingsOverride
        self.noteDurationOverride = noteDurationOverride
        self.notificationCenter = notificationCenter
    }

    // MARK: - Public API

    func startPitchMatching() {
        guard state == .idle else {
            logger.warning("startPitchMatching() called but state is \(String(describing: self.state)), not idle")
            return
        }
        trainingTask = Task {
            await playNextChallenge()
        }
    }

    func adjustFrequency(_ frequency: Double) {
        guard state == .playingTunable else { return }
        Task {
            try? await currentHandle?.adjustFrequency(frequency)
        }
    }

    func commitResult(userFrequency: Double) {
        guard state == .playingTunable else { return }
        guard let challenge = currentChallenge else { return }

        Task {
            try? await currentHandle?.stop()
            currentHandle = nil
        }

        let settings = currentSettings
        let referenceFrequency = (try? FrequencyCalculation.frequency(
            midiNote: challenge.referenceNote,
            referencePitch: settings.referencePitch
        )) ?? 440.0

        let userCentError = 1200.0 * log2(userFrequency / referenceFrequency)

        let result = CompletedPitchMatching(
            referenceNote: challenge.referenceNote,
            initialCentOffset: challenge.initialCentOffset,
            userCentError: userCentError
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
        guard state != .idle else { return }
        trainingTask?.cancel()
        trainingTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil
        Task {
            try? await currentHandle?.stop()
            currentHandle = nil
        }
        state = .idle
    }

    // MARK: - Configuration

    private var currentSettings: TrainingSettings {
        if let override = settingsOverride { return override }
        let defaults = UserDefaults.standard
        return TrainingSettings(
            noteRangeMin: defaults.object(forKey: SettingsKeys.noteRangeMin) as? Int ?? SettingsKeys.defaultNoteRangeMin,
            noteRangeMax: defaults.object(forKey: SettingsKeys.noteRangeMax) as? Int ?? SettingsKeys.defaultNoteRangeMax,
            referencePitch: defaults.object(forKey: SettingsKeys.referencePitch) as? Double ?? SettingsKeys.defaultReferencePitch
        )
    }

    private var currentNoteDuration: TimeInterval {
        noteDurationOverride ?? (UserDefaults.standard.object(forKey: SettingsKeys.noteDuration) as? Double ?? SettingsKeys.defaultNoteDuration)
    }

    // MARK: - Challenge Generation

    private func generateChallenge() -> PitchMatchingChallenge {
        let settings = currentSettings
        let note = Int.random(in: settings.noteRangeMin...settings.noteRangeMax)
        let offset = Double.random(in: -100.0...100.0)
        return PitchMatchingChallenge(referenceNote: note, initialCentOffset: offset)
    }

    // MARK: - Training Loop

    private func playNextChallenge() async {
        let settings = currentSettings
        let noteDuration = currentNoteDuration
        let challenge = generateChallenge()
        currentChallenge = challenge

        do {
            let referenceFrequency = try FrequencyCalculation.frequency(
                midiNote: challenge.referenceNote,
                referencePitch: settings.referencePitch
            )

            state = .playingReference
            try await notePlayer.play(
                frequency: referenceFrequency,
                duration: noteDuration,
                velocity: velocity,
                amplitudeDB: 0.0
            )

            guard state != .idle && !Task.isCancelled else { return }

            let tunableFrequency = try FrequencyCalculation.frequency(
                midiNote: challenge.referenceNote,
                cents: challenge.initialCentOffset,
                referencePitch: settings.referencePitch
            )

            state = .playingTunable
            let handle = try await notePlayer.play(
                frequency: tunableFrequency,
                velocity: velocity,
                amplitudeDB: 0.0
            )
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

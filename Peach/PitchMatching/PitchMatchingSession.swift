import Foundation
import Observation
import os
import AVFoundation
import UIKit

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
    private var referenceFrequency: Double?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    // MARK: - Notification Observers

    private var audioInterruptionObserver: NSObjectProtocol?
    private var audioRouteChangeObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

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

        setupAudioInterruptionObservers()
    }

    isolated deinit {
        if let observer = audioInterruptionObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = audioRouteChangeObserver {
            notificationCenter.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            notificationCenter.removeObserver(observer)
        }
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

        let handleToStop = currentHandle
        currentHandle = nil
        Task {
            try? await handleToStop?.stop()
        }

        guard let referenceFrequency else { return }
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
        Task {
            try? await handleToStop?.stop()
        }
        state = .idle
    }

    // MARK: - Audio Interruption Handling

    private func setupAudioInterruptionObservers() {
        audioInterruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(typeValue: typeValue)
            }
        }

        audioRouteChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioRouteChange(reasonValue: reasonValue)
            }
        }

        backgroundObserver = notificationCenter.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
    }

    private func handleAudioInterruption(typeValue: UInt?) {
        guard let typeValue = typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            logger.warning("Audio interruption notification received but could not parse type")
            return
        }

        switch type {
        case .began:
            logger.info("Audio interruption began - stopping session")
            stop()
        case .ended:
            logger.info("Audio interruption ended - session remains stopped")
        @unknown default:
            logger.warning("Unknown audio interruption type: \(typeValue)")
        }
    }

    private func handleAudioRouteChange(reasonValue: UInt?) {
        guard let reasonValue = reasonValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            logger.warning("Audio route change notification received but could not parse reason")
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            logger.info("Audio device disconnected - stopping session")
            stop()
        case .newDeviceAvailable, .categoryChange, .override, .wakeFromSleep, .noSuitableRouteForCategory, .routeConfigurationChange, .unknown:
            logger.info("Audio route changed (reason: \(reason.rawValue)) - continuing")
        @unknown default:
            logger.warning("Unknown audio route change reason: \(reasonValue)")
        }
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

    private func generateChallenge(settings: TrainingSettings) -> PitchMatchingChallenge {
        let note = Int.random(in: settings.noteRangeMin...settings.noteRangeMax)
        let offset = Double.random(in: -100.0...100.0)
        return PitchMatchingChallenge(referenceNote: note, initialCentOffset: offset)
    }

    // MARK: - Training Loop

    private func playNextChallenge() async {
        let settings = currentSettings
        let noteDuration = currentNoteDuration
        let challenge = generateChallenge(settings: settings)
        currentChallenge = challenge

        do {
            let refFreq = try FrequencyCalculation.frequency(
                midiNote: challenge.referenceNote,
                referencePitch: settings.referencePitch
            )
            self.referenceFrequency = refFreq

            state = .playingReference
            try await notePlayer.play(
                frequency: refFreq,
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

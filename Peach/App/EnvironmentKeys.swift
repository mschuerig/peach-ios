import SwiftUI

// WALKTHROUGH: audioSampleRate has a concrete default (.standard48000) that silently
// masks missing injection. A sample rate mismatch would cause subtle timing bugs.
// Remove the default and make it optional or fatalError, so missing injection fails loudly.

// MARK: - Environment Keys (production defaults)

extension EnvironmentValues {
    @Entry var progressTimeline = ProgressTimeline(profile: PerceptualProfile())
    @Entry var activeSession: (any TrainingSession)? = nil
    @Entry var perceptualProfile = PerceptualProfile()
    @Entry var rhythmPlayer: (any RhythmPlayer)? = nil
    @Entry var stepSequencer: (any StepSequencer)? = nil
    @Entry var midiInput: (any MIDIInput)? = nil
    @Entry var audioSampleRate: SampleRate = .standard48000
}

// MARK: - Environment Keys (injected by PeachApp — defaults are stubs for previews only)

private struct SoundSourceProviderKey: EnvironmentKey {
    static var defaultValue: any SoundSourceProvider = StubSoundSourceProvider()
}

private struct UserSettingsKey: EnvironmentKey {
    static var defaultValue: any UserSettings = StubUserSettings()
}

private struct TrainingLifecycleKey: EnvironmentKey {
    static var defaultValue: TrainingLifecycleCoordinator = .stub
}

private struct SettingsCoordinatorKey: EnvironmentKey {
    static var defaultValue: SettingsCoordinator = .stub
}

private struct PitchDiscriminationSessionKey: EnvironmentKey {
    static var defaultValue: PitchDiscriminationSession = .stub
}

private struct PitchMatchingSessionKey: EnvironmentKey {
    static var defaultValue: PitchMatchingSession = .stub
}

private struct RhythmOffsetDetectionSessionKey: EnvironmentKey {
    static var defaultValue: RhythmOffsetDetectionSession = .stub
}

private struct ContinuousRhythmMatchingSessionKey: EnvironmentKey {
    static var defaultValue: ContinuousRhythmMatchingSession = .stub
}

extension EnvironmentValues {
    var soundSourceProvider: any SoundSourceProvider {
        get { self[SoundSourceProviderKey.self] }
        set { self[SoundSourceProviderKey.self] = newValue }
    }
    var userSettings: any UserSettings {
        get { self[UserSettingsKey.self] }
        set { self[UserSettingsKey.self] = newValue }
    }
    var trainingLifecycle: TrainingLifecycleCoordinator {
        get { self[TrainingLifecycleKey.self] }
        set { self[TrainingLifecycleKey.self] = newValue }
    }
    var settingsCoordinator: SettingsCoordinator {
        get { self[SettingsCoordinatorKey.self] }
        set { self[SettingsCoordinatorKey.self] = newValue }
    }
    var pitchDiscriminationSession: PitchDiscriminationSession {
        get { self[PitchDiscriminationSessionKey.self] }
        set { self[PitchDiscriminationSessionKey.self] = newValue }
    }
    var pitchMatchingSession: PitchMatchingSession {
        get { self[PitchMatchingSessionKey.self] }
        set { self[PitchMatchingSessionKey.self] = newValue }
    }
    var rhythmOffsetDetectionSession: RhythmOffsetDetectionSession {
        get { self[RhythmOffsetDetectionSessionKey.self] }
        set { self[RhythmOffsetDetectionSessionKey.self] = newValue }
    }
    var continuousRhythmMatchingSession: ContinuousRhythmMatchingSession {
        get { self[ContinuousRhythmMatchingSessionKey.self] }
        set { self[ContinuousRhythmMatchingSessionKey.self] = newValue }
    }
}

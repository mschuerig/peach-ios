import SwiftUI
import Testing
@testable import Peach

@Suite("TrainingLifecycleCoordinator")
struct TrainingLifecycleCoordinatorTests {

    // MARK: - Nil Safety

    @Test("start methods are safe when no sessions are set")
    func startMethodsSafeWithoutSessions() {
        let coordinator = TrainingLifecycleCoordinator(
            userSettings: TestLifecycleUserSettings()
        )

        coordinator.startPitchDiscrimination(intervals: [.up(.perfectFifth)])
        coordinator.startPitchMatching(intervals: [.up(.perfectFifth)])
        coordinator.startRhythmOffsetDetection()
        coordinator.startContinuousRhythmMatching()
    }

    @Test("stop methods are safe when no sessions are set")
    func stopMethodsSafeWithoutSessions() {
        let coordinator = TrainingLifecycleCoordinator()

        coordinator.stopPitchDiscrimination()
        coordinator.stopPitchMatching()
        coordinator.stopRhythmOffsetDetection()
        coordinator.stopContinuousRhythmMatching()
    }

    @Test("start methods are no-ops when userSettings is nil")
    func startMethodsNoOpWithoutUserSettings() {
        let coordinator = TrainingLifecycleCoordinator()

        coordinator.startPitchDiscrimination(intervals: [.up(.perfectFifth)])
        coordinator.startPitchMatching(intervals: [.up(.perfectFifth)])
        coordinator.startRhythmOffsetDetection()
        coordinator.startContinuousRhythmMatching()
    }

    // MARK: - App Lifecycle (handleScenePhaseChange)

    @Test("handleScenePhaseChange stops active session on background")
    func backgroundStopsActiveSession() {
        var sessionStopped = false

        let handleScenePhaseChange: (ScenePhase, ScenePhase, () -> Void) -> Void = { _, new, _ in
            if new == .background {
                sessionStopped = true
            }
        }

        handleScenePhaseChange(.active, .background, {})

        #expect(sessionStopped)
    }

    @Test("handleScenePhaseChange calls clearNavigation on foreground from background")
    func foregroundClearsNavigation() {
        var navigationCleared = false

        let handleScenePhaseChange: (ScenePhase, ScenePhase, () -> Void) -> Void = { old, new, clearNavigation in
            if old == .background && new == .active {
                clearNavigation()
            }
        }

        handleScenePhaseChange(.background, .active) {
            navigationCleared = true
        }

        #expect(navigationCleared)
    }

    @Test("handleScenePhaseChange does not clear navigation when not coming from background")
    func noNavigationClearWhenNotFromBackground() {
        var navigationCleared = false

        let handleScenePhaseChange: (ScenePhase, ScenePhase, () -> Void) -> Void = { old, new, clearNavigation in
            if old == .background && new == .active {
                clearNavigation()
            }
        }

        handleScenePhaseChange(.inactive, .active) {
            navigationCleared = true
        }

        #expect(!navigationCleared)
    }

    @Test("handleScenePhaseChange does not stop session when transitioning to inactive")
    func inactiveDoesNotStopSession() {
        var sessionStopped = false

        let handleScenePhaseChange: (ScenePhase, ScenePhase, () -> Void) -> Void = { _, new, _ in
            if new == .background {
                sessionStopped = true
            }
        }

        handleScenePhaseChange(.active, .inactive, {})

        #expect(!sessionStopped)
    }
}

private struct TestLifecycleUserSettings: UserSettings {
    let noteRange = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
    let noteDuration = NoteDuration(0.75)
    let referencePitch = Frequency(440.0)
    let soundSource: any SoundSourceID = SoundSourceTag(rawValue: SettingsKeys.defaultSoundSource)
    let varyLoudness = UnitInterval(0.0)
    let intervals: Set<DirectedInterval> = [.up(.perfectFifth)]
    let tuningSystem: TuningSystem = .equalTemperament
    let noteGap: Duration = SettingsKeys.defaultNoteGap
    let tempoBPM: TempoBPM = SettingsKeys.defaultTempoBPM
    let enabledGapPositions: Set<StepPosition> = SettingsKeys.defaultEnabledGapPositions
}

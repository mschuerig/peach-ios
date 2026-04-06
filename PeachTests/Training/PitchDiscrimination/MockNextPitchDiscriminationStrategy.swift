import Foundation
@testable import Peach

final class MockNextPitchDiscriminationStrategy: NextPitchDiscriminationStrategy {
    // MARK: - Test State Tracking

    var comparisons: [PitchDiscriminationTrial]
    var currentIndex = 0
    var callCount = 0
    var lastReceivedProfile: TrainingProfile?
    var lastReceivedSettings: PitchDiscriminationSettings?
    var lastReceivedLastComparison: CompletedPitchDiscriminationTrial?
    var lastReceivedInterval: DirectedInterval?

    // MARK: - Initialization

    init(comparisons: [PitchDiscriminationTrial] = [
        PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))
    ]) {
        self.comparisons = comparisons
    }

    // MARK: - Test Control

    var onNextTrialCalled: (() -> Void)?

    // MARK: - NextPitchDiscriminationStrategy Protocol

    func nextPitchDiscriminationTrial(
        profile: TrainingProfile,
        settings: PitchDiscriminationSettings,
        lastTrial: CompletedPitchDiscriminationTrial?,
        interval: DirectedInterval
    ) -> PitchDiscriminationTrial {
        callCount += 1
        lastReceivedProfile = profile
        lastReceivedSettings = settings
        lastReceivedLastComparison = lastTrial
        lastReceivedInterval = interval

        onNextTrialCalled?()

        let comparison = comparisons[currentIndex % comparisons.count]
        currentIndex += 1
        return comparison
    }

    // MARK: - Test Helpers

    func reset() {
        currentIndex = 0
        callCount = 0
        lastReceivedProfile = nil
        lastReceivedSettings = nil
        lastReceivedLastComparison = nil
        lastReceivedInterval = nil
        onNextTrialCalled = nil
    }
}

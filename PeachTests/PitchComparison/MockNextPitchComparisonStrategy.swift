import Foundation
@testable import Peach

final class MockNextPitchComparisonStrategy: NextPitchComparisonStrategy {
    // MARK: - Test State Tracking

    var comparisons: [PitchComparison]
    var currentIndex = 0
    var callCount = 0
    var lastReceivedProfile: PitchComparisonProfile?
    var lastReceivedSettings: PitchComparisonTrainingSettings?
    var lastReceivedLastComparison: CompletedPitchComparison?
    var lastReceivedInterval: DirectedInterval?

    // MARK: - Initialization

    init(comparisons: [PitchComparison] = [
        PitchComparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))
    ]) {
        self.comparisons = comparisons
    }

    // MARK: - NextPitchComparisonStrategy Protocol

    func nextPitchComparison(
        profile: PitchComparisonProfile,
        settings: PitchComparisonTrainingSettings,
        lastPitchComparison: CompletedPitchComparison?,
        interval: DirectedInterval
    ) -> PitchComparison {
        callCount += 1
        lastReceivedProfile = profile
        lastReceivedSettings = settings
        lastReceivedLastComparison = lastPitchComparison
        lastReceivedInterval = interval

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
    }
}

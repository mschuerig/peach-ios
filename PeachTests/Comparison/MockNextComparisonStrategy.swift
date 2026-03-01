import Foundation
@testable import Peach

final class MockNextComparisonStrategy: NextComparisonStrategy {
    // MARK: - Test State Tracking

    var comparisons: [Comparison]
    var currentIndex = 0
    var callCount = 0
    var lastReceivedProfile: PitchDiscriminationProfile?
    var lastReceivedSettings: TrainingSettings?
    var lastReceivedLastComparison: CompletedComparison?
    var lastReceivedInterval: Interval?

    // MARK: - Initialization

    init(comparisons: [Comparison] = [
        Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))
    ]) {
        self.comparisons = comparisons
    }

    // MARK: - NextComparisonStrategy Protocol

    func nextComparison(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?,
        interval: Interval
    ) -> Comparison {
        callCount += 1
        lastReceivedProfile = profile
        lastReceivedSettings = settings
        lastReceivedLastComparison = lastComparison
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

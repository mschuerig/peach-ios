import Foundation

enum ContinuousRhythmMatchingSettingsKeys {
    static let enabledGapPositions = "enabledGapPositions"
    static let defaultEnabledGapPositions: Set<BeatPosition> = Set(BeatPosition.allCases)
}

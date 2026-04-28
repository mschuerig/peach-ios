import Foundation

enum ContinuousRhythmMatchingSettingsKeys {
    static let enabledGapPositions = "enabledGapPositions"
    static let defaultEnabledGapPositions: Set<StepPosition> = Set(StepPosition.allCases)
}

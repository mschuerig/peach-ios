import Foundation

protocol ContinuousRhythmMatchingUserSettings {
    var enabledGapPositions: Set<StepPosition> { get }
}

final class AppContinuousRhythmMatchingUserSettings: ContinuousRhythmMatchingUserSettings {
    var defaults: UserDefaults = .standard

    var enabledGapPositions: Set<StepPosition> {
        guard let raw = defaults.string(forKey: ContinuousRhythmMatchingSettingsKeys.enabledGapPositions) else {
            return ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions
        }
        return GapPositionEncoding.decodeWithDefault(raw)
    }
}

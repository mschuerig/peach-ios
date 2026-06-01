import Foundation

protocol ContinuousRhythmMatchingUserSettings {
    var enabledGapPositions: Set<BeatPosition> { get }
}

final class AppContinuousRhythmMatchingUserSettings: ContinuousRhythmMatchingUserSettings {
    var defaults: UserDefaults = .standard

    var enabledGapPositions: Set<BeatPosition> {
        guard let raw = defaults.string(forKey: ContinuousRhythmMatchingSettingsKeys.enabledGapPositions) else {
            return ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions
        }
        return GapPositionEncoding.decodeWithDefault(raw)
    }
}

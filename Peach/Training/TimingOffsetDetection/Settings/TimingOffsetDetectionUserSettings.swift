import Foundation

protocol TimingOffsetDetectionUserSettings {
    var maxRepetitions: Int { get }
    var offsetNotePosition: OffsetNotePosition { get }
}

final class AppTimingOffsetDetectionUserSettings: TimingOffsetDetectionUserSettings {
    var defaults: UserDefaults = .standard

    /// Reads the configured maximum repetition count, clamping missing or out-of-range
    /// values (`< 1`) to ``TimingOffsetDetectionSettingsKeys/defaultMaxRepetitions``.
    /// Defence in depth: a corrupted UserDefaults value (0, negative, migration glitch)
    /// must not produce a crashing `precondition` in ``TimingOffsetDetectionSettings``.
    var maxRepetitions: Int {
        guard defaults.object(forKey: TimingOffsetDetectionSettingsKeys.maxRepetitions) != nil else {
            return TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions
        }
        let stored = defaults.integer(forKey: TimingOffsetDetectionSettingsKeys.maxRepetitions)
        guard stored >= 1 else {
            return TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions
        }
        return stored
    }

    var offsetNotePosition: OffsetNotePosition {
        guard defaults.object(forKey: TimingOffsetDetectionSettingsKeys.offsetNotePosition) != nil else {
            return .default
        }
        return OffsetNotePosition(
            clamping: defaults.integer(forKey: TimingOffsetDetectionSettingsKeys.offsetNotePosition)
        )
    }
}

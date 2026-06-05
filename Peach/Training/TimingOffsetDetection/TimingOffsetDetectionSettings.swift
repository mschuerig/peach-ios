import Foundation

struct TimingOffsetDetectionSettings: Sendable {
    var tempo: TempoBPM
    var feedbackDuration: Duration
    var maxOffsetPercentage: Double
    var minOffsetPercentage: Double
    var maxRepetitions: Int
    var offsetNotePosition: OffsetNotePosition
    var pattern: TimingOffsetDetectionPattern

    init(
        tempo: TempoBPM = TempoBPM(80),
        feedbackDuration: Duration = .milliseconds(400),
        maxOffsetPercentage: Double = 20.0,
        minOffsetPercentage: Double = 1.0,
        maxRepetitions: Int = TimingOffsetDetectionSettingsKeys.defaultMaxRepetitions,
        offsetNotePosition: OffsetNotePosition = .default,
        pattern: TimingOffsetDetectionPattern = TimingOffsetDetectionPatternCatalog.defaultPattern
    ) {
        precondition(minOffsetPercentage <= maxOffsetPercentage, "minOffsetPercentage must be <= maxOffsetPercentage")
        precondition(maxRepetitions >= 1, "maxRepetitions must be >= 1")
        precondition(
            pattern.pickable.contains(offsetNotePosition.rawValue),
            "TimingOffsetDetectionSettings: offsetNotePosition \(offsetNotePosition.rawValue) is not pickable for pattern '\(pattern.id)' (pickable: \(pattern.pickable.sorted()))"
        )
        self.tempo = tempo
        self.feedbackDuration = feedbackDuration
        self.maxOffsetPercentage = maxOffsetPercentage
        self.minOffsetPercentage = minOffsetPercentage
        self.maxRepetitions = maxRepetitions
        self.offsetNotePosition = offsetNotePosition
        self.pattern = pattern
    }

    static func from(
        _ userSettings: UserSettings,
        todUserSettings: TimingOffsetDetectionUserSettings
    ) -> TimingOffsetDetectionSettings {
        TimingOffsetDetectionSettings(
            tempo: userSettings.tempoBPM,
            maxRepetitions: todUserSettings.maxRepetitions,
            offsetNotePosition: todUserSettings.offsetNotePosition,
            pattern: todUserSettings.selectedPattern
        )
    }
}

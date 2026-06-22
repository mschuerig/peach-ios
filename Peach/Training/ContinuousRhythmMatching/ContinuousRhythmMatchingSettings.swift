import Foundation

struct ContinuousRhythmMatchingSettings: Sendable, Equatable {
    var tempo: TempoBPM
    var enabledGapPositions: Set<BeatPosition>

    init(tempo: TempoBPM = TempoBPM(80), enabledGapPositions: Set<BeatPosition> = [.fourth]) {
        precondition(!enabledGapPositions.isEmpty, "At least one gap position must be enabled")
        self.tempo = tempo
        self.enabledGapPositions = enabledGapPositions
    }

    static func from(
        _ userSettings: UserSettings,
        crmUserSettings: ContinuousRhythmMatchingUserSettings
    ) -> ContinuousRhythmMatchingSettings {
        ContinuousRhythmMatchingSettings(
            tempo: userSettings.tempoBPM,
            enabledGapPositions: crmUserSettings.enabledGapPositions
        )
    }
}

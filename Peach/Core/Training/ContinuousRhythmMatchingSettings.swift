import Foundation

struct ContinuousRhythmMatchingSettings: Sendable {
    var tempo: TempoBPM
    var enabledGapPositions: Set<StepPosition>

    init(tempo: TempoBPM = TempoBPM(80), enabledGapPositions: Set<StepPosition> = [.fourth]) {
        precondition(!enabledGapPositions.isEmpty, "At least one gap position must be enabled")
        self.tempo = tempo
        self.enabledGapPositions = enabledGapPositions
    }

    static func from(_ userSettings: UserSettings) -> ContinuousRhythmMatchingSettings {
        ContinuousRhythmMatchingSettings(
            tempo: userSettings.tempoBPM,
            enabledGapPositions: userSettings.enabledGapPositions
        )
    }
}

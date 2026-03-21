import Foundation

struct RhythmMatchingSettings: Sendable {
    var tempo: TempoBPM
    var feedbackDuration: Duration

    init(tempo: TempoBPM = TempoBPM(80), feedbackDuration: Duration = .milliseconds(400)) {
        self.tempo = tempo
        self.feedbackDuration = feedbackDuration
    }

    static func from(_ userSettings: UserSettings) -> RhythmMatchingSettings {
        RhythmMatchingSettings(tempo: userSettings.tempoBPM)
    }
}

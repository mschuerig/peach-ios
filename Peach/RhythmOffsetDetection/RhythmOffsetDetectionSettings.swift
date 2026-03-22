import Foundation

struct RhythmOffsetDetectionSettings: Sendable {
    var tempo: TempoBPM
    var feedbackDuration: Duration
    var maxOffsetPercentage: Double
    var minOffsetPercentage: Double

    init(
        tempo: TempoBPM = TempoBPM(80),
        feedbackDuration: Duration = .milliseconds(400),
        maxOffsetPercentage: Double = 20.0,
        minOffsetPercentage: Double = 1.0
    ) {
        precondition(minOffsetPercentage <= maxOffsetPercentage, "minOffsetPercentage must be <= maxOffsetPercentage")
        self.tempo = tempo
        self.feedbackDuration = feedbackDuration
        self.maxOffsetPercentage = maxOffsetPercentage
        self.minOffsetPercentage = minOffsetPercentage
    }

    static func from(_ userSettings: UserSettings) -> RhythmOffsetDetectionSettings {
        RhythmOffsetDetectionSettings(tempo: userSettings.tempoBPM)
    }
}

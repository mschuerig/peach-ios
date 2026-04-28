import Foundation

nonisolated struct TimingOffsetDetectionPayload: TrainingDisciplinePayload, Equatable {
    static let disciplineIdentifier = "timingOffsetDetection"
    static let currentPayloadVersion = 1

    var tempoBPM: Int

    /// Signed offset in milliseconds: negative = early, positive = late
    var offsetMs: Double

    var isCorrect: Bool
}

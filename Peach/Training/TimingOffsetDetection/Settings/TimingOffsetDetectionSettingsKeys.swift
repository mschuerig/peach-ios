import Foundation

enum TimingOffsetDetectionSettingsKeys {
    static let maxRepetitions = "timingOffsetDetectionMaxRepetitions"
    static let defaultMaxRepetitions: Int = 20

    /// 1-based position of the note that carries the timing offset. Range and
    /// default live on ``OffsetNotePosition``.
    static let offsetNotePosition = "timingOffsetDetectionOffsetNotePosition"
}

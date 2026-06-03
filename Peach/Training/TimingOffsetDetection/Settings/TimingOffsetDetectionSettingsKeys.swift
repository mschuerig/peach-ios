import Foundation

enum TimingOffsetDetectionSettingsKeys {
    static let maxRepetitions = "timingOffsetDetectionMaxRepetitions"
    static let defaultMaxRepetitions: Int = 20

    /// 1-based position of the note that carries the timing offset. Range and
    /// default live on ``OffsetNotePosition``; pattern-aware clamping lives on
    /// ``TimingOffsetDetectionPattern``.
    static let offsetNotePosition = "timingOffsetDetectionOffsetNotePosition"

    /// Id of the active ``TimingOffsetDetectionPattern``. Defaults to
    /// ``TimingOffsetDetectionPatternCatalog/defaultPatternId`` when absent;
    /// unknown ids fall back to the default pattern and emit a `.warning` log
    /// at the port boundary.
    static let selectedPatternId = "timingOffsetDetectionSelectedPatternId"
}

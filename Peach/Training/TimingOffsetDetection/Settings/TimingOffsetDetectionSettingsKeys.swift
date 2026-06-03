import Foundation

enum TimingOffsetDetectionSettingsKeys {
    static let maxRepetitions = "timingOffsetDetectionMaxRepetitions"
    static let defaultMaxRepetitions: Int = 20

    /// 1-based index of the note in the four-16th-note pattern that carries the
    /// timing offset. Placeholder name pending the terminology decision in
    /// story 82.2; renamed in story 82.4.
    static let offsetNotePosition = "timingOffsetDetectionOffsetNotePosition"
    static let defaultOffsetNotePosition: Int = 3
    static let validOffsetNotePositionRange = 1...4

    /// Returns `position` if it falls within ``validOffsetNotePositionRange``,
    /// otherwise ``defaultOffsetNotePosition``. Use this at every `@AppStorage`
    /// read site so corrupt storage cannot make the audio engine and the visual
    /// dot indicator disagree on which note is the tested one.
    static func clamped(_ position: Int) -> Int {
        validOffsetNotePositionRange.contains(position) ? position : defaultOffsetNotePosition
    }
}

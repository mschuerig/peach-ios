import Foundation

/// Stable ids for ``DisciplineSettingsSection`` declarations shared by the
/// rhythm-category disciplines. Both ``ContinuousRhythmMatchingDiscipline``
/// and ``TimingOffsetDetectionDiscipline`` declare the tempo section under
/// ``tempo``; the aggregating screen renders the first declarer and skips
/// the rest, so each discipline can stay self-contained.
enum SharedRhythmSectionID {
    static let tempo = "rhythm.tempo"
    static let gapPositions = "rhythm.gapPositions"
}

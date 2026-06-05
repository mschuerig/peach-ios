import Testing
@testable import Peach

@Suite("TimingOffsetDetectionPatternPickerSettingsSection — accessibility label derivation")
struct TimingOffsetDetectionPatternPickerSettingsSectionTests {

    // Locked composite labels per `tod-tuplet-renderer-design.md`
    // § *Per-cell accessibility labels*: comma-joined per-cell labels for the
    // pattern's visual cells (rest cells contribute nothing — they're absorbed
    // into the preceding `.note`'s cell or non-focusable orphan rests).

    @Test("pattern_01 composite label reads each audible position with the locked Note N of K form")
    func labelForPattern01() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern01
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(4)"),
            String(localized: "Note \(3) of \(4)"),
            String(localized: "Note \(4) of \(4)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_02 composite label — 3 audibles after rest absorption")
    func labelForPattern02() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern02
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(3)"),
            String(localized: "Note \(3) of \(3)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_03 composite label — 3 audibles after middle-rest absorption")
    func labelForPattern03() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern03
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(3)"),
            String(localized: "Note \(3) of \(3)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_04 composite label — 2 audibles (both rests absorbed)")
    func labelForPattern04() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern04
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(2)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_05 composite label — 2 audibles (both rests absorbed into accent)")
    func labelForPattern05() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern05
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(2)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    // MARK: - cascadeWrites(forNewId:)

    @Test("cascade writes resolve to (catalog id, pattern default) for a known id")
    func cascadeWritesForKnownId() {
        let resolved = TimingOffsetDetectionPatternPickerSettingsSection.cascadeWrites(
            forNewId: TimingOffsetDetectionPatternCatalog.defaultPatternId
        )
        let pattern = TimingOffsetDetectionPatternCatalog.defaultPattern
        #expect(resolved.selectedPatternId == pattern.id)
        #expect(resolved.offsetNotePosition == pattern.defaultOffsetNotePosition.rawValue)
    }

    @Test("cascade writes rewrite an unknown id to the catalog default's id")
    func cascadeWritesForUnknownId() {
        let resolved = TimingOffsetDetectionPatternPickerSettingsSection.cascadeWrites(
            forNewId: "pattern_does_not_exist"
        )
        let pattern = TimingOffsetDetectionPatternCatalog.defaultPattern
        // Storage must not retain the unknown id — the binding writes the
        // resolved pattern's id so subsequent reads round-trip consistently.
        #expect(resolved.selectedPatternId == pattern.id)
        #expect(resolved.offsetNotePosition == pattern.defaultOffsetNotePosition.rawValue)
    }

    // MARK: - Tuplet composite labels (enabled by Story 84.4)

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func labelForPattern10NestedTriplet() {
        // pattern_10 (`* *-*-*`): "Accent, Note 2 of 4, in triplet, Note 3 of 4, in triplet, Note 4 of 4, in triplet"
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func labelForPattern09MixedDuration() {
        // pattern_09 (`* *. .`): "Accent, Note 2 of 3, dotted, Note 3 of 3"
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func labelForPattern14LeadingDuplet() {
        // pattern_14 (`.-. * *`): "Accent, in duplet, Note 2 of 4, in duplet, Note 3 of 4, Note 4 of 4"
    }
}

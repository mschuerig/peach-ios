import Testing
@testable import Peach

@Suite("TimingOffsetDetectionPatternPickerSettingsSection — accessibility label derivation")
struct TimingOffsetDetectionPatternPickerSettingsSectionTests {

    // Locked composite labels per `tod-tuplet-renderer-design.md`
    // § *Per-cell accessibility labels*: comma-joined per-cell labels for the
    // pattern's visual cells (rest cells contribute nothing — they're absorbed
    // into the preceding `.note`'s cell or non-focusable orphan rests).

    @Test("pattern_straight16ths_01 composite label reads each audible position with the locked Note N of K form")
    func labelForPattern01() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_straight16ths_01
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(4)"),
            String(localized: "Note \(3) of \(4)"),
            String(localized: "Note \(4) of \(4)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_gapped16ths_01 composite label — 3 audibles after rest absorption")
    func labelForPattern02() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_gapped16ths_01
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(3)"),
            String(localized: "Note \(3) of \(3)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_gapped16ths_02 composite label — 3 audibles after middle-rest absorption")
    func labelForPattern03() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_gapped16ths_02
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(3)"),
            String(localized: "Note \(3) of \(3)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_gapped16ths_03 composite label — 2 audibles (both rests absorbed)")
    func labelForPattern04() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_gapped16ths_03
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(2)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_gapped16ths_04 composite label — 2 audibles (both rests absorbed into accent)")
    func labelForPattern05() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_gapped16ths_04
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

    // MARK: - Tuplet composite labels (Story 84.4 — pattern_triplets_01..15 registered)

    @Test("pattern_nested_01 (`* *-*-*`) composite label names the trailing nested triplet on audibles 2–4")
    func labelForPattern10NestedTriplet() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_nested_01
        )
        let inTriplet = String(localized: "in triplet")
        let expected = [
            String(localized: "Accent"),
            "\(String(localized: "Note \(2) of \(4)")), \(inTriplet)",
            "\(String(localized: "Note \(3) of \(4)")), \(inTriplet)",
            "\(String(localized: "Note \(4) of \(4)")), \(inTriplet)"
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_triplets_04 (`* *. .`) composite label carries `dotted` on audible 2")
    func labelForPattern09MixedDuration() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_triplets_04
        )
        let expected = [
            String(localized: "Accent"),
            "\(String(localized: "Note \(2) of \(3)")), \(String(localized: "dotted"))",
            String(localized: "Note \(3) of \(3)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_nested_05 (`.-. * *`) composite label opens with the leading-duplet accent and trails into the host triplet")
    func labelForPattern14LeadingDuplet() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_nested_05
        )
        let inDuplet = String(localized: "in duplet")
        let expected = [
            "\(String(localized: "Accent")), \(inDuplet)",
            "\(String(localized: "Note \(2) of \(4)")), \(inDuplet)",
            String(localized: "Note \(3) of \(4)"),
            String(localized: "Note \(4) of \(4)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_nested_02 (`*-*-* *`) composite label opens with the leading-triplet accent")
    func labelForPattern11LeadingTriplet() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_nested_02
        )
        let inTriplet = String(localized: "in triplet")
        let expected = [
            "\(String(localized: "Accent")), \(inTriplet)",
            "\(String(localized: "Note \(2) of \(4)")), \(inTriplet)",
            "\(String(localized: "Note \(3) of \(4)")), \(inTriplet)",
            String(localized: "Note \(4) of \(4)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    @Test("pattern_sextuplet_01 (sextuplet) composite label enumerates six audibles")
    func labelForPattern15Sextuplet() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern_sextuplet_01
        )
        let expected = [
            String(localized: "Accent"),
            String(localized: "Note \(2) of \(6)"),
            String(localized: "Note \(3) of \(6)"),
            String(localized: "Note \(4) of \(6)"),
            String(localized: "Note \(5) of \(6)"),
            String(localized: "Note \(6) of \(6)")
        ].joined(separator: ", ")
        #expect(label == expected)
    }

    // MARK: - cascadeWrites for tuplet entries (covers each locked default)

    @Test(
        "cascade writes for each always-on Story 84.4 tuplet pattern resolve to that pattern's locked default position",
        arguments: [
            ("pattern_triplets_01", 2),
            ("pattern_triplets_02", 2),
            ("pattern_triplets_03", 2),
            ("pattern_triplets_04", 2),
            ("pattern_sextuplet_01", 4)
        ] as [(String, Int)]
    )
    func cascadeWritesForTupletPatterns(expectation: (id: String, expectedDefault: Int)) {
        let resolved = TimingOffsetDetectionPatternPickerSettingsSection.cascadeWrites(
            forNewId: expectation.id
        )
        #expect(resolved.selectedPatternId == expectation.id)
        #expect(resolved.offsetNotePosition == expectation.expectedDefault)
    }

    #if PEACH_RESEARCH
    /// Nested-bucket cascade resolutions — registered only in `PEACH_RESEARCH`
    /// builds where the entries are part of the catalog.
    @Test(
        "cascade writes for each Nested-bucket pattern resolve to its locked default position (PEACH_RESEARCH-gated)",
        arguments: [
            ("pattern_nested_01", 3),
            ("pattern_nested_02", 3),
            ("pattern_nested_03", 4),
            ("pattern_nested_04", 3),
            ("pattern_nested_05", 2)
        ] as [(String, Int)]
    )
    func cascadeWritesForNestedPatterns(expectation: (id: String, expectedDefault: Int)) {
        let resolved = TimingOffsetDetectionPatternPickerSettingsSection.cascadeWrites(
            forNewId: expectation.id
        )
        #expect(resolved.selectedPatternId == expectation.id)
        #expect(resolved.offsetNotePosition == expectation.expectedDefault)
    }
    #endif
}

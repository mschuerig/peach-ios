import Testing
import CoreGraphics
@testable import Peach

@Suite("TimingDotView Tests")
struct TimingDotViewTests {

    // MARK: - Visual vocabulary constants (pinned)

    @Test("dot diameter is 16pt")
    func dotDiameter() async {
        #expect(TimingDotView.dotDiameter == 16)
    }

    @Test("beat one dot diameter is 22pt")
    func beatOneDotDiameter() async {
        #expect(TimingDotView.beatOneDotDiameter == 22)
    }

    @Test("dot spacing is 24pt")
    func dotSpacing() async {
        #expect(TimingDotView.dotSpacing == 24)
    }

    @Test("diameter for step index 0 returns beat one diameter")
    func diameterForFirstStep() async {
        #expect(TimingDotView.diameter(forStepIndex: 0) == 22)
    }

    @Test("diameter for step indices 1-3 returns standard diameter")
    func diameterForOtherSteps() async {
        for i in 1...3 {
            #expect(TimingDotView.diameter(forStepIndex: i) == 16)
        }
    }

    @Test("overlap offset is half the dot diameter")
    func overlapOffset() async {
        #expect(abs(TimingDotView.overlapOffset - TimingDotView.dotDiameter / 2) < 0.001)
    }

    @Test("tested note frame width is dot diameter plus overlap offset")
    func testedNoteFrameWidthIsDotDiameterPlusOverlapOffset() async {
        #expect(abs(TimingDotView.testedNoteFrameWidth - (TimingDotView.dotDiameter + TimingDotView.overlapOffset)) < 0.001)
    }

    @Test("bracket geometry base values (locked in tod-tuplet-renderer-design § Grouping indicators)")
    func bracketGeometryBaseValues() async {
        #expect(TimingDotView.bracketThicknessBase == 1.5)
        #expect(TimingDotView.bracketOffsetAboveBase == 4)
        #expect(TimingDotView.bracketEndInsetBase == 1)
    }

    // MARK: - visualCells(for:) — Epic-82 catalog (flat patterns)

    /// Locked widths and start-x values per `tod-tuplet-renderer-design.md`
    /// § *Cell-width math* worked examples. Tolerance scales with the magnitude
    /// of the expected value so deeper nesting (smaller cell widths from larger
    /// divisors) doesn't accumulate enough float drift to break a hard-coded
    /// absolute threshold.
    private static func widthTolerance(forExpected expected: CGFloat) -> CGFloat {
        max(abs(expected), 1.0) * 1e-6
    }

    @Test("visualCells for pattern_straight16ths_01 — 4 equal cells of W/4 each")
    func visualCellsPattern01() async {
        let cells = TimingDotView.visualCells(for: .pattern_straight16ths_01)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.25, .accent),
            (0.25, 0.25, .normalAudible(audiblePosition: 2)),
            (0.5, 0.25, .normalAudible(audiblePosition: 3)),
            (0.75, 0.25, .normalAudible(audiblePosition: 4))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_gapped16ths_01 — widths W/2, W/4, W/4 (accent absorbs trailing rest)")
    func visualCellsPattern02() async {
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_01)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.5, .accent),
            (0.5, 0.25, .normalAudible(audiblePosition: 2)),
            (0.75, 0.25, .normalAudible(audiblePosition: 3))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_gapped16ths_02 — widths W/4, W/2, W/4 (audible 2 absorbs trailing rest)")
    func visualCellsPattern03() async {
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_02)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.25, .accent),
            (0.25, 0.5, .normalAudible(audiblePosition: 2)),
            (0.75, 0.25, .normalAudible(audiblePosition: 3))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_gapped16ths_03 — 2 equal cells of W/2 each (8ths feel)")
    func visualCellsPattern04() async {
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_03)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.5, .accent),
            (0.5, 0.5, .normalAudible(audiblePosition: 2))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_gapped16ths_04 — widths 3W/4, W/4 (accent absorbs two rests)")
    func visualCellsPattern05() async {
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_04)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.75, .accent),
            (0.75, 0.25, .normalAudible(audiblePosition: 2))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    // MARK: - cellAccessibilityLabel — Epic-82 catalog (flat patterns)

    @Test(
        "cellAccessibilityLabel for pattern_straight16ths_01 reads the locked flat-pattern form",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(4)")),
            (2, String(localized: "Note \(3) of \(4)")),
            (3, String(localized: "Note \(4) of \(4)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern01(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern_straight16ths_01)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern_straight16ths_01)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_gapped16ths_01 — 3 audibles after rest absorption",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(3)")),
            (2, String(localized: "Note \(3) of \(3)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern02(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_01)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern_gapped16ths_01)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_gapped16ths_02 — 3 audibles (audible 2 absorbs middle rest)",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(3)")),
            (2, String(localized: "Note \(3) of \(3)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern03(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_02)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern_gapped16ths_02)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_gapped16ths_03 — 2 audibles (both rests absorbed)",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(2)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern04(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_03)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern_gapped16ths_03)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_gapped16ths_04 — 2 audibles (accent absorbs 2 rests)",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(2)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern05(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_04)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern_gapped16ths_04)
        #expect(label == expected)
    }

    // MARK: - Doubled-glyph cell mapping (regression for I/O Matrix)

    /// Locks the regression-risk scenario from the spec's I/O matrix:
    /// `pattern_gapped16ths_02` + `OffsetNotePosition(3)` must overlay the *third* visual
    /// cell (the rightmost W/4 audible cell at startX 0.75) — never the
    /// absorbed-rest mid-cell at startX 0.25.
    @Test("doubled-glyph for pattern_gapped16ths_02 at position 3 lands on the rightmost W/4 cell, not the absorbed-rest mid-cell")
    func doubledGlyphForPattern03Position3LandsOnRightmostCell() async {
        let highlightedAudible = TimingDotView.audiblePositionToHighlight(
            for: .pattern_gapped16ths_02,
            offsetNotePosition: OffsetNotePosition(3)
        )
        #expect(highlightedAudible == 3)

        let cells = TimingDotView.visualCells(for: .pattern_gapped16ths_02)
        // Cell index 2 carries audible position 3 at startX 0.75 per `visualCellsPattern03`.
        let highlightedCell = cells.first {
            if case .normalAudible(let pos) = $0.kind, pos == highlightedAudible { return true }
            return false
        }
        #expect(highlightedCell?.startXProportion == 0.75)
        #expect(highlightedCell?.widthProportion == 0.25)
    }

    @Test("audiblePositionToHighlight returns nil for the metric anchor (position 1) — accent is never pickable")
    func audiblePositionToHighlightRejectsAccent() async {
        let result = TimingDotView.audiblePositionToHighlight(
            for: .pattern_straight16ths_01,
            offsetNotePosition: OffsetNotePosition(1)
        )
        #expect(result == nil)
    }

    // MARK: - audiblePositionToHighlight

    @Test("audiblePositionToHighlight returns nil when position out of range")
    func audiblePositionToHighlightOutOfRange() async {
        // pattern_gapped16ths_03 has audibleCount == 2; position 3 is out of range.
        let result = TimingDotView.audiblePositionToHighlight(
            for: .pattern_gapped16ths_03,
            offsetNotePosition: OffsetNotePosition(3)
        )
        #expect(result == nil)
    }

    @Test(
        "audiblePositionToHighlight returns the audible position number for pickable positions",
        arguments: [2, 3, 4]
    )
    func audiblePositionToHighlightValid(rawValue: Int) async {
        let result = TimingDotView.audiblePositionToHighlight(
            for: .pattern_straight16ths_01,
            offsetNotePosition: OffsetNotePosition(rawValue)
        )
        #expect(result == rawValue)
    }

    // MARK: - isAudibleLit (grid-based litCount → audible lit state)

    @Test(
        "isAudibleLit for pattern_gapped16ths_03 (audibles at grid [0],[2]) follows top-level lit progression",
        arguments: [
            (1, 0, false), (1, 1, true), (1, 2, true),
            (2, 0, false), (2, 1, false), (2, 2, false),
            (2, 3, true), (2, 4, true)
        ] as [(Int, Int, Bool)]
    )
    func isAudibleLitPattern04(input: (Int, Int, Bool)) async {
        let (audible, litCount, expected) = input
        #expect(TimingDotView.isAudibleLit(audiblePosition: audible, in: .pattern_gapped16ths_03, litCount: litCount) == expected)
    }

    // MARK: - Tuplet-renderer coverage (Story 84.4 — pattern_triplets_01..15 registered)

    @Test("visualCells for pattern_triplets_01 — 3 equal cells of W/3 each")
    func visualCellsPattern06Triplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_triplets_01)
        let third = 1.0 / 3.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, third, .accent),
            (third, third, .normalAudible(audiblePosition: 2)),
            (2.0 * third, third, .normalAudible(audiblePosition: 3))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_triplets_02 (`* * -`) — widths W/3, 2W/3 (audible 2 absorbs trailing rest)")
    func visualCellsPattern07TripletTrailingRest() async {
        let cells = TimingDotView.visualCells(for: .pattern_triplets_02)
        let third = 1.0 / 3.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, third, .accent),
            (third, 2.0 * third, .normalAudible(audiblePosition: 2))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_triplets_03 (`* - *`) — widths 2W/3, W/3 (accent absorbs middle rest)")
    func visualCellsPattern08TripletMiddleRest() async {
        let cells = TimingDotView.visualCells(for: .pattern_triplets_03)
        let third = 1.0 / 3.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 2.0 * third, .accent),
            (2.0 * third, third, .normalAudible(audiblePosition: 2))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_triplets_04 (`* *. .`) — widths 2W/6, 3W/6, W/6 (mixed-duration triplet)")
    func visualCellsPattern09MixedDuration() async {
        let cells = TimingDotView.visualCells(for: .pattern_triplets_04)
        let sixth = 1.0 / 6.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 2.0 * sixth, .accent),
            (2.0 * sixth, 3.0 * sixth, .normalAudible(audiblePosition: 2)),
            (5.0 * sixth, sixth, .normalAudible(audiblePosition: 3))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_nested_01 (`* *-*-*`) — top W/2 accent + 3 nested W/6 cells + bracket")
    func visualCellsPattern10NestedTriplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_01)
        let sixth = 1.0 / 6.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.5, .accent),
            (0.5, sixth, .normalAudible(audiblePosition: 2)),
            (0.5 + sixth, sixth, .normalAudible(audiblePosition: 3)),
            (0.5 + 2.0 * sixth, sixth, .normalAudible(audiblePosition: 4)),
            (0.5, 0.5, .nestingBracket(childDivision: .triplet))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_nested_02 (`*-*-* *`) — 3 leading nested W/6 cells + top W/2 + leading bracket")
    func visualCellsPattern11LeadingNestedTriplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_02)
        let sixth = 1.0 / 6.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, sixth, .accent),
            (sixth, sixth, .normalAudible(audiblePosition: 2)),
            (2.0 * sixth, sixth, .normalAudible(audiblePosition: 3)),
            (0.5, 0.5, .normalAudible(audiblePosition: 4)),
            (0.0, 0.5, .nestingBracket(childDivision: .triplet))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_nested_03 (`* * .-.`) — 2 top-level triplet cells + nested duplet (W/6, W/6) + trailing bracket")
    func visualCellsPattern12TrailingDuplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_03)
        let third = 1.0 / 3.0
        let sixth = 1.0 / 6.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, third, .accent),
            (third, third, .normalAudible(audiblePosition: 2)),
            (2.0 * third, sixth, .normalAudible(audiblePosition: 3)),
            (2.0 * third + sixth, sixth, .normalAudible(audiblePosition: 4)),
            (2.0 * third, third, .nestingBracket(childDivision: .duplet))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_nested_04 (`* .-. *`) — top + nested duplet (middle) + top + middle bracket")
    func visualCellsPattern13MiddleDuplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_04)
        let third = 1.0 / 3.0
        let sixth = 1.0 / 6.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, third, .accent),
            (third, sixth, .normalAudible(audiblePosition: 2)),
            (third + sixth, sixth, .normalAudible(audiblePosition: 3)),
            (2.0 * third, third, .normalAudible(audiblePosition: 4)),
            (third, third, .nestingBracket(childDivision: .duplet))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_nested_05 (`.-. * *`) — 2 leading nested duplet cells + 2 top-level triplet cells + leading bracket")
    func visualCellsPattern14LeadingDuplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_05)
        let third = 1.0 / 3.0
        let sixth = 1.0 / 6.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, sixth, .accent),
            (sixth, sixth, .normalAudible(audiblePosition: 2)),
            (third, third, .normalAudible(audiblePosition: 3)),
            (2.0 * third, third, .normalAudible(audiblePosition: 4)),
            (0.0, third, .nestingBracket(childDivision: .duplet))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_sextuplet_01 — 6 equal cells of W/6 each (flat sextuplet)")
    func visualCellsPattern15Sextuplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_sextuplet_01)
        let sixth = 1.0 / 6.0
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, sixth, .accent),
            (sixth, sixth, .normalAudible(audiblePosition: 2)),
            (2.0 * sixth, sixth, .normalAudible(audiblePosition: 3)),
            (3.0 * sixth, sixth, .normalAudible(audiblePosition: 4)),
            (4.0 * sixth, sixth, .normalAudible(audiblePosition: 5)),
            (5.0 * sixth, sixth, .normalAudible(audiblePosition: 6))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("cellAccessibilityLabel for pattern_triplets_04 audible 2 carries the dotted descriptor")
    func cellAccessibilityLabelPattern09Dotted() async {
        let cells = TimingDotView.visualCells(for: .pattern_triplets_04)
        // Cell index 1 is the audible-2 cell (the dotted long cell).
        let label = TimingDotView.cellAccessibilityLabel(for: cells[1], in: .pattern_triplets_04)
        let expected = "\(String(localized: "Note \(2) of \(3)")), \(String(localized: "dotted"))"
        #expect(label == expected)
    }

    @Test("cellAccessibilityLabel for pattern_nested_02 audible 1 names the leading triplet (`Accent, in triplet`)")
    func cellAccessibilityLabelPattern11LeadingNestedAccent() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_02)
        // Cell index 0 is the accent — leading-nested-triplet first audible.
        let label = TimingDotView.cellAccessibilityLabel(for: cells[0], in: .pattern_nested_02)
        let expected = "\(String(localized: "Accent")), \(String(localized: "in triplet"))"
        #expect(label == expected)
    }

    @Test("cellAccessibilityLabel for pattern_nested_05 audible 1 names the leading duplet (`Accent, in duplet`)")
    func cellAccessibilityLabelPattern14LeadingNestedDuplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_05)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[0], in: .pattern_nested_05)
        let expected = "\(String(localized: "Accent")), \(String(localized: "in duplet"))"
        #expect(label == expected)
    }

    @Test("cellAccessibilityLabel for pattern_nested_04 middle-duplet audibles read `Note N of 4, in duplet`")
    func cellAccessibilityLabelPattern13MiddleDuplet() async {
        let cells = TimingDotView.visualCells(for: .pattern_nested_04)
        // Cell index 1 is audible 2 (first cell of the nested duplet);
        // cell index 2 is audible 3 (second cell of the nested duplet).
        let label2 = TimingDotView.cellAccessibilityLabel(for: cells[1], in: .pattern_nested_04)
        let label3 = TimingDotView.cellAccessibilityLabel(for: cells[2], in: .pattern_nested_04)
        let expected2 = "\(String(localized: "Note \(2) of \(4)")), \(String(localized: "in duplet"))"
        let expected3 = "\(String(localized: "Note \(3) of \(4)")), \(String(localized: "in duplet"))"
        #expect(label2 == expected2)
        #expect(label3 == expected3)
    }

    // MARK: - Helpers

    private static func expectVisualCells(
        _ cells: [TimingDotView.VisualCell],
        matches expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(cells.count == expected.count, "cell count mismatch", sourceLocation: sourceLocation)
        // A count mismatch would mean the index-by-index loop below indexes
        // out of bounds and traps. Bail early — the cell-count failure has
        // already been recorded.
        guard cells.count == expected.count else { return }
        for (index, exp) in expected.enumerated() {
            let cell = cells[index]
            let (expectedStart, expectedWidth, expectedKind) = exp
            #expect(abs(cell.startXProportion - expectedStart) < widthTolerance(forExpected: expectedStart),
                    "cell \(index) startX: got \(cell.startXProportion), expected \(expectedStart)",
                    sourceLocation: sourceLocation)
            #expect(abs(cell.widthProportion - expectedWidth) < widthTolerance(forExpected: expectedWidth),
                    "cell \(index) width: got \(cell.widthProportion), expected \(expectedWidth)",
                    sourceLocation: sourceLocation)
            #expect(cell.kind == expectedKind,
                    "cell \(index) kind: got \(cell.kind), expected \(expectedKind)",
                    sourceLocation: sourceLocation)
        }
    }
}

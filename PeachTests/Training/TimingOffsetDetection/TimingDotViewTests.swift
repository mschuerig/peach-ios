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
    /// § *Cell-width math* worked examples. Tolerance 1e-6 for floating-point
    /// equality across the depth-first walk.
    private static let widthTolerance: CGFloat = 1e-6

    @Test("visualCells for pattern_01 — 4 equal cells of W/4 each")
    func visualCellsPattern01() async {
        let cells = TimingDotView.visualCells(for: .pattern01)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.25, .accent),
            (0.25, 0.25, .normalAudible(audiblePosition: 2)),
            (0.5, 0.25, .normalAudible(audiblePosition: 3)),
            (0.75, 0.25, .normalAudible(audiblePosition: 4))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_02 — widths W/2, W/4, W/4 (accent absorbs trailing rest)")
    func visualCellsPattern02() async {
        let cells = TimingDotView.visualCells(for: .pattern02)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.5, .accent),
            (0.5, 0.25, .normalAudible(audiblePosition: 2)),
            (0.75, 0.25, .normalAudible(audiblePosition: 3))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_03 — widths W/4, W/2, W/4 (audible 2 absorbs trailing rest)")
    func visualCellsPattern03() async {
        let cells = TimingDotView.visualCells(for: .pattern03)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.25, .accent),
            (0.25, 0.5, .normalAudible(audiblePosition: 2)),
            (0.75, 0.25, .normalAudible(audiblePosition: 3))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_04 — 2 equal cells of W/2 each (8ths feel)")
    func visualCellsPattern04() async {
        let cells = TimingDotView.visualCells(for: .pattern04)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.5, .accent),
            (0.5, 0.5, .normalAudible(audiblePosition: 2))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    @Test("visualCells for pattern_05 — widths 3W/4, W/4 (accent absorbs two rests)")
    func visualCellsPattern05() async {
        let cells = TimingDotView.visualCells(for: .pattern05)
        let expected: [(CGFloat, CGFloat, TimingDotView.VisualCellKind)] = [
            (0.0, 0.75, .accent),
            (0.75, 0.25, .normalAudible(audiblePosition: 2))
        ]
        Self.expectVisualCells(cells, matches: expected)
    }

    // MARK: - cellAccessibilityLabel — Epic-82 catalog (flat patterns)

    @Test(
        "cellAccessibilityLabel for pattern_01 reads the locked flat-pattern form",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(4)")),
            (2, String(localized: "Note \(3) of \(4)")),
            (3, String(localized: "Note \(4) of \(4)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern01(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern01)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern01)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_02 — 3 audibles after rest absorption",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(3)")),
            (2, String(localized: "Note \(3) of \(3)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern02(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern02)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern02)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_03 — 3 audibles (audible 2 absorbs middle rest)",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(3)")),
            (2, String(localized: "Note \(3) of \(3)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern03(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern03)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern03)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_04 — 2 audibles (both rests absorbed)",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(2)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern04(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern04)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern04)
        #expect(label == expected)
    }

    @Test(
        "cellAccessibilityLabel for pattern_05 — 2 audibles (accent absorbs 2 rests)",
        arguments: [
            (0, String(localized: "Accent")),
            (1, String(localized: "Note \(2) of \(2)"))
        ] as [(Int, String)]
    )
    func cellAccessibilityLabelPattern05(input: (Int, String)) async {
        let (cellIndex, expected) = input
        let cells = TimingDotView.visualCells(for: .pattern05)
        let label = TimingDotView.cellAccessibilityLabel(for: cells[cellIndex], in: .pattern05)
        #expect(label == expected)
    }

    // MARK: - Doubled-glyph cell mapping (regression for I/O Matrix)

    /// Locks the regression-risk scenario from the spec's I/O matrix:
    /// `pattern_03` + `OffsetNotePosition(3)` must overlay the *third* visual
    /// cell (the rightmost W/4 audible cell at startX 0.75) — never the
    /// absorbed-rest mid-cell at startX 0.25.
    @Test("doubled-glyph for pattern_03 at position 3 lands on the rightmost W/4 cell, not the absorbed-rest mid-cell")
    func doubledGlyphForPattern03Position3LandsOnRightmostCell() async {
        let highlightedAudible = TimingDotView.audiblePositionToHighlight(
            for: .pattern03,
            offsetNotePosition: OffsetNotePosition(3)
        )
        #expect(highlightedAudible == 3)

        let cells = TimingDotView.visualCells(for: .pattern03)
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
            for: .pattern01,
            offsetNotePosition: OffsetNotePosition(1)
        )
        #expect(result == nil)
    }

    // MARK: - audiblePositionToHighlight

    @Test("audiblePositionToHighlight returns nil when position out of range")
    func audiblePositionToHighlightOutOfRange() async {
        // pattern_04 has audibleCount == 2; position 3 is out of range.
        let result = TimingDotView.audiblePositionToHighlight(
            for: .pattern04,
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
            for: .pattern01,
            offsetNotePosition: OffsetNotePosition(rawValue)
        )
        #expect(result == rawValue)
    }

    // MARK: - isAudibleLit (grid-based litCount → audible lit state)

    @Test(
        "isAudibleLit for pattern_04 (audibles at grid [0],[2]) follows top-level lit progression",
        arguments: [
            (1, 0, false), (1, 1, true), (1, 2, true),
            (2, 0, false), (2, 1, false), (2, 2, false),
            (2, 3, true), (2, 4, true)
        ] as [(Int, Int, Bool)]
    )
    func isAudibleLitPattern04(input: (Int, Int, Bool)) async {
        let (audible, litCount, expected) = input
        #expect(TimingDotView.isAudibleLit(audiblePosition: audible, in: .pattern04, litCount: litCount) == expected)
    }

    // MARK: - Tuplet-renderer stubs (enabled by Story 84.4 when pattern_06..15 register)

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func visualCellsPattern06Triplet() async {
        // pattern_06 (`* * *`) — 3 equal cells of W/3 each.
        // let cells = TimingDotView.visualCells(for: .pattern06)
        // expected: (0, 1/3, .accent), (1/3, 1/3, .normalAudible(2)), (2/3, 1/3, .normalAudible(3))
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func visualCellsPattern09MixedDuration() async {
        // pattern_09 (`* *. .`) — 3 cells of widths W/3, W/2, W/6.
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func visualCellsPattern10NestedTriplet() async {
        // pattern_10 (`* *-*-*`) — top W/2 cell + nested-bracket span over 3 cells of W/6.
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func cellAccessibilityLabelPattern09Dotted() async {
        // pattern_09 audible 2 → "Note 2 of 3, dotted".
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func cellAccessibilityLabelPattern11LeadingNestedAccent() async {
        // pattern_11 (`*-*-* *`) audible 1 → "Accent, in triplet".
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func cellAccessibilityLabelPattern14LeadingNestedDuplet() async {
        // pattern_14 (`.-. * *`) audible 1 → "Accent, in duplet".
    }

    @Test(.disabled("Enabled by Story 84.4 catalog registration of pattern_06..15"))
    func cellAccessibilityLabelPattern13MiddleDuplet() async {
        // pattern_13 (`* .-. *`) audible 2 → "Note 2 of 4, in duplet"; audible 3 → "Note 3 of 4, in duplet".
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
            #expect(abs(cell.startXProportion - expectedStart) < widthTolerance,
                    "cell \(index) startX: got \(cell.startXProportion), expected \(expectedStart)",
                    sourceLocation: sourceLocation)
            #expect(abs(cell.widthProportion - expectedWidth) < widthTolerance,
                    "cell \(index) width: got \(cell.widthProportion), expected \(expectedWidth)",
                    sourceLocation: sourceLocation)
            #expect(cell.kind == expectedKind,
                    "cell \(index) kind: got \(cell.kind), expected \(expectedKind)",
                    sourceLocation: sourceLocation)
        }
    }
}

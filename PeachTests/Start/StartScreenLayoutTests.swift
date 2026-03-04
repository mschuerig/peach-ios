import Testing
import SwiftUI
@testable import Peach

/// Tests for StartScreen layout adaptation based on vertical size class
@Suite("StartScreen Layout Tests")
struct StartScreenLayoutTests {

    // MARK: - Section Spacing

    @Test("Section spacing is 24pt in compact mode")
    func sectionSpacingCompact() async {
        #expect(StartScreen.sectionSpacing(isCompact: true) == 24)
    }

    @Test("Section spacing is 28pt in regular mode")
    func sectionSpacingRegular() async {
        #expect(StartScreen.sectionSpacing(isCompact: false) == 28)
    }

    @Test("Compact section spacing is smaller than regular")
    func compactSectionSpacingSmallerThanRegular() async {
        #expect(StartScreen.sectionSpacing(isCompact: true) < StartScreen.sectionSpacing(isCompact: false))
    }

    // MARK: - Card Spacing

    @Test("Card spacing is 6pt in compact mode")
    func cardSpacingCompact() async {
        #expect(StartScreen.cardSpacing(isCompact: true) == 6)
    }

    @Test("Card spacing is 10pt in regular mode")
    func cardSpacingRegular() async {
        #expect(StartScreen.cardSpacing(isCompact: false) == 10)
    }

    @Test("Compact card spacing is smaller than regular")
    func compactCardSpacingSmallerThanRegular() async {
        #expect(StartScreen.cardSpacing(isCompact: true) < StartScreen.cardSpacing(isCompact: false))
    }

    // MARK: - Card Corner Radius

    @Test("Card corner radius is 12pt")
    func cardCornerRadius() async {
        #expect(StartScreen.cardCornerRadius == 12)
    }
}

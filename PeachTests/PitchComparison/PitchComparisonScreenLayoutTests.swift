import Testing
import SwiftUI
@testable import Peach

/// Tests for PitchComparisonScreen layout adaptation based on vertical size class (Story 7.3)
@Suite("PitchComparisonScreen Layout Tests")
struct PitchComparisonScreenLayoutTests {

    // MARK: - Button Icon Size

    @Test("Button icon size is 60pt in compact mode")
    func buttonIconSizeCompact() {
        #expect(PitchComparisonScreen.buttonIconSize(isCompact: true) == 60)
    }

    @Test("Button icon size is 80pt in regular mode")
    func buttonIconSizeRegular() {
        #expect(PitchComparisonScreen.buttonIconSize(isCompact: false) == 80)
    }

    // MARK: - Button Min Height

    @Test("Button min height is 120pt in compact mode")
    func buttonMinHeightCompact() {
        #expect(PitchComparisonScreen.buttonMinHeight(isCompact: true) == 120)
    }

    @Test("Button min height is 200pt in regular mode")
    func buttonMinHeightRegular() {
        #expect(PitchComparisonScreen.buttonMinHeight(isCompact: false) == 200)
    }

    // MARK: - Button Text Font

    @Test("Button text font is title2 in compact mode")
    func buttonTextFontCompact() {
        #expect(PitchComparisonScreen.buttonTextFont(isCompact: true) == .title2)
    }

    @Test("Button text font is title in regular mode")
    func buttonTextFontRegular() {
        #expect(PitchComparisonScreen.buttonTextFont(isCompact: false) == .title)
    }

    // MARK: - Compact vs Regular Consistency

    @Test("All compact dimensions are smaller than regular dimensions")
    func compactDimensionsSmallerThanRegular() {
        #expect(PitchComparisonScreen.buttonIconSize(isCompact: true) < PitchComparisonScreen.buttonIconSize(isCompact: false))
        #expect(PitchComparisonScreen.buttonMinHeight(isCompact: true) < PitchComparisonScreen.buttonMinHeight(isCompact: false))
    }

    @Test("Compact button min height exceeds 44pt minimum tap target")
    func compactButtonMinHeightExceedsTapTarget() {
        #expect(PitchComparisonScreen.buttonMinHeight(isCompact: true) >= 44)
    }

    // MARK: - Help Sections (Story 37.3)

    @Test("helpSections returns five sections for comparison training")
    func helpSectionsCount() async {
        #expect(PitchComparisonScreen.helpSections.count == 5)
    }

    @Test("help section titles match expected order")
    func helpSectionTitlesOrder() async {
        let expectedTitles = [
            String(localized: "Goal"),
            String(localized: "Controls"),
            String(localized: "Feedback"),
            String(localized: "Difficulty"),
            String(localized: "Intervals"),
        ]
        let actualTitles = PitchComparisonScreen.helpSections.map(\.title)
        #expect(actualTitles == expectedTitles)
    }

    @Test("each help section has a non-empty body")
    func helpSectionBodiesNonEmpty() async {
        for section in PitchComparisonScreen.helpSections {
            #expect(!section.body.isEmpty, "Section '\(section.title)' has empty body")
        }
    }

    @Test("intervals help section explains interval training")
    func intervalsHelpContainsKeyTerms() async {
        let intervalsTitle = String(localized: "Intervals")
        let intervalsSection = PitchComparisonScreen.helpSections.first { $0.title == intervalsTitle }
        #expect(intervalsSection != nil)
        let body = intervalsSection?.body.lowercased() ?? ""
        #expect(body.contains("interval"))
    }
}

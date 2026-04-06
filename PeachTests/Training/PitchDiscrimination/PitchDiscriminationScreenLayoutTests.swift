import Testing
import SwiftUI
@testable import Peach

/// Tests for PitchDiscriminationScreen layout adaptation based on vertical size class (Story 7.3)
@Suite("PitchDiscriminationScreen Layout Tests")
struct PitchDiscriminationScreenLayoutTests {

    // MARK: - Button Icon Size

    @Test("Button icon size is 60pt in compact mode")
    func buttonIconSizeCompact() async {
        #expect(PitchDiscriminationScreen.buttonIconSize(isCompact: true) == 60)
    }

    @Test("Button icon size is 80pt in regular mode")
    func buttonIconSizeRegular() async {
        #expect(PitchDiscriminationScreen.buttonIconSize(isCompact: false) == 80)
    }

    // MARK: - Button Min Height

    @Test("Button min height is 120pt in compact mode")
    func buttonMinHeightCompact() async {
        #expect(PitchDiscriminationScreen.buttonMinHeight(isCompact: true) == 120)
    }

    @Test("Button min height is 200pt in regular mode")
    func buttonMinHeightRegular() async {
        #expect(PitchDiscriminationScreen.buttonMinHeight(isCompact: false) == 200)
    }

    // MARK: - Button Text Font

    @Test("Button text font is title2 in compact mode")
    func buttonTextFontCompact() async {
        #expect(PitchDiscriminationScreen.buttonTextFont(isCompact: true) == .title2)
    }

    @Test("Button text font is title in regular mode")
    func buttonTextFontRegular() async {
        #expect(PitchDiscriminationScreen.buttonTextFont(isCompact: false) == .title)
    }

    // MARK: - Compact vs Regular Consistency

    @Test("All compact dimensions are smaller than regular dimensions")
    func compactDimensionsSmallerThanRegular() async {
        #expect(PitchDiscriminationScreen.buttonIconSize(isCompact: true) < PitchDiscriminationScreen.buttonIconSize(isCompact: false))
        #expect(PitchDiscriminationScreen.buttonMinHeight(isCompact: true) < PitchDiscriminationScreen.buttonMinHeight(isCompact: false))
    }

    @Test("Compact button min height exceeds 44pt minimum tap target")
    func compactButtonMinHeightExceedsTapTarget() async {
        #expect(PitchDiscriminationScreen.buttonMinHeight(isCompact: true) >= 44)
    }

    // MARK: - Help Sections (Story 37.3)

    @Test("helpSections returns five sections for comparison training")
    func helpSectionsCount() async {
        #expect(PitchDiscriminationScreen.helpSections.count == 5)
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
        let actualTitles = PitchDiscriminationScreen.helpSections.map(\.title)
        #expect(actualTitles == expectedTitles)
    }

    @Test("each help section has a non-empty body")
    func helpSectionBodiesNonEmpty() async {
        for section in PitchDiscriminationScreen.helpSections {
            #expect(!section.body.isEmpty, "Section '\(section.title)' has empty body")
        }
    }

    @Test("intervals help section explains interval training")
    func intervalsHelpContainsKeyTerms() async {
        let intervalsTitle = String(localized: "Intervals")
        let intervalsSection = PitchDiscriminationScreen.helpSections.first { $0.title == intervalsTitle }
        #expect(intervalsSection != nil)
        let body = intervalsSection?.body.lowercased() ?? ""
        #expect(body.contains("interval"))
    }
}

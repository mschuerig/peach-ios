import Testing
@testable import Peach

@Suite("ContinuousRhythmMatchingScreen")
struct ContinuousRhythmMatchingScreenTests {

    // MARK: - Layout Parameters

    @Test("compact button icon size is smaller than regular")
    func compactButtonIconSize() async {
        #expect(ContinuousRhythmMatchingScreen.buttonIconSize(isCompact: true) <
                ContinuousRhythmMatchingScreen.buttonIconSize(isCompact: false))
    }

    @Test("compact button min height is smaller than regular")
    func compactButtonMinHeight() async {
        #expect(ContinuousRhythmMatchingScreen.buttonMinHeight(isCompact: true) <
                ContinuousRhythmMatchingScreen.buttonMinHeight(isCompact: false))
    }

    @Test("compact button text font differs from regular")
    func compactButtonTextFont() async {
        #expect(ContinuousRhythmMatchingScreen.buttonTextFont(isCompact: true) !=
                ContinuousRhythmMatchingScreen.buttonTextFont(isCompact: false))
    }

    // MARK: - Help Sections

    @Test("has three help sections")
    func helpSectionCount() async {
        #expect(ContinuousRhythmMatchingScreen.helpSections.count == 3)
    }

    @Test("help sections have Goal, Controls, Feedback titles")
    func helpSectionTitles() async {
        let titles = ContinuousRhythmMatchingScreen.helpSections.map(\.title)
        #expect(titles.contains(String(localized: "Goal")))
        #expect(titles.contains(String(localized: "Controls")))
        #expect(titles.contains(String(localized: "Feedback")))
    }

    // MARK: - Stats Formatting

    @Test("hitRateText formats percentage correctly")
    func hitRateText() async {
        #expect(ContinuousRhythmMatchingScreen.hitRateText(75.0) == "75%")
    }

    @Test("hitRateText rounds to nearest integer")
    func hitRateTextRounding() async {
        #expect(ContinuousRhythmMatchingScreen.hitRateText(83.7) == "84%")
    }

    @Test("cycleProgressText shows count out of 16")
    func cycleProgressText() async {
        #expect(ContinuousRhythmMatchingScreen.cycleProgressText(4) == "4/16")
    }
}

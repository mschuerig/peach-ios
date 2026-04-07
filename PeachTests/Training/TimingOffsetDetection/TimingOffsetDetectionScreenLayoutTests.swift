import Testing
import SwiftUI
@testable import Peach

@Suite("TimingOffsetDetectionScreen Layout Tests")
struct TimingOffsetDetectionScreenLayoutTests {

    // MARK: - Button Icon Size

    @Test("button icon size is 60pt in compact mode")
    func buttonIconSizeCompact() async {
        #expect(TimingOffsetDetectionScreen.buttonIconSize(isCompact: true) == 60)
    }

    @Test("button icon size is 80pt in regular mode")
    func buttonIconSizeRegular() async {
        #expect(TimingOffsetDetectionScreen.buttonIconSize(isCompact: false) == 80)
    }

    // MARK: - Button Min Height

    @Test("button min height is 120pt in compact mode")
    func buttonMinHeightCompact() async {
        #expect(TimingOffsetDetectionScreen.buttonMinHeight(isCompact: true) == 120)
    }

    @Test("button min height is 200pt in regular mode")
    func buttonMinHeightRegular() async {
        #expect(TimingOffsetDetectionScreen.buttonMinHeight(isCompact: false) == 200)
    }

    // MARK: - Button Text Font

    @Test("button text font is title2 in compact mode")
    func buttonTextFontCompact() async {
        #expect(TimingOffsetDetectionScreen.buttonTextFont(isCompact: true) == .title2)
    }

    @Test("button text font is title in regular mode")
    func buttonTextFontRegular() async {
        #expect(TimingOffsetDetectionScreen.buttonTextFont(isCompact: false) == .title)
    }

    // MARK: - Compact vs Regular Consistency

    @Test("all compact dimensions are smaller than regular dimensions")
    func compactDimensionsSmallerThanRegular() async {
        #expect(TimingOffsetDetectionScreen.buttonIconSize(isCompact: true) < TimingOffsetDetectionScreen.buttonIconSize(isCompact: false))
        #expect(TimingOffsetDetectionScreen.buttonMinHeight(isCompact: true) < TimingOffsetDetectionScreen.buttonMinHeight(isCompact: false))
    }

    @Test("compact button min height exceeds 44pt minimum tap target")
    func compactButtonMinHeightExceedsTapTarget() async {
        #expect(TimingOffsetDetectionScreen.buttonMinHeight(isCompact: true) >= 44)
    }

    // canAcceptAnswer is tested via TimingOffsetDetectionSessionTests

    // MARK: - Feedback Animation

    @Test("feedback animation returns nil when reduce motion enabled")
    func feedbackAnimationReduceMotion() async {
        #expect(TimingOffsetDetectionScreen.feedbackAnimation(reduceMotion: true) == nil)
    }

    @Test("feedback animation returns non-nil when reduce motion disabled")
    func feedbackAnimationNormal() async {
        #expect(TimingOffsetDetectionScreen.feedbackAnimation(reduceMotion: false) != nil)
    }

    // MARK: - Help Sections

    @Test("helpSections returns four sections for rhythm training")
    func helpSectionsCount() async {
        #expect(HelpContent.timingOffsetDetection.count == 4)
    }

    @Test("help section titles match expected order")
    func helpSectionTitlesOrder() async {
        let expectedTitles = [
            String(localized: "Goal"),
            String(localized: "Controls"),
            String(localized: "Feedback"),
            String(localized: "Difficulty"),
        ]
        let actualTitles = HelpContent.timingOffsetDetection.map(\.title)
        #expect(actualTitles == expectedTitles)
    }

    @Test("each help section has a non-empty body")
    func helpSectionBodiesNonEmpty() async {
        for section in HelpContent.timingOffsetDetection {
            #expect(!section.body.isEmpty, "Section '\(section.title)' has empty body")
        }
    }
}

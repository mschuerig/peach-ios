import Testing
import SwiftUI
@testable import Peach

@Suite("RhythmOffsetDetectionScreen Layout Tests")
struct RhythmOffsetDetectionScreenLayoutTests {

    // MARK: - Button Icon Size

    @Test("button icon size is 60pt in compact mode")
    func buttonIconSizeCompact() async {
        #expect(RhythmOffsetDetectionScreen.buttonIconSize(isCompact: true) == 60)
    }

    @Test("button icon size is 80pt in regular mode")
    func buttonIconSizeRegular() async {
        #expect(RhythmOffsetDetectionScreen.buttonIconSize(isCompact: false) == 80)
    }

    // MARK: - Button Min Height

    @Test("button min height is 120pt in compact mode")
    func buttonMinHeightCompact() async {
        #expect(RhythmOffsetDetectionScreen.buttonMinHeight(isCompact: true) == 120)
    }

    @Test("button min height is 200pt in regular mode")
    func buttonMinHeightRegular() async {
        #expect(RhythmOffsetDetectionScreen.buttonMinHeight(isCompact: false) == 200)
    }

    // MARK: - Button Text Font

    @Test("button text font is title2 in compact mode")
    func buttonTextFontCompact() async {
        #expect(RhythmOffsetDetectionScreen.buttonTextFont(isCompact: true) == .title2)
    }

    @Test("button text font is title in regular mode")
    func buttonTextFontRegular() async {
        #expect(RhythmOffsetDetectionScreen.buttonTextFont(isCompact: false) == .title)
    }

    // MARK: - Compact vs Regular Consistency

    @Test("all compact dimensions are smaller than regular dimensions")
    func compactDimensionsSmallerThanRegular() async {
        #expect(RhythmOffsetDetectionScreen.buttonIconSize(isCompact: true) < RhythmOffsetDetectionScreen.buttonIconSize(isCompact: false))
        #expect(RhythmOffsetDetectionScreen.buttonMinHeight(isCompact: true) < RhythmOffsetDetectionScreen.buttonMinHeight(isCompact: false))
    }

    @Test("compact button min height exceeds 44pt minimum tap target")
    func compactButtonMinHeightExceedsTapTarget() async {
        #expect(RhythmOffsetDetectionScreen.buttonMinHeight(isCompact: true) >= 44)
    }

    // canAcceptAnswer is tested via RhythmOffsetDetectionSessionTests

    // MARK: - Feedback Animation

    @Test("feedback animation returns nil when reduce motion enabled")
    func feedbackAnimationReduceMotion() async {
        #expect(RhythmOffsetDetectionScreen.feedbackAnimation(reduceMotion: true) == nil)
    }

    @Test("feedback animation returns non-nil when reduce motion disabled")
    func feedbackAnimationNormal() async {
        #expect(RhythmOffsetDetectionScreen.feedbackAnimation(reduceMotion: false) != nil)
    }

    // MARK: - Help Sections

    @Test("helpSections returns four sections for rhythm training")
    func helpSectionsCount() async {
        #expect(RhythmOffsetDetectionScreen.helpSections.count == 4)
    }

    @Test("help section titles match expected order")
    func helpSectionTitlesOrder() async {
        let expectedTitles = [
            String(localized: "Goal"),
            String(localized: "Controls"),
            String(localized: "Feedback"),
            String(localized: "Difficulty"),
        ]
        let actualTitles = RhythmOffsetDetectionScreen.helpSections.map(\.title)
        #expect(actualTitles == expectedTitles)
    }

    @Test("each help section has a non-empty body")
    func helpSectionBodiesNonEmpty() async {
        for section in RhythmOffsetDetectionScreen.helpSections {
            #expect(!section.body.isEmpty, "Section '\(section.title)' has empty body")
        }
    }
}

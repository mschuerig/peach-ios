import Testing
@testable import Peach

@Suite("PitchMatchingScreen")
struct PitchMatchingScreenTests {

    // MARK: - feedbackAnimation

    @Test("feedbackAnimation returns nil when Reduce Motion is enabled")
    func feedbackAnimationReturnsNilForReduceMotion() async {
        #expect(PitchMatchingScreen.feedbackAnimation(reduceMotion: true) == nil)
    }

    @Test("feedbackAnimation returns animation when Reduce Motion is disabled")
    func feedbackAnimationReturnsAnimationNormally() async {
        #expect(PitchMatchingScreen.feedbackAnimation(reduceMotion: false) != nil)
    }

    // MARK: - Help Sections (Story 37.3)

    @Test("helpSections returns four sections for pitch matching training")
    func helpSectionsCount() async {
        #expect(HelpContent.pitchMatching.count == 4)
    }

    @Test("help section titles match expected order")
    func helpSectionTitlesOrder() async {
        let expectedTitles = [
            String(localized: "Goal"),
            String(localized: "Controls"),
            String(localized: "Feedback"),
            String(localized: "Intervals"),
        ]
        let actualTitles = HelpContent.pitchMatching.map(\.title)
        #expect(actualTitles == expectedTitles)
    }

    @Test("each help section has a non-empty body")
    func helpSectionBodiesNonEmpty() async {
        for section in HelpContent.pitchMatching {
            #expect(!section.body.isEmpty, "Section '\(section.title)' has empty body")
        }
    }

    @Test("intervals help section explains interval training")
    func intervalsHelpContainsKeyTerms() async {
        let intervalsTitle = String(localized: "Intervals")
        let intervalsSection = HelpContent.pitchMatching.first { $0.title == intervalsTitle }
        #expect(intervalsSection != nil)
        let body = intervalsSection?.body.lowercased() ?? ""
        #expect(body.contains("interval"))
    }
}

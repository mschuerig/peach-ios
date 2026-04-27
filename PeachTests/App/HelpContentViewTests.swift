import Testing
@testable import Peach

@Suite("HelpContentView Tests")
struct HelpContentViewTests {

    init() {
        TrainingDisciplineRegistry._replaceSharedForTesting(disciplines: DisciplineBootstrap.allDisciplines)
    }

    @Test("HelpSection can be instantiated with title and body")
    func helpSectionCanBeInstantiated() async {
        let section = HelpSection(title: "Test Title", body: "Test body text")
        #expect(section.title == "Test Title")
        #expect(section.body == "Test body text")
    }

    @Test("HelpContentView can be instantiated with sections")
    func helpContentViewCanBeInstantiated() async {
        let sections = [
            HelpSection(title: "First", body: "First body"),
            HelpSection(title: "Second", body: "Second body"),
        ]
        _ = HelpContentView(sections: sections)
    }

    @Test("HelpContentView can be instantiated with Markdown content")
    func helpContentViewHandlesMarkdown() async {
        let sections = [
            HelpSection(title: "Links", body: "Visit [example](https://example.com)."),
            HelpSection(title: "Bold", body: "This is **bold** text."),
        ]
        _ = HelpContentView(sections: sections)
    }

    @Test("InfoScreen acknowledgments sections has one section")
    func acknowledgmentsSectionsHasOneSection() async {
        #expect(HelpContent.acknowledgments.count == 1)
    }

    @Test("InfoScreen acknowledgments text contains SoundFont URL")
    func acknowledgmentsTextContainsSoundFontURL() async {
        #expect(HelpContent.acknowledgmentsText.contains("schristiancollins.com"))
    }

    // MARK: - Identifiable Conformance

    @Test("HelpSection conforms to Identifiable with stable UUID")
    func helpSectionIsIdentifiable() async {
        let section = HelpSection(title: "Test", body: "Body")
        let id1 = section.id
        let id2 = section.id
        #expect(id1 == id2)
    }

    @Test("Two HelpSections have distinct IDs")
    func helpSectionsHaveDistinctIDs() async {
        let a = HelpSection(title: "Same", body: "Body")
        let b = HelpSection(title: "Same", body: "Body")
        #expect(a.id != b.id)
    }

    // MARK: - Cached Attributed String

    @Test("attributedBody returns non-nil for valid markdown")
    func attributedBodyParsesMarkdown() async {
        let section = HelpSection(title: "T", body: "This is **bold**")
        #expect(section.attributedBody != nil)
    }

    @Test("attributedBody is pre-parsed at init and stable")
    func attributedBodyIsPreParsed() async {
        let section = HelpSection(title: "T", body: "This is **bold**")
        let first = section.attributedBody
        let second = section.attributedBody
        #expect(first == second)
    }

    @Test("attributedBody returns nil for empty string")
    func attributedBodyHandlesEmptyString() async {
        let section = HelpSection(title: "T", body: "")
        // Empty string should still parse successfully as AttributedString
        // (AttributedString(markdown: "") succeeds)
        #expect(section.attributedBody != nil)
    }

    // MARK: - Contribution-driven assembly

    @Test("settingsHelpSections contains a Rhythm section iff a discipline contributes a Rhythm-titled help section")
    func settingsRhythmHelpFollowsContribution() async {
        let rhythmTitle = String(localized: "Rhythm")
        let titles = HelpContent.settingsHelpSections().map(\.title)
        let hasRhythmHelp = titles.contains(rhythmTitle)
        let contributed = TrainingDisciplineRegistry.shared.allUI
            .flatMap(\.settingsHelp)
            .contains { $0.title == rhythmTitle }
        #expect(hasRhythmHelp == contributed)
    }

    @Test("profileHelpSections contains spectrogram help iff a discipline contributes it")
    func profileSpectrogramHelpFollowsContribution() async {
        let spectrogramTitle = String(localized: "Rhythm Spectrogram",
                                       comment: "Spectrogram overview help title")
        let titles = HelpContent.profileHelpSections().map(\.title)
        let hasSpectrogramHelp = titles.contains(spectrogramTitle)
        let contributed = TrainingDisciplineRegistry.shared.allUI
            .flatMap(\.profileHelp)
            .contains { $0.title == spectrogramTitle }
        #expect(hasSpectrogramHelp == contributed)
    }

    @Test("settingsHelpSections always begins with the common sections and ends with Data")
    func settingsHelpHasCommonAndDataAnchors() async {
        let sections = HelpContent.settingsHelpSections()
        let titles = sections.map(\.title)
        #expect(titles.first == String(localized: "Training Range"))
        #expect(titles.last == String(localized: "Data"))
    }

    @Test("settingsHelpSections drops contributed sections when no discipline contributes")
    func settingsHelpFollowsEmptyContribution() {
        let pitchOnly: [any TrainingDiscipline] = [UnisonPitchDiscriminationDiscipline()]
        TrainingDisciplineRegistry._withSharedReplacedForTesting(disciplines: pitchOnly) {
            let titles = HelpContent.settingsHelpSections().map(\.title)
            #expect(!titles.contains(String(localized: "Rhythm")))
            #expect(!titles.contains(String(localized: "Gap Positions")))
        }
    }

    @Test("profileHelpSections drops spectrogram help when no discipline contributes")
    func profileHelpFollowsEmptyContribution() {
        let pitchOnly: [any TrainingDiscipline] = [UnisonPitchDiscriminationDiscipline()]
        TrainingDisciplineRegistry._withSharedReplacedForTesting(disciplines: pitchOnly) {
            let titles = HelpContent.profileHelpSections().map(\.title)
            let spectrogramTitle = String(localized: "Rhythm Spectrogram",
                                          comment: "Spectrogram overview help title")
            #expect(!titles.contains(spectrogramTitle))
        }
    }
}

import Testing
@testable import Peach

@Suite("HelpContentView Tests")
struct HelpContentViewTests {

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
        #expect(InfoScreen.acknowledgmentsSections.count == 1)
    }

    @Test("InfoScreen acknowledgments text contains SoundFont URL")
    func acknowledgmentsTextContainsSoundFontURL() async {
        #expect(InfoScreen.acknowledgmentsText.contains("schristiancollins.com"))
    }
}

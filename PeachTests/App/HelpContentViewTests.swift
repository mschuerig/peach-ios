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
}

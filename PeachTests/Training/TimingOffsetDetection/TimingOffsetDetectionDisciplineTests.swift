import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionDiscipline UI contribution")
struct TimingOffsetDetectionDisciplineTests {

    @Test("settingsSections contributes the shared tempo section, the offset-note-position section, and the max-repetitions section, in that order")
    func settingsSectionsContainAllEntriesInOrder() {
        let discipline = TimingOffsetDetectionDiscipline()

        let ids = discipline.settingsSections.map(\.id)

        #expect(ids == [SharedRhythmSectionID.tempo, "tod.offsetNotePosition", "tod.maxRepetitions"])
    }

    @Test("settingsHelp concatenates the inherited tempo help, the offset-note-position help, and the max-repetitions help")
    func settingsHelpConcatenatesAllSections() {
        let discipline = TimingOffsetDetectionDiscipline()

        let titles = discipline.settingsHelp.map(\.title)
        let expectedTitles = (ContinuousRhythmMatchingHelp.tempoSettingsHelp
                              + TimingOffsetDetectionHelp.offsetNotePositionSettingsHelp
                              + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp).map(\.title)

        #expect(titles == expectedTitles)
        #expect(titles.count == ContinuousRhythmMatchingHelp.tempoSettingsHelp.count
                              + TimingOffsetDetectionHelp.offsetNotePositionSettingsHelp.count
                              + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp.count)
    }
}
#endif

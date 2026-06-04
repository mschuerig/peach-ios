import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionDiscipline UI contribution")
struct TimingOffsetDetectionDisciplineTests {

    @Test("settingsSections contributes tempo, pattern picker, offset-note-position, max-repetitions, in that order")
    func settingsSectionsContainAllEntriesInOrder() {
        let discipline = TimingOffsetDetectionDiscipline()

        let ids = discipline.settingsSections.map(\.id)

        #expect(ids == [
            SharedRhythmSectionID.tempo,
            "tod.patternPicker",
            "tod.offsetNotePosition",
            "tod.maxRepetitions",
        ])
    }

    @Test("settingsHelp concatenates tempo, pattern picker, offset-note-position, and max-repetitions help")
    func settingsHelpConcatenatesAllSections() {
        let discipline = TimingOffsetDetectionDiscipline()

        let titles = discipline.settingsHelp.map(\.title)
        let expectedTitles = (ContinuousRhythmMatchingHelp.tempoSettingsHelp
                              + TimingOffsetDetectionHelp.patternPickerSettingsHelp
                              + TimingOffsetDetectionHelp.offsetNotePositionSettingsHelp
                              + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp).map(\.title)

        #expect(titles == expectedTitles)
        #expect(titles.count == ContinuousRhythmMatchingHelp.tempoSettingsHelp.count
                              + TimingOffsetDetectionHelp.patternPickerSettingsHelp.count
                              + TimingOffsetDetectionHelp.offsetNotePositionSettingsHelp.count
                              + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp.count)
    }
}
#endif

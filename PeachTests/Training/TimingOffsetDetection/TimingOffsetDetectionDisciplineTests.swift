import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionDiscipline UI contribution")
struct TimingOffsetDetectionDisciplineTests {

    @Test("settingsSections contributes the shared tempo section and the TOD max-repetitions section, in that order")
    func settingsSectionsContainBothEntriesInOrder() {
        let discipline = TimingOffsetDetectionDiscipline()

        let ids = discipline.settingsSections.map(\.id)

        #expect(ids == [SharedRhythmSectionID.tempo, "tod.maxRepetitions"])
    }

    @Test("settingsHelp concatenates the inherited tempo help and the TOD max-repetitions help")
    func settingsHelpConcatenatesTempoAndMaxRepetitions() {
        let discipline = TimingOffsetDetectionDiscipline()

        let titles = discipline.settingsHelp.map(\.title)
        let expectedTitles = (ContinuousRhythmMatchingHelp.tempoSettingsHelp
                              + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp).map(\.title)

        #expect(titles == expectedTitles)
        #expect(titles.count == ContinuousRhythmMatchingHelp.tempoSettingsHelp.count
                              + TimingOffsetDetectionHelp.maxRepetitionsSettingsHelp.count)
    }
}
#endif

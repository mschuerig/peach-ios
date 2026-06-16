import Testing
import Foundation
@testable import Peach

/// Aggregation contract for the help sheet shown by ``SettingsScreen``: the
/// common sections come first, then each registered discipline's
/// ``TrainingDisciplineUI/settingsHelp`` in registration order, then the
/// trailing Data section. Owned by Story 77.2.
@Suite("Settings help — discipline aggregation")
struct SettingsScreenAggregationTests {

    @Test("with no per-discipline help, common sections render and end with Data")
    func emptyContributionsYieldCommonSectionsPlusData() {
        TrainingDisciplineRegistry.withOverride(
            disciplines: [
                SyntheticUIDiscipline(id: TrainingDisciplineID("p"), category: .pitch),
            ]
        ) {
            let titles = HelpContent.settingsHelpSections().map(\.title)
            #expect(titles.first == String(localized: "Training Range"))
            #expect(titles.last == String(localized: "Data"))
            #expect(titles.contains(where: { $0 == "Tempo" || $0 == "Gap" }) == false)
        }
    }

    @Test("per-discipline settings help renders between the common sections and the Data section")
    func contributedSectionsRenderBetweenCommonAndData() {
        TrainingDisciplineRegistry.withOverride(
            disciplines: [
                SyntheticUIDiscipline(
                    id: TrainingDisciplineID("rhythm"),
                    category: .rhythm,
                    ownSettingsHelp: [
                        HelpSection(title: "Tempo", body: ""),
                        HelpSection(title: "Gap", body: ""),
                    ]
                ),
            ]
        ) {
            let titles = HelpContent.settingsHelpSections().map(\.title)
            let dataIdx = titles.firstIndex(of: String(localized: "Data"))!
            let tempoIdx = titles.firstIndex(of: "Tempo")!
            let gapIdx = titles.firstIndex(of: "Gap")!
            #expect(tempoIdx < gapIdx)
            #expect(gapIdx < dataIdx)
        }
    }

    @Test("ordering of per-discipline help follows registration order")
    func contributedOrderFollowsRegistrationOrder() {
        TrainingDisciplineRegistry.withOverride(
            disciplines: [
                SyntheticUIDiscipline(
                    id: TrainingDisciplineID("first"),
                    category: .rhythm,
                    ownSettingsHelp: [HelpSection(title: "First", body: "")]
                ),
                SyntheticUIDiscipline(
                    id: TrainingDisciplineID("second"),
                    category: .pitch,
                    ownSettingsHelp: [HelpSection(title: "Second", body: "")]
                ),
            ]
        ) {
            let titles = HelpContent.settingsHelpSections().map(\.title)
            #expect(titles.firstIndex(of: "First")! < titles.firstIndex(of: "Second")!)
        }
    }

    @Test("profile help aggregates common sections plus per-discipline profileHelp")
    func profileHelpAggregatesCommonAndDiscipline() {
        TrainingDisciplineRegistry.withOverride(
            disciplines: [
                SyntheticUIDiscipline(
                    id: TrainingDisciplineID("rhythm"),
                    category: .rhythm,
                    ownProfileHelp: [HelpSection(title: "Spectrogram", body: "")]
                ),
            ]
        ) {
            let titles = HelpContent.profileHelpSections().map(\.title)
            #expect(titles.first == String(localized: "Your Progress Chart"))
            #expect(titles.contains("Spectrogram"))
        }
    }
}

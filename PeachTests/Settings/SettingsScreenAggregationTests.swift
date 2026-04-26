import Testing
import Foundation
@testable import Peach

@Suite("SettingsScreen — section aggregation")
struct SettingsScreenAggregationTests {

    // MARK: - Helper math

    @Test("with no contributions, common sections + Data render in order")
    func emptyContributionsYieldsCommonSectionsPlusData() {
        #expect(
            SettingsScreen.orderedSectionIdentifiers(contributions: []) == [
                .trainingRange,
                .intervals,
                .sound,
                .difficulty,
                .data,
            ]
        )
    }

    @Test("contributed sections appear after Difficulty and before Data")
    func contributedSectionsRenderBetweenDifficultyAndData() {
        let actual = SettingsScreen.orderedSectionIdentifiers(
            contributions: [.rhythmTempo, .rhythmGapPositions]
        )
        #expect(actual == [
            .trainingRange,
            .intervals,
            .sound,
            .difficulty,
            .contributed(.rhythmTempo),
            .contributed(.rhythmGapPositions),
            .data,
        ])
    }

    @Test("contributed-section ordering follows the input list verbatim")
    func contributedOrderFollowsInputList() {
        let actual = SettingsScreen.orderedSectionIdentifiers(
            contributions: [.rhythmGapPositions, .rhythmTempo]
        )
        #expect(Array(actual.dropFirst(4).dropLast()) == [
            .contributed(.rhythmGapPositions),
            .contributed(.rhythmTempo),
        ])
    }

    // MARK: - Wiring through the shared registry

    @Test("SettingsScreen reads contributions from the shared registry")
    func screenConsumesSharedRegistryContributions() {
        TrainingDisciplineRegistry._withSharedReplacedForTesting(
            disciplines: [
                SyntheticDiscipline(
                    id: TrainingDisciplineID("r1"),
                    category: .rhythm,
                    settingsContributions: [.rhythmTempo, .rhythmGapPositions]
                ),
            ]
        ) {
            let identifiers = SettingsScreen.orderedSectionIdentifiers(
                contributions: TrainingDisciplineRegistry.shared.settingsSectionContributions
            )
            #expect(identifiers == [
                .trainingRange,
                .intervals,
                .sound,
                .difficulty,
                .contributed(.rhythmTempo),
                .contributed(.rhythmGapPositions),
                .data,
            ])
        }
    }

    @Test("a synthetic subset with no settings contributions yields no contributed sections")
    func syntheticSubsetWithNoContributionsYieldsNoContributed() {
        TrainingDisciplineRegistry._withSharedReplacedForTesting(
            disciplines: [
                SyntheticDiscipline(id: TrainingDisciplineID("p"), category: .pitch),
            ]
        ) {
            let identifiers = SettingsScreen.orderedSectionIdentifiers(
                contributions: TrainingDisciplineRegistry.shared.settingsSectionContributions
            )
            #expect(identifiers == [
                .trainingRange,
                .intervals,
                .sound,
                .difficulty,
                .data,
            ])
        }
    }
}

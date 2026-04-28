import Testing
import Foundation
import SwiftUI
@testable import Peach

/// Synthetic UI-conforming discipline for exercising the
/// ``TrainingDisciplineUI`` contract over arbitrary subsets without
/// depending on the real bootstrap list.
struct SyntheticUIDiscipline: TrainingDisciplineUI, Sendable {
    let id: TrainingDisciplineID
    let category: TrainingCategory
    var isHero: Bool = false
    var ownSettingsHelp: [HelpSection] = []
    var ownProfileHelp: [HelpSection] = []
    var ownSettingsSectionIDs: [String] = []

    var config: TrainingDisciplineConfig {
        TrainingDisciplineConfig(
            displayName: id.slug,
            shortLabel: id.slug,
            systemImageName: "questionmark",
            isHero: isHero,
            helpDescription: "",
            unitLabel: "u",
            optimalBaseline: 0,
            statistics: .default
        )
    }

    var statisticsKeys: [StatisticsKey] { [.pitch(id)] }
    var helpSections: [HelpSection] { [] }
    var navigationDestination: NavigationDestination { .profile }
    var csvTrainingType: String { id.slug }
    var csvColumns: [String] { ["__synthetic_\(id.slug)"] }
    var csvHistory: CSVHistory {
        CSVHistory(entries: [
            CSVHistoryEntry(version: 1, trainingType: id.slug, columns: ["__synthetic_\(id.slug)"]),
        ])
    }

    var settingsHelp: [HelpSection] { ownSettingsHelp }
    var profileHelp: [HelpSection] { ownProfileHelp }
    var settingsSections: [DisciplineSettingsSection] {
        ownSettingsSectionIDs.map { sectionID in
            DisciplineSettingsSection(id: sectionID) { EmptyView() }
        }
    }

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {}
    func csvKeyValuePairs(for payload: any TrainingDisciplinePayload) -> [(String, String)] { [] }
    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<(timestamp: Date, payload: any TrainingDisciplinePayload), CSVImportError> {
        .failure(.invalidRowData(row: rowNumber, column: "synthetic", value: "", reason: "synthetic"))
    }
    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] { [] }
    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [(timestamp: Date, payload: any TrainingDisciplinePayload)] { [] }
    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) { (0, 0) }
}

/// Contract for the plugin-style ``TrainingDisciplineUI`` model introduced
/// by Story 77.2: each discipline owns its UI surfaces, the registry
/// exposes them via ``TrainingDisciplineRegistry/allUI`` in registration
/// order, and aggregating screens iterate that list directly.
@Suite("TrainingDisciplineRegistry — UI contributions")
struct RegistryContributionsTests {

    // MARK: - allUI shape

    @Test("allUI returns registered disciplines in registration order")
    func allUIPreservesRegistrationOrder() {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticUIDiscipline(id: TrainingDisciplineID("first"), category: .pitch),
            SyntheticUIDiscipline(id: TrainingDisciplineID("second"), category: .rhythm),
            SyntheticUIDiscipline(id: TrainingDisciplineID("third"), category: .intervals),
        ])
        let ids = registry.allUI.map(\.id.slug)
        #expect(ids == ["first", "second", "third"])
    }

    @Test("allUI includes every UI-conforming discipline registered")
    func allUIMatchesAllForUIConformingDisciplines() {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticUIDiscipline(id: TrainingDisciplineID("a"), category: .pitch),
            SyntheticUIDiscipline(id: TrainingDisciplineID("b"), category: .pitch),
        ])
        #expect(registry.allUI.map(\.id) == registry.all.map(\.id))
    }

    // MARK: - Default behavior

    @Test("a discipline that overrides nothing yields empty settingsHelp and profileHelp")
    func defaultsAreEmpty() {
        let d = SyntheticUIDiscipline(id: TrainingDisciplineID("d"), category: .pitch)
        #expect(d.settingsHelp.isEmpty)
        #expect(d.profileHelp.isEmpty)
    }

    // MARK: - Override behavior

    @Test("a discipline's overridden settingsHelp surfaces verbatim through allUI")
    func overriddenSettingsHelpPreservedThroughAllUI() {
        let section = HelpSection(title: "Tempo", body: "BPM control")
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("rhythm"),
                category: .rhythm,
                ownSettingsHelp: [section]
            ),
        ])
        let collected = registry.allUI.flatMap(\.settingsHelp).map(\.title)
        #expect(collected == ["Tempo"])
    }

    @Test("a discipline's overridden profileHelp surfaces verbatim through allUI")
    func overriddenProfileHelpPreservedThroughAllUI() {
        let section = HelpSection(title: "Spectrogram", body: "Color grid")
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("rhythm"),
                category: .rhythm,
                ownProfileHelp: [section]
            ),
        ])
        let collected = registry.allUI.flatMap(\.profileHelp).map(\.title)
        #expect(collected == ["Spectrogram"])
    }

    @Test("only the disciplines that override contribute help; others stay silent")
    func onlyOverridingDisciplinesContribute() {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticUIDiscipline(id: TrainingDisciplineID("silent"), category: .pitch),
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("loud"),
                category: .rhythm,
                ownSettingsHelp: [HelpSection(title: "Tempo", body: "")]
            ),
            SyntheticUIDiscipline(id: TrainingDisciplineID("also-silent"), category: .intervals),
        ])
        let collected = registry.allUI.flatMap(\.settingsHelp).map(\.title)
        #expect(collected == ["Tempo"])
    }

    // MARK: - Subsets via the shared registry

    @Test("a pitch-only synthetic subset surfaces no help through the shared registry")
    func sharedRegistryReplacedWithPitchOnlySubsetEmitsNoHelp() {
        TrainingDisciplineRegistry._withSharedReplacedForTesting(
            disciplines: [
                SyntheticUIDiscipline(id: TrainingDisciplineID("p"), category: .pitch),
            ]
        ) {
            let settings = TrainingDisciplineRegistry.shared.allUI.flatMap(\.settingsHelp)
            let profile = TrainingDisciplineRegistry.shared.allUI.flatMap(\.profileHelp)
            #expect(settings.isEmpty)
            #expect(profile.isEmpty)
        }
    }

    @Test("a rhythm-only synthetic subset surfaces only its declared help through the shared registry")
    func sharedRegistryReplacedWithRhythmOnlySubsetEmitsOnlyDeclaredHelp() {
        TrainingDisciplineRegistry._withSharedReplacedForTesting(
            disciplines: [
                SyntheticUIDiscipline(
                    id: TrainingDisciplineID("r"),
                    category: .rhythm,
                    ownSettingsHelp: [HelpSection(title: "Gap", body: "")],
                    ownProfileHelp: [HelpSection(title: "Spectrogram", body: "")]
                ),
            ]
        ) {
            let settings = TrainingDisciplineRegistry.shared.allUI.flatMap(\.settingsHelp).map(\.title)
            let profile = TrainingDisciplineRegistry.shared.allUI.flatMap(\.profileHelp).map(\.title)
            #expect(settings == ["Gap"])
            #expect(profile == ["Spectrogram"])
        }
    }
}

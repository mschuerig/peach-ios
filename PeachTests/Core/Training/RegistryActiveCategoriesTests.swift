import Testing
import Foundation
import SwiftData
@testable import Peach

/// Synthetic discipline fixture for exercising registry algorithms over
/// arbitrary category mixes without depending on the real bootstrap list.
struct SyntheticDiscipline: TrainingDiscipline, Sendable {
    let id: TrainingDisciplineID
    let category: TrainingCategory
    var isHero: Bool = false

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

    var recordType: any PersistentModel.Type { PitchDiscriminationRecord.self }

    var helpSections: [HelpSection] { [] }

    var navigationDestination: NavigationDestination { .profile }

    var csvTrainingType: String { id.slug }

    var csvColumns: [String] { ["__synthetic_\(id.slug)"] }

    func feedRecords(from store: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {}

    func csvKeyValuePairs(for record: any PersistentModel) -> [(String, String)] { [] }

    func parseCSVRow(
        fields: [String],
        columnIndex: [String: Int],
        rowNumber: Int
    ) -> Result<any PersistentModel, CSVImportError> {
        .failure(.invalidRowData(row: rowNumber, column: "synthetic", value: "", reason: "synthetic"))
    }

    func fetchExportRecords(from store: TrainingDataStore) throws -> [(timestamp: Date, record: any PersistentModel)] { [] }

    func parsedRecords(from parseResult: CSVImportParser.ImportResult) -> [any PersistentModel] { [] }

    func mergeImportRecords(
        from parseResult: CSVImportParser.ImportResult,
        existingIn store: TrainingDataStore,
        into scope: TrainingDataStore.TransactionScope
    ) throws -> (imported: Int, skipped: Int) { (0, 0) }
}

@Suite("TrainingDisciplineRegistry — activeCategories and disciplines(in:)")
struct RegistryActiveCategoriesTests {

    private func make(_ entries: (slug: String, category: TrainingCategory)...) -> TrainingDisciplineRegistry {
        TrainingDisciplineRegistry(disciplines: entries.map {
            SyntheticDiscipline(id: TrainingDisciplineID($0.slug), category: $0.category)
        })
    }

    // MARK: - disciplines(in:)

    @Test("disciplines(in:) returns disciplines for the given category in registration order", arguments: [
        (TrainingCategory.pitch, ["a", "c", "g"]),
        (TrainingCategory.intervals, ["b", "f"]),
        (TrainingCategory.rhythm, ["d", "e"]),
    ])
    func disciplinesInPreservesRegistrationOrder(category: TrainingCategory, expected: [String]) async {
        let registry = make(
            ("a", .pitch),
            ("b", .intervals),
            ("c", .pitch),
            ("d", .rhythm),
            ("e", .rhythm),
            ("f", .intervals),
            ("g", .pitch)
        )
        let slugs = registry.disciplines(in: category).map(\.id.slug)
        #expect(slugs == expected)
    }

    @Test("disciplines(in:) returns empty for a category with no registrations")
    func disciplinesInEmptyForAbsentCategory() async {
        let registry = make(("a", .pitch))
        #expect(registry.disciplines(in: .rhythm).isEmpty)
        #expect(registry.disciplines(in: .intervals).isEmpty)
    }

    // MARK: - activeCategories

    @Test("activeCategories preserves TrainingCategory.allCases declaration order")
    func activeCategoriesInDeclarationOrder() async {
        let registry = make(
            ("a", .rhythm),
            ("b", .pitch),
            ("c", .intervals)
        )
        #expect(registry.activeCategories == TrainingCategory.allCases)
    }

    @Test("activeCategories deduplicates repeated categories")
    func activeCategoriesDeduplicates() async {
        let registry = make(
            ("a", .pitch),
            ("b", .pitch),
            ("c", .intervals),
            ("d", .intervals),
            ("e", .intervals)
        )
        #expect(registry.activeCategories == [.pitch, .intervals])
    }

    @Test("activeCategories omits categories with no registered disciplines")
    func activeCategoriesOmitsEmpty() async {
        let registry = make(("only", .pitch))
        #expect(registry.activeCategories == [.pitch])
    }

    @Test("activeCategories omits the rhythm category when no rhythm discipline is registered")
    func activeCategoriesOmitsRhythmWhenMissing() async {
        let registry = make(
            ("p", .pitch),
            ("i", .intervals)
        )
        #expect(!registry.activeCategories.contains(.rhythm))
    }

    @Test("activeCategories with a single rhythm discipline contains only rhythm")
    func activeCategoriesSingleRhythm() async {
        let registry = make(("only-rhythm", .rhythm))
        #expect(registry.activeCategories == [.rhythm])
    }
}

@Suite("TrainingDisciplineRegistry — hero cardinality")
struct RegistryHeroCardinalityTests {

    @Test("a single hero per category is accepted")
    func singleHeroPerCategoryAccepted() async {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticDiscipline(id: TrainingDisciplineID("p1"), category: .pitch, isHero: true),
            SyntheticDiscipline(id: TrainingDisciplineID("p2"), category: .pitch, isHero: false),
            SyntheticDiscipline(id: TrainingDisciplineID("i1"), category: .intervals, isHero: true),
        ])
        #expect(registry.all.count == 3)
    }

    @Test("zero heros in a category is accepted")
    func zeroHeroesAccepted() async {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticDiscipline(id: TrainingDisciplineID("p1"), category: .pitch, isHero: false),
            SyntheticDiscipline(id: TrainingDisciplineID("p2"), category: .pitch, isHero: false),
        ])
        #expect(registry.all.count == 2)
    }

    // Exit tests run the closure in a subprocess and observe its exit status.
    // Subprocess support is only available on macOS in our toolchain, so this
    // violation-path test is gated to macOS.
    #if os(macOS)
    @Test("two heros in the same category trip a precondition")
    func twoHeroesInSameCategoryTraps() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                _ = TrainingDisciplineRegistry(disciplines: [
                    SyntheticDiscipline(id: TrainingDisciplineID("a"), category: .pitch, isHero: true),
                    SyntheticDiscipline(id: TrainingDisciplineID("b"), category: .pitch, isHero: true),
                ])
            }
        }
    }
    #endif
}

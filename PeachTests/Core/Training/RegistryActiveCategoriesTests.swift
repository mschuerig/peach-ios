import Testing
import Foundation
@testable import Peach

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

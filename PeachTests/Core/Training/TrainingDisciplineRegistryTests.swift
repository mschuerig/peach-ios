import Testing
import Foundation
@testable import Peach

@Suite("TrainingDisciplineRegistry")
struct TrainingDisciplineRegistryTests {

    private let registry = TrainingDisciplineRegistry(disciplines: DisciplineBootstrap.allDisciplines)

    // MARK: - Registered-set invariants
    //
    // The registered set varies by build configuration: every configuration
    // registers the four pitch disciplines plus Timing Offset Detection, and the
    // Research configurations additionally register the research-only
    // disciplines (Continuous Rhythm Matching and Chromatic Construction).
    // Tests below assert set membership rather than exact counts, so adding a
    // discipline does not break them — but the shipping set is pinned from both
    // sides, because the App Store copy enumerates exactly those five.

    @Test("the pitch disciplines and Timing Offset Detection are always registered")
    func shippingDisciplinesAlwaysRegistered() async {
        let registeredIDs = Set(registry.all.map(\.id))
        let alwaysOn: Set<TrainingDisciplineID> = [
            .unisonPitchDiscrimination,
            .intervalPitchDiscrimination,
            .unisonPitchMatching,
            .intervalPitchMatching,
            .timingOffsetDetection,
        ]
        #expect(alwaysOn.isSubset(of: registeredIDs))
    }

    #if !PEACH_RESEARCH
    /// Guards the upper bound of the shipping set. `alwaysOn` above is a subset
    /// assertion, so a research-only discipline escaping the `#if
    /// PEACH_RESEARCH` block in `DisciplineBootstrap` would register in a
    /// shipping build with every scheme still green — while the App Store
    /// description and App Review Notes promise exactly five disciplines.
    @Test("research-only disciplines are absent from the shipping build")
    func researchDisciplinesAbsentFromShippingBuild() async {
        let registeredIDs = Set(registry.all.map(\.id))
        let researchOnly: Set<TrainingDisciplineID> = [
            .continuousRhythmMatching,
            .chromaticConstruction,
        ]
        #expect(registeredIDs.isDisjoint(with: researchOnly))
    }
    #endif

    @Test("registered IDs are a subset of the canonical catalog")
    func registeredIDsAreSubsetOfCanonical() async {
        let registeredIDs = Set(registry.all.map(\.id))
        let allIDs = Set(TrainingDisciplineID.canonicalIDs)
        #expect(registeredIDs.isSubset(of: allIDs))
    }

    @Test("no discipline ID is registered twice")
    func noDuplicateIDs() async {
        let ids = registry.all.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test("every active category has at least one registered discipline")
    func activeCategoryNonEmpty() async {
        for category in registry.activeCategories {
            #expect(registry.disciplines(in: category).isEmpty == false,
                    "Category \(category) is active but has no disciplines")
        }
    }

    @Test("every registered discipline's category is in TrainingCategory.allCases")
    func registeredCategoryIsCanonical() async {
        for discipline in registry.all {
            #expect(TrainingCategory.allCases.contains(discipline.category),
                    "Discipline \(discipline.id) declares unknown category \(discipline.category)")
        }
    }

    @Test("subscript returns the discipline whose id matches the lookup")
    func subscriptReturnsCorrectDiscipline() async {
        for discipline in registry.all {
            #expect(registry[discipline.id].id == discipline.id)
        }
    }

    /// ``TrainingDisciplineRegistry/allUI`` filters via `compactMap`; if a
    /// future production discipline forgets the ``TrainingDisciplineUI``
    /// conformance, every aggregating screen would silently omit it. This
    /// test trips on the production bootstrap list before that can ship.
    @Test("every registered discipline conforms to TrainingDisciplineUI")
    func everyDisciplineConformsToUI() async {
        let total = registry.all.count
        let ui = registry.allUI.count
        #expect(
            ui == total,
            "allUI dropped \(total - ui) discipline(s) — every production discipline must conform to TrainingDisciplineUI"
        )
    }

    // MARK: - No CSV column name overlaps

    @Test("no discipline declares a common column as its own")
    func noDisciplineDeclaresCommonColumn() async {
        let commonSet = Set(CSVExportSchema.commonColumns)

        for discipline in registry.all {
            for column in discipline.csvColumns {
                #expect(commonSet.contains(column) == false,
                        "Discipline \(discipline.csvTrainingType) declares common column '\(column)'")
            }
        }
    }

    @Test("columns shared between disciplines have compatible semantics (same training type)")
    func sharedColumnsHaveCompatibleOwners() async {
        var columnOwners: [String: Set<String>] = [:]

        for discipline in registry.all {
            for column in discipline.csvColumns {
                columnOwners[column, default: []].insert(discipline.csvTrainingType)
            }
        }

        for (column, owners) in columnOwners where owners.count > 1 {
            #expect(registry.csvDisciplineColumns.contains(column),
                    "Shared column '\(column)' missing from registry's deduped column list")
        }
    }

    @Test("csvDisciplineColumns has no duplicates")
    func csvDisciplineColumnsNoDuplicates() async {
        let columns = registry.csvDisciplineColumns
        #expect(columns.count == Set(columns).count)
    }

    // MARK: - Parser dispatch by training type string

    @Test("each discipline's csvTrainingType resolves to a parser in csvParsers")
    func parserDispatchByTrainingType() async {
        let expectedTypes: Set<String> = Set(registry.all.map(\.csvTrainingType))

        for trainingType in expectedTypes {
            let parser = registry.csvParsers[trainingType]
            #expect(parser != nil, "No parser registered for training type '\(trainingType)'")
        }
    }

    @Test("csvParsers maps to correct discipline for each training type")
    func csvParsersMapCorrectly() async {
        for discipline in registry.all {
            if let parser = registry.csvParsers[discipline.csvTrainingType] {
                #expect(parser.csvTrainingType == discipline.csvTrainingType)
            }
        }
    }

    // MARK: - shared-registry test primitive

    @Test("withOverride scopes the given disciplines to the body via task-local")
    func withOverrideScopesViaTaskLocal() {
        let custom: [any TrainingDiscipline] = [UnisonPitchDiscriminationDiscipline()]
        TrainingDisciplineRegistry.withOverride(disciplines: custom) {
            let registered = Set(TrainingDisciplineRegistry.shared.all.map(\.id))
            #expect(registered == Set(custom.map(\.id)))
        }
        let restored = Set(TrainingDisciplineRegistry.shared.all.map(\.id))
        #expect(restored == Set(DisciplineBootstrap.allDisciplines.map(\.id)))
    }
}

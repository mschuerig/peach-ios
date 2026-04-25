import Testing
import Foundation
@testable import Peach

@Suite("TrainingDisciplineRegistry")
struct TrainingDisciplineRegistryTests {

    private let registry = TrainingDisciplineRegistry(disciplines: DisciplineBootstrap.allDisciplines)

    // MARK: - All discipline IDs are registered

    @Test("all canonical TrainingDisciplineIDs are registered in the registry")
    func allDisciplineIDsRegistered() async {
        let registeredIDs = Set(registry.all.map(\.id))
        let allIDs = Set(TrainingDisciplineID.canonicalIDs)

        #expect(registeredIDs == allIDs)
    }

    @Test("registry contains exactly 6 disciplines")
    func registryContainsSixDisciplines() async {
        #expect(registry.all.count == 6)
    }

    @Test("subscript returns correct discipline for each ID")
    func subscriptReturnsCorrectDiscipline() async {
        for disciplineID in TrainingDisciplineID.canonicalIDs {
            let discipline = registry[disciplineID]
            #expect(discipline.id == disciplineID)
        }
    }

    @Test("each discipline declares the expected category", arguments: [
        (TrainingDisciplineID.unisonPitchDiscrimination, TrainingCategory.pitch),
        (TrainingDisciplineID.intervalPitchDiscrimination, TrainingCategory.intervals),
        (TrainingDisciplineID.unisonPitchMatching, TrainingCategory.pitch),
        (TrainingDisciplineID.intervalPitchMatching, TrainingCategory.intervals),
        (TrainingDisciplineID.timingOffsetDetection, TrainingCategory.rhythm),
        (TrainingDisciplineID.continuousRhythmMatching, TrainingCategory.rhythm),
    ])
    func disciplineDeclaresExpectedCategory(_ id: TrainingDisciplineID, _ expected: TrainingCategory) async {
        #expect(registry[id].category == expected)
    }

    // MARK: - No CSV column name overlaps

    @Test("no discipline declares a common column as its own")
    func noDisciplineDeclaresCommonColumn() async {
        let commonSet = Set(CSVExportSchema.commonColumns)

        for discipline in registry.all {
            for column in discipline.csvColumns {
                #expect(!commonSet.contains(column),
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

    @Test("recordTypes returns distinct model types")
    func recordTypesDistinct() async {
        let types = registry.recordTypes
        let typeIDs = types.map { ObjectIdentifier($0) }
        #expect(typeIDs.count == Set(typeIDs).count)
    }
}

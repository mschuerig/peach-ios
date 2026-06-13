import Testing
import Foundation
@testable import Peach

@Suite("ChromaticConstructionDiscipline experimental-cut conformance")
struct ChromaticConstructionDisciplineTests {

    @Test("category is .intervals")
    func categoryIsIntervals() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.category == .intervals)
    }

    @Test("id is the canonical chromatic-construction slug")
    func idIsCanonical() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.id == .chromaticConstruction)
    }

    @Test("navigationDestination routes to chromaticConstruction")
    func navigationDestinationIsChromaticConstruction() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.navigationDestination == .chromaticConstruction)
    }

    @Test("statisticsKeys is empty (no progress tracking in this cut)")
    func statisticsKeysIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.statisticsKeys.isEmpty)
    }

    @Test("helpSections is empty (help deferred to graduation from research)")
    func helpSectionsIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.helpSections.isEmpty)
    }

    @Test("settingsSections inherits the empty default")
    func settingsSectionsIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.settingsSections.isEmpty)
    }

    @Test("settingsHelp inherits the empty default")
    func settingsHelpIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.settingsHelp.isEmpty)
    }

    @Test("profileHelp inherits the empty default")
    func profileHelpIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.profileHelp.isEmpty)
    }

    @Test("CSV columns are empty (no records persisted)")
    func csvColumnsIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.csvColumns.isEmpty)
    }

    @Test("csvTrainingType is stable wire identifier")
    func csvTrainingTypeIsCanonical() {
        let discipline = ChromaticConstructionDiscipline()
        #expect(discipline.csvTrainingType == "chromaticConstruction")
    }

    @Test("csvKeyValuePairs returns empty for any payload")
    func csvKeyValuePairsIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        let payload = ChromaticConstructionPayload()
        #expect(discipline.csvKeyValuePairs(for: payload).isEmpty)
    }

    @Test("parseCSVRow rejects every row")
    func parseCSVRowAlwaysFails() {
        let discipline = ChromaticConstructionDiscipline()
        let result = discipline.parseCSVRow(fields: [], columnIndex: [:], rowNumber: 1)
        switch result {
        case .failure: #expect(true)
        case .success: Issue.record("parseCSVRow should reject every row in the experimental cut")
        }
    }

    @Test("parsedRecords returns empty")
    func parsedRecordsIsEmpty() {
        let discipline = ChromaticConstructionDiscipline()
        let empty = CSVImportParser.ImportResult(payloads: [:], errors: [])
        #expect(discipline.parsedRecords(from: empty).isEmpty)
    }
}

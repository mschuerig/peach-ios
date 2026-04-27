import Testing
import Foundation
import SwiftUI
@testable import Peach

/// Aggregation contract for the discipline-contributed section list rendered
/// by ``SettingsScreen``: sections appear in registration order, and the
/// first declarer of a given id wins so that disciplines may share
/// per-category sections (e.g. the rhythm tempo section) without producing
/// duplicates. Owned by Story 77.2.
@Suite("Settings sections — discipline aggregation")
struct DisciplineSettingsSectionAggregationTests {

    @Test("sections from a single discipline render in declaration order")
    func sectionsPreserveDeclarationOrder() {
        let disciplines: [any TrainingDisciplineUI] = [
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("a"),
                category: .rhythm,
                ownSettingsSectionIDs: ["alpha", "beta", "gamma"]
            ),
        ]
        let ids = DisciplineSettingsSection.aggregated(from: disciplines).map(\.id)
        #expect(ids == ["alpha", "beta", "gamma"])
    }

    @Test("sections from multiple disciplines render in registration order")
    func sectionsPreserveRegistrationOrder() {
        let disciplines: [any TrainingDisciplineUI] = [
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("first"),
                category: .rhythm,
                ownSettingsSectionIDs: ["one"]
            ),
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("second"),
                category: .pitch,
                ownSettingsSectionIDs: ["two"]
            ),
        ]
        let ids = DisciplineSettingsSection.aggregated(from: disciplines).map(\.id)
        #expect(ids == ["one", "two"])
    }

    @Test("a section id declared by two disciplines renders once, from the first declarer")
    func sharedSectionIDDedupedToFirstDeclarer() {
        let disciplines: [any TrainingDisciplineUI] = [
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("first"),
                category: .rhythm,
                ownSettingsSectionIDs: ["shared"]
            ),
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("second"),
                category: .rhythm,
                ownSettingsSectionIDs: ["shared", "second-only"]
            ),
        ]
        let ids = DisciplineSettingsSection.aggregated(from: disciplines).map(\.id)
        #expect(ids == ["shared", "second-only"])
    }

    @Test("disciplines that contribute no sections do not displace others")
    func silentDisciplinesDoNotDisplaceOthers() {
        let disciplines: [any TrainingDisciplineUI] = [
            SyntheticUIDiscipline(id: TrainingDisciplineID("silent-a"), category: .pitch),
            SyntheticUIDiscipline(
                id: TrainingDisciplineID("loud"),
                category: .rhythm,
                ownSettingsSectionIDs: ["only"]
            ),
            SyntheticUIDiscipline(id: TrainingDisciplineID("silent-b"), category: .intervals),
        ]
        let ids = DisciplineSettingsSection.aggregated(from: disciplines).map(\.id)
        #expect(ids == ["only"])
    }
}

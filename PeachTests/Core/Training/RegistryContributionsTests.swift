import Testing
import Foundation
@testable import Peach

/// Aggregator invariants for the plugin-style contribution model introduced
/// by Story 77.1. The registry collects each discipline's enum-typed
/// contributions (settings sections, profile help) into an ordered,
/// deduplicated list that aggregating screens iterate verbatim.
@Suite("TrainingDisciplineRegistry — UI contributions")
struct RegistryContributionsTests {

    @Test("settingsSectionContributions is empty when no discipline contributes")
    func settingsContributionsEmptyWhenNone() {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticDiscipline(id: TrainingDisciplineID("a"), category: .pitch),
        ])
        #expect(registry.settingsSectionContributions.isEmpty)
    }

    @Test("settingsSectionContributions deduplicates kinds shared by sibling disciplines")
    func settingsContributionsDeduplicates() {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticDiscipline(
                id: TrainingDisciplineID("r1"),
                category: .rhythm,
                settingsContributions: [.rhythmTempo]
            ),
            SyntheticDiscipline(
                id: TrainingDisciplineID("r2"),
                category: .rhythm,
                settingsContributions: [.rhythmTempo, .rhythmGapPositions]
            ),
        ])
        #expect(registry.settingsSectionContributions == [.rhythmTempo, .rhythmGapPositions])
    }

    @Test("settingsSectionContributions preserves first-occurrence registration order")
    func settingsContributionsPreservesOrder() {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticDiscipline(
                id: TrainingDisciplineID("first"),
                category: .rhythm,
                settingsContributions: [.rhythmGapPositions]
            ),
            SyntheticDiscipline(
                id: TrainingDisciplineID("second"),
                category: .rhythm,
                settingsContributions: [.rhythmTempo]
            ),
        ])
        #expect(registry.settingsSectionContributions == [.rhythmGapPositions, .rhythmTempo])
    }

    @Test("profileHelpContributions deduplicates kinds shared by sibling disciplines")
    func profileHelpContributionsDeduplicates() {
        let registry = TrainingDisciplineRegistry(disciplines: [
            SyntheticDiscipline(
                id: TrainingDisciplineID("r1"),
                category: .rhythm,
                profileHelpContributions: [.rhythmSpectrogramOverview, .rhythmSpectrogramColors]
            ),
            SyntheticDiscipline(
                id: TrainingDisciplineID("r2"),
                category: .rhythm,
                profileHelpContributions: [.rhythmSpectrogramOverview, .rhythmSpectrogramColors]
            ),
        ])
        #expect(registry.profileHelpContributions == [.rhythmSpectrogramOverview, .rhythmSpectrogramColors])
    }

    @Test("profileHelpContributions yields only what the registered subset declares")
    func profileHelpContributionsRespectsSubset() {
        let pitchOnly = TrainingDisciplineRegistry(disciplines: [
            SyntheticDiscipline(id: TrainingDisciplineID("p"), category: .pitch),
        ])
        #expect(pitchOnly.profileHelpContributions.isEmpty)
    }

    // MARK: - Profile-card mapping exhaustiveness

    @Test("every ProfileCardKind has a concrete view in contributedProfileCard")
    func profileCardKindMappingIsExhaustive() {
        // Construct a synthetic discipline per kind and dispatch via the
        // App-layer mapping; the mapping is a switch over a non-frozen enum,
        // so this test fails to compile if a case is added without a branch.
        // At runtime we just need to confirm dispatch returns without trapping.
        let kinds: [ProfileCardKind] = [.progressChart, .rhythmSpectrogram]
        for kind in kinds {
            let discipline = SyntheticDiscipline(
                id: TrainingDisciplineID("synthetic-\(kind)"),
                category: .pitch,
                profileCard: kind
            )
            // Smoke check: the dispatcher can be invoked without trapping.
            _ = contributedProfileCard(for: discipline)
        }
    }

    @Test("every registered discipline declares a known ProfileCardKind")
    func everyRegisteredDisciplineHasKnownProfileCard() {
        let known: Set<ProfileCardKind> = [.progressChart, .rhythmSpectrogram]
        for discipline in TrainingDisciplineRegistry.shared.all {
            #expect(known.contains(discipline.profileCard),
                    "Discipline \(discipline.id) declares unknown ProfileCardKind \(discipline.profileCard)")
        }
    }
}

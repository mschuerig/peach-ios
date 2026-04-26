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

    #if PEACH_RESEARCH
    @Test("under the canonical Research bootstrap, contributed settings render Tempo above Gap Positions")
    func canonicalBootstrapPinsTempoAboveGapPositions() {
        #expect(TrainingDisciplineRegistry.shared.settingsSectionContributions
                == [.rhythmTempo, .rhythmGapPositions])
    }
    #endif

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

    @Test("every ProfileCardKind has a concrete view in contributedProfileCard",
          arguments: ProfileCardKind.allCases)
    func profileCardKindMappingIsExhaustive(_ kind: ProfileCardKind) {
        let discipline = SyntheticDiscipline(
            id: TrainingDisciplineID("synthetic-\(kind)"),
            category: .pitch,
            profileCard: kind
        )
        _ = contributedProfileCard(for: discipline)
    }

    @Test("every registered discipline declares a known ProfileCardKind")
    func everyRegisteredDisciplineHasKnownProfileCard() {
        let known = Set(ProfileCardKind.allCases)
        for discipline in TrainingDisciplineRegistry.shared.all {
            #expect(known.contains(discipline.profileCard),
                    "Discipline \(discipline.id) declares unknown ProfileCardKind \(discipline.profileCard)")
        }
    }

    // MARK: - Synthetic subsets via the shared registry

    @Test("a pitch-only synthetic subset surfaces no contributions through the shared registry")
    func sharedRegistryReplacedWithPitchOnlySubsetEmitsNoContributions() {
        TrainingDisciplineRegistry._withSharedReplacedForTesting(
            disciplines: [
                SyntheticDiscipline(id: TrainingDisciplineID("p"), category: .pitch),
            ]
        ) {
            #expect(TrainingDisciplineRegistry.shared.settingsSectionContributions.isEmpty)
            #expect(TrainingDisciplineRegistry.shared.profileHelpContributions.isEmpty)
        }
    }

    @Test("a rhythm-only synthetic subset surfaces only its declared contributions through the shared registry")
    func sharedRegistryReplacedWithRhythmOnlySubsetEmitsOnlyDeclaredContributions() {
        TrainingDisciplineRegistry._withSharedReplacedForTesting(
            disciplines: [
                SyntheticDiscipline(
                    id: TrainingDisciplineID("r"),
                    category: .rhythm,
                    settingsContributions: [.rhythmGapPositions],
                    profileHelpContributions: [.rhythmSpectrogramOverview]
                ),
            ]
        ) {
            #expect(TrainingDisciplineRegistry.shared.settingsSectionContributions == [.rhythmGapPositions])
            #expect(TrainingDisciplineRegistry.shared.profileHelpContributions == [.rhythmSpectrogramOverview])
        }
    }

    @Test("synthetic subsets that vary profile-card kind are reflected in the shared registry's discipline set",
          arguments: ProfileCardKind.allCases)
    func sharedRegistryReplacedWithSubsetExposesProfileCardKind(_ kind: ProfileCardKind) {
        TrainingDisciplineRegistry._withSharedReplacedForTesting(
            disciplines: [
                SyntheticDiscipline(
                    id: TrainingDisciplineID("synthetic-\(kind)"),
                    category: .pitch,
                    profileCard: kind
                ),
            ]
        ) {
            #expect(TrainingDisciplineRegistry.shared.all.first?.profileCard == kind)
        }
    }
}

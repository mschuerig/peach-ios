import Foundation

/// Identifier for a settings section a discipline contributes to ``SettingsScreen``.
///
/// The App layer maps each kind to a concrete SwiftUI section. Disciplines
/// declare contributions as enum values (no SwiftUI in Core); the screen
/// aggregates them across the registered set, deduplicating identical kinds.
enum SettingsSectionKind: String, CaseIterable, Sendable, Hashable {
    /// Tempo (BPM) stepper. Applies to every rhythm discipline.
    case rhythmTempo
    /// Gap-positions grid. Applies only to ``ContinuousRhythmMatchingDiscipline``.
    case rhythmGapPositions
}

/// Identifier for the profile card view a discipline owns on ``ProfileScreen``.
///
/// The App layer maps each kind to a concrete SwiftUI view (e.g. line chart
/// vs. spectrogram). Adding a new card type means adding a case here and a
/// branch in the App-layer mapping; no `switch discipline.category` ever
/// appears in the screen itself.
enum ProfileCardKind: Sendable, Hashable {
    case progressChart
    case rhythmSpectrogram
}

/// Identifier for a scoped help section a discipline contributes to
/// ``ProfileScreen`` help. Settings-screen scoped help is derived from
/// ``SettingsSectionKind`` instead — settings sections and their help
/// move together.
enum ProfileHelpKind: String, CaseIterable, Sendable, Hashable {
    case rhythmSpectrogramOverview
    case rhythmSpectrogramColors
}

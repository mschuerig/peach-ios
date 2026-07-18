import SwiftUI

/// App-layer refinement of ``TrainingDiscipline`` that adds view-producing
/// requirements. Concrete disciplines live outside Core (in
/// `Peach/Training/<Feature>/`) so they may freely `import SwiftUI` and
/// conform here without violating Core's no-SwiftUI rule.
///
/// Aggregating screens (``SettingsScreen``, ``ProfileScreen``, ``HelpContent``)
/// iterate the App-typed list (``TrainingDisciplineRegistry/allUI``) and
/// invoke these properties directly — no central kind enum, no central
/// dispatcher, no `switch` on category in the screen.
///
/// All view-producing requirements have defaults. A discipline overrides
/// only the surfaces it owns; everything else inherits the default and
/// renders trivially.
///
/// ## Per-category shared sections
///
/// Some sections (e.g. the rhythm tempo section) are naturally shared by
/// every discipline in a category. Each discipline that needs the section
/// declares it with a stable ``DisciplineSettingsSection/id``; the
/// aggregating screen renders the first declarer's section and skips
/// subsequent declarations with the same id. This keeps disciplines
/// self-contained — disabling one rhythm discipline does not silently
/// remove a section the other still depends on.
protocol TrainingDisciplineUI: TrainingDiscipline {
    /// Profile card rendered for this discipline on ``ProfileScreen``.
    /// Default: ``ProgressChartView`` keyed by ``id``.
    var profileCard: AnyView { get }

    /// Settings sections rendered for this discipline on ``SettingsScreen``,
    /// each keyed by a stable id. Default: none.
    var settingsSections: [DisciplineSettingsSection] { get }

    /// Help sections shown in the ``SettingsScreen`` help sheet for this
    /// discipline. Default: none. Aggregators dedupe by content so that
    /// shared per-category help (e.g. rhythm tempo) declared by multiple
    /// disciplines renders only once.
    var settingsHelp: [HelpSection] { get }

    /// Help sections shown in the ``ProfileScreen`` help sheet for this
    /// discipline. Default: none.
    var profileHelp: [HelpSection] { get }
}

extension TrainingDisciplineUI {
    var profileCard: AnyView { AnyView(CachedProgress(mode: id) { ProgressChartView(mode: id, progress: $0) }) }
    var settingsSections: [DisciplineSettingsSection] { [] }
    var settingsHelp: [HelpSection] { [] }
    var profileHelp: [HelpSection] { [] }
}

// MARK: - Registry-access mechanism

extension TrainingDisciplineRegistry {
    /// The registered disciplines viewed through the App-layer UI protocol.
    ///
    /// Every concrete discipline conforms to ``TrainingDisciplineUI``; the
    /// `compactMap` cast therefore always succeeds for production
    /// disciplines. Synthetic test fixtures conforming only to
    /// ``TrainingDiscipline`` are silently filtered out, which is the
    /// desired behavior — registry tests that assert UI behavior must use
    /// fixtures that conform to the UI protocol.
    var allUI: [any TrainingDisciplineUI] {
        all.compactMap { $0 as? any TrainingDisciplineUI }
    }
}

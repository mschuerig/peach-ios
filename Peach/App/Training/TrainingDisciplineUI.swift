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
protocol TrainingDisciplineUI: TrainingDiscipline {
    /// Profile card rendered for this discipline on ``ProfileScreen``.
    /// Default: ``ProgressChartView`` keyed by ``id``.
    var profileCard: AnyView { get }

    /// Settings sections rendered for this discipline on ``SettingsScreen``.
    /// Default: empty.
    var settingsSections: AnyView { get }

    /// Help sections shown in the ``SettingsScreen`` help sheet for this
    /// discipline. Default: none. Sections describing per-feature settings
    /// (e.g. rhythm tempo) move with the settings sections themselves.
    var settingsHelp: [HelpSection] { get }

    /// Help sections shown in the ``ProfileScreen`` help sheet for this
    /// discipline. Default: none.
    var profileHelp: [HelpSection] { get }
}

extension TrainingDisciplineUI {
    var profileCard: AnyView { AnyView(ProgressChartView(mode: id)) }
    var settingsSections: AnyView { AnyView(EmptyView()) }
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

import SwiftUI

/// Gap-positions grid for ``ContinuousRhythmMatchingDiscipline``. Encodes
/// the active subset into the `enabledGapPositions` `@AppStorage` key via
/// ``GapPositionEncoding``.
struct RhythmGapPositionsSettingsSection: View {
    @AppStorage(ContinuousRhythmMatchingSettingsKeys.enabledGapPositions)
    private var enabledGapPositionsEncoded: String = GapPositionEncoding.encode(ContinuousRhythmMatchingSettingsKeys.defaultEnabledGapPositions)

    @State private var enabledGapPositions: Set<BeatPosition> = []

    var body: some View {
        Section {
            GridToggleRow(selection: $enabledGapPositions) { position in
                "\(position.rawValue + 1)"
            }
        } header: {
            Text(String(localized: "Gap Positions"))
        } footer: {
            Text(String(localized: "Select which gap positions to practice. At least one must remain active."))
        }
        .onAppear {
            enabledGapPositions = GapPositionEncoding.decodeWithDefault(enabledGapPositionsEncoded)
        }
        .onChange(of: enabledGapPositions) {
            enabledGapPositionsEncoded = GapPositionEncoding.encode(enabledGapPositions)
        }
    }
}

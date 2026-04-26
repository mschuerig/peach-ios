import SwiftUI

/// App-layer mapping from ``ProfileCardKind`` — a Core enum that any
/// ``TrainingDiscipline`` declares via ``profileCard`` — to the concrete
/// SwiftUI card view. Adding a new card type is an additive change in this
/// file: declare the new case in ``ProfileCardKind`` (Core) and add a branch
/// here. ``ProfileScreen`` itself does not need to be edited.
@ViewBuilder
func contributedProfileCard(for discipline: any TrainingDiscipline) -> some View {
    switch discipline.profileCard {
    case .progressChart:
        ProgressChartView(mode: discipline.id)
    case .rhythmSpectrogram:
        RhythmProfileCardView(mode: discipline.id)
    }
}

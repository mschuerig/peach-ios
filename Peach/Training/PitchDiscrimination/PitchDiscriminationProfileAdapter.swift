import Foundation

struct PitchDiscriminationProfileAdapter: PitchDiscriminationObserver {
    private let profile: any ProfileUpdating

    init(profile: any ProfileUpdating) {
        self.profile = profile
    }

    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
        let pc = completed.trial
        let isUnison = pc.referenceNote == pc.targetNote.note
        let mode: TrainingDisciplineID = isUnison ? .unisonPitchDiscrimination : .intervalPitchDiscrimination

        guard completed.isCorrect else { return }

        profile.update(.pitch(mode), timestamp: completed.timestamp, value: pc.targetNote.offset.magnitude)
    }
}

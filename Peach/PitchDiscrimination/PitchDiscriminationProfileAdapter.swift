import Foundation

struct PitchDiscriminationProfileAdapter: PitchDiscriminationObserver {
    private let profile: any ProfileUpdating

    init(profile: any ProfileUpdating) {
        self.profile = profile
    }

    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
        let pc = completed.trial
        let interval = (try? Interval.between(pc.referenceNote, pc.targetNote.note))?.rawValue ?? 0
        let isUnison = interval == 0
        let mode: TrainingDisciplineID = isUnison ? .unisonPitchDiscrimination : .intervalPitchDiscrimination

        guard completed.isCorrect else { return }

        profile.update(.pitch(mode), timestamp: completed.timestamp, value: pc.targetNote.offset.magnitude)
    }
}

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

        // Only correct answers update the profile — incorrect answers carry no useful offset
        // information. Contrast with PitchMatchingProfileAdapter which routes all results
        // (pitch matching has no binary outcome, only continuous cent error).
        guard completed.isCorrect else { return }

        profile.update(.pitch(mode), timestamp: completed.timestamp, value: pc.targetNote.offset.magnitude)
    }
}

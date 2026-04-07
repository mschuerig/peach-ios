import Foundation

struct PitchMatchingProfileAdapter: PitchMatchingObserver {
    private let profile: any ProfileUpdating

    init(profile: any ProfileUpdating) {
        self.profile = profile
    }

    // Pitch matching produces a continuous cent error on every attempt — there is no binary
    // correct/incorrect outcome. All results are routed to the profile, unlike
    // PitchDiscriminationProfileAdapter which gates on isCorrect.
    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
        let isUnison = result.referenceNote == result.targetNote
        let mode: TrainingDisciplineID = isUnison ? .unisonPitchMatching : .intervalPitchMatching

        profile.update(.pitch(mode), timestamp: result.timestamp, value: result.userCentError.magnitude)
    }
}

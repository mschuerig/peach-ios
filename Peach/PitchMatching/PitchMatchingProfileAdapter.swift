import Foundation

struct PitchMatchingProfileAdapter: PitchMatchingObserver {
    private let profile: any ProfileUpdating

    init(profile: any ProfileUpdating) {
        self.profile = profile
    }

    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
        let interval = (try? Interval.between(result.referenceNote, result.targetNote))?.rawValue ?? 0
        let isUnison = interval == 0
        let mode: TrainingDisciplineID = isUnison ? .unisonPitchMatching : .intervalPitchMatching

        profile.update(.pitch(mode), timestamp: result.timestamp, value: result.userCentError.magnitude)
    }
}

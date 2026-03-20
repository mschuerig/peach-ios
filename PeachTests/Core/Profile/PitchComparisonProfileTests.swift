import Testing
@testable import Peach

@Suite("TrainingProfile")
struct TrainingProfileTests {

    @Test("PerceptualProfile conforms to TrainingProfile")
    func conformsToTrainingProfile() async {
        let profile = PerceptualProfile()
        let _: TrainingProfile = profile
        #expect(profile is TrainingProfile)
    }
}

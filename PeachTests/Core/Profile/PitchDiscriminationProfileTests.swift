import Testing
@testable import Peach

@Suite("PitchDiscriminationProfile")
struct PitchDiscriminationProfileTests {

    @Test("PerceptualProfile conforms to PitchDiscriminationProfile")
    func conformsToPitchDiscriminationProfile() async {
        let profile = PerceptualProfile()
        let _: PitchDiscriminationProfile = profile
        #expect(profile is PitchDiscriminationProfile)
    }
}

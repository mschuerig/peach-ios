import Testing
import SwiftUI
@testable import Peach

@Suite("ProfileScreen Tests")
struct ProfileScreenTests {

    // MARK: - PerceptualProfile Environment Key

    @Test("PerceptualProfile environment key provides default value")
    func environmentKeyDefaultValue() async throws {
        let env = EnvironmentValues()
        let profile = env.perceptualProfile
        #expect(profile.comparisonMean(for: .prime) == nil)
    }

    @Test("PerceptualProfile environment key can be set and retrieved")
    func environmentKeySetAndGet() async throws {
        let profile = PerceptualProfile()
        PitchDiscriminationProfileAdapter(profile: profile).pitchDiscriminationCompleted(CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(50.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))

        var env = EnvironmentValues()
        env.perceptualProfile = profile

        let retrieved = env.perceptualProfile
        #expect(retrieved.comparisonMean(for: .prime) == 50.0)
    }

}

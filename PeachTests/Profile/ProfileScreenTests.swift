import Testing
import SwiftUI
@testable import Peach

@Suite("ProfileScreen Tests")
struct ProfileScreenTests {

    // MARK: - PerceptualProfile Environment Key

    @Test("PerceptualProfile environment key provides default value")
    func environmentKeyDefaultValue() async throws {
        var env = EnvironmentValues()
        let profile = env.perceptualProfile
        #expect(profile.overallMean == nil)
    }

    @Test("PerceptualProfile environment key can be set and retrieved")
    func environmentKeySetAndGet() async throws {
        let profile = PerceptualProfile()
        profile.update(note: 60, centOffset: 50, isCorrect: true)

        var env = EnvironmentValues()
        env.perceptualProfile = profile

        let retrieved = env.perceptualProfile
        #expect(retrieved.statsForNote(60).mean == 50.0)
    }

}

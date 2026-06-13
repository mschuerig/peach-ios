import Testing
@testable import Peach

@Suite("ChromaticConstructionSession lifecycle contribution")
struct ChromaticConstructionLifecycleContributionTests {

    @Test("contribute registers .chromaticConstruction with the session")
    func contributeRegistersChromaticConstruction() {
        let session = ChromaticConstructionSession.stub
        let userSettings = StubUserSettings()
        let registry = TrainingLifecycleRegistry { builder in
            session.contribute(to: builder, userSettings: userSettings)
        }
        let contribution = registry.contribution(for: .chromaticConstruction)
        #expect(contribution != nil)
        #expect(contribution?.session === session)
    }
}

import Testing
@testable import Peach

@Suite("Pitch Matching Training Discipline Tests")
struct PitchMatchingTrainingDisciplineTests {

    @Test("trainingDiscipline returns unisonMatching for prime intervals")
    func trainingDisciplineUnison() async {
        let mode = PitchMatchingScreen.trainingDiscipline(for: [.prime])
        #expect(mode == .unisonPitchMatching)
    }

    @Test("trainingDiscipline returns intervalMatching for non-prime intervals")
    func trainingDisciplineInterval() async {
        let mode = PitchMatchingScreen.trainingDiscipline(for: [.up(.perfectFifth)])
        #expect(mode == .intervalPitchMatching)
    }
}

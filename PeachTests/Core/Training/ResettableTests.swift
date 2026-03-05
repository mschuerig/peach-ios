import Testing
@testable import Peach

@Suite("Resettable Protocol Tests")
struct ResettableTests {

    @Test("Resettable protocol can be used as a type-erased collection element")
    func resettableCanBeStoredInArray() async throws {
        let mock = MockResettable()
        let resettables: [Resettable] = [mock]
        for r in resettables { try r.reset() }
        #expect(mock.resetCallCount == 1)
    }

    @Test("Multiple resettables are all reset when iterating")
    func multipleResettablesAllReset() async throws {
        let mock1 = MockResettable()
        let mock2 = MockResettable()
        let resettables: [Resettable] = [mock1, mock2]
        for r in resettables { try r.reset() }
        #expect(mock1.resetCallCount == 1)
        #expect(mock2.resetCallCount == 1)
    }

    @Test("ProgressTimeline conforms to Resettable")
    func progressTimelineConformsToResettable() async throws {
        let timeline = ProgressTimeline()
        let resettable: Resettable = timeline
        try resettable.reset()
        #expect(timeline.state(for: .unisonComparison) == .noData)
    }

    @Test("ComparisonSession.resetTrainingData calls reset on all resettables")
    func resetTrainingDataCallsAllResettables() async throws {
        let mock1 = MockResettable()
        let mock2 = MockResettable()
        let session = ComparisonSession(
            notePlayer: MockNotePlayer(),
            strategy: MockNextComparisonStrategy(),
            profile: PerceptualProfile(),
            userSettings: MockUserSettings(),
            resettables: [mock1, mock2]
        )

        try session.resetTrainingData()

        #expect(mock1.resetCallCount == 1)
        #expect(mock2.resetCallCount == 1)
    }
}

import Testing
@testable import Peach

@MainActor
@Suite("ChromaticConstructionSession")
struct ChromaticConstructionSessionTests {

    // MARK: - Fixtures

    private func makeFixture(
        outerIntervals: Set<DirectedInterval> = [.up(.majorSecond)],  // 2 interior positions
        lowerAnchor: MIDINote = MIDINote(60)
    ) -> (session: ChromaticConstructionSession, notePlayer: MockNotePlayer, settings: ChromaticConstructionSettings) {
        let notePlayer = MockNotePlayer()
        let strategy = MonotonicPath()
        let session = ChromaticConstructionSession(notePlayer: notePlayer, strategy: strategy)
        let settings = ChromaticConstructionSettings(
            lowerAnchor: lowerAnchor,
            outerIntervals: outerIntervals,
            referencePitch: Frequency(440.0)
        )
        return (session, notePlayer, settings)
    }

    // MARK: - Lifecycle

    @Test("session starts in .idle with no current or completed trial")
    func initialState() {
        let (session, _, _) = makeFixture()
        #expect(session.state == .idle)
        #expect(session.currentTrial == nil)
        #expect(session.lastCompletedTrial == nil)
        #expect(session.isIdle)
    }

    @Test("start from .idle transitions to .walking and builds a trial via the strategy")
    func startFromIdle() async {
        let (session, notePlayer, settings) = makeFixture()
        session.start(settings: settings)
        await notePlayer.waitForPlay()

        #expect(session.state == .walking)
        #expect(session.currentTrial != nil)
        #expect(session.currentTrial?.active?.index == 1)
        #expect(notePlayer.playCallCount >= 1)
    }

    @Test("start from non-idle is a no-op")
    func startFromNonIdleIsNoOp() async {
        let (session, notePlayer, settings) = makeFixture()
        session.start(settings: settings)
        await notePlayer.waitForPlay()

        let stateBefore = session.state
        session.start(settings: settings)
        #expect(session.state == stateBefore)
    }

    @Test("stop from .walking returns to .idle and clears trial state")
    func stopFromWalking() async {
        let (session, notePlayer, settings) = makeFixture()
        session.start(settings: settings)
        await notePlayer.waitForPlay()

        session.stop()

        #expect(session.state == .idle)
        #expect(session.currentTrial == nil)
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from .idle is a no-op")
    func stopFromIdleIsNoOp() {
        let (session, notePlayer, _) = makeFixture()
        session.stop()
        #expect(session.state == .idle)
        #expect(notePlayer.stopAllCallCount == 0)
    }

    // MARK: - Place / Interior advancement

    @Test("place at an interior position advances active and plays the predecessor cue")
    func placeAdvancesInteriorPosition() async {
        // outerInterval = .up(.minorThird) → 3 .up steps → interiorPositionCount = 2.
        let (session, notePlayer, settings) = makeFixture(outerIntervals: [.up(.minorThird)])
        session.start(settings: settings)
        await notePlayer.waitForPlay()  // anchor cue
        notePlayer.reset()

        session.place(offset: Cents(95.0))
        await notePlayer.waitForPlay()  // predecessor cue for position 2

        #expect(session.state == .walking)
        #expect(session.currentTrial?.active?.index == 2)
        #expect(notePlayer.playCallCount >= 1)
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("place at the final interior position completes the trial implicitly")
    func placeFinalImplicitSubmit() async {
        let (session, notePlayer, settings) = makeFixture(outerIntervals: [.up(.majorSecond)])
        session.start(settings: settings)
        await notePlayer.waitForPlay()
        notePlayer.reset()

        session.place(offset: Cents(95.0))  // sole interior position → trial completes
        await notePlayer.waitForStopAll()

        #expect(session.state == .showingResult)
        #expect(session.currentTrial?.isComplete == true)
        #expect(session.lastCompletedTrial != nil)
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("place outside .walking is a no-op")
    func placeOutsideWalkingIsNoOp() {
        let (session, _, _) = makeFixture()
        session.place(offset: Cents(100.0))  // from .idle
        #expect(session.state == .idle)
        #expect(session.currentTrial == nil)
    }

    // MARK: - StepBack

    @Test("stepBack from position 2 re-activates position 1 with placedOffset preserved")
    func stepBackFromPositionTwo() async {
        let (session, notePlayer, settings) = makeFixture(outerIntervals: [.up(.minorThird)])
        session.start(settings: settings)
        await notePlayer.waitForPlay()
        session.place(offset: Cents(95.0))
        await notePlayer.waitForPlay(minCount: 2)

        session.stepBack()

        #expect(session.state == .walking)
        #expect(session.currentTrial?.active?.index == 1)
        #expect(session.currentTrial?.active?.preservedValue == DetunedMIDINote(note: MIDINote(60), offset: Cents(95.0)))
        #expect(session.currentTrial?.placed.isEmpty == true)
    }

    @Test("stepBack at position 1 is a no-op")
    func stepBackAtFirstPositionNoOp() async {
        let (session, notePlayer, settings) = makeFixture()
        session.start(settings: settings)
        await notePlayer.waitForPlay()

        let stateBefore = session.currentTrial
        session.stepBack()
        #expect(session.currentTrial == stateBefore)
    }

    @Test("stepBack from .showingResult reopens the final interior position")
    func stepBackFromShowingResult() async {
        let (session, notePlayer, settings) = makeFixture(outerIntervals: [.up(.majorSecond)])
        session.start(settings: settings)
        await notePlayer.waitForPlay()
        session.place(offset: Cents(95.0))  // trial completes
        #expect(session.state == .showingResult)

        session.stepBack()

        #expect(session.state == .walking)
        #expect(session.currentTrial?.active?.index == 1)
        #expect(session.currentTrial?.active?.preservedValue == DetunedMIDINote(note: MIDINote(60), offset: Cents(95.0)))
        #expect(session.lastCompletedTrial == nil)
    }

    // MARK: - nextTrial

    @Test("nextTrial from .showingResult builds a fresh trial via the strategy")
    func nextTrialBuildsFreshTrial() async {
        let (session, notePlayer, settings) = makeFixture(outerIntervals: [.up(.majorSecond)])
        session.start(settings: settings)
        await notePlayer.waitForPlay()
        session.place(offset: Cents(95.0))
        #expect(session.state == .showingResult)

        session.nextTrial()

        #expect(session.state == .walking)
        #expect(session.currentTrial?.active?.index == 1)
        #expect(session.currentTrial?.placed.isEmpty == true)
    }

    @Test("nextTrial outside .showingResult is a no-op")
    func nextTrialOutsideShowingResultNoOp() {
        let (session, _, _) = makeFixture()
        session.nextTrial()
        #expect(session.state == .idle)
    }

    // MARK: - Pause / Resume

    @Test("pause from .walking preserves currentTrial and calls scheduleStopAll")
    func pausePreservesState() async {
        let (session, notePlayer, settings) = makeFixture()
        session.start(settings: settings)
        await notePlayer.waitForPlay()
        notePlayer.reset()

        session.pause()
        await notePlayer.waitForStopAll()

        #expect(session.state == .walking)
        #expect(session.currentTrial != nil)
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("pause from .idle is a no-op")
    func pauseFromIdleIsNoOp() {
        let (session, notePlayer, _) = makeFixture()
        session.pause()
        #expect(session.state == .idle)
        #expect(notePlayer.stopAllCallCount == 0)
    }

    @Test("resume after pause replays the orienting cue and clears isPaused")
    func resumeAfterPauseReplaysCue() async {
        let (session, notePlayer, settings) = makeFixture()
        session.start(settings: settings)
        await notePlayer.waitForPlay()
        session.pause()
        notePlayer.reset()

        session.resume()
        await notePlayer.waitForPlay()

        #expect(notePlayer.playCallCount >= 1)
    }

    @Test("start after pause re-engages cleanly (isPaused does not leak)")
    func startAfterPauseDoesNotLeakPaused() async {
        let (session, notePlayer, settings) = makeFixture()
        session.start(settings: settings)
        await notePlayer.waitForPlay()
        session.pause()
        session.stop()  // returns to .idle, clears isPaused

        session.start(settings: settings)
        await notePlayer.waitForPlay()
        // A subsequent pause should not be a no-op (which is what would happen if isPaused leaked).
        notePlayer.reset()
        session.pause()
        await notePlayer.waitForStopAll()
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("resume outside paused-walking is a no-op")
    func resumeOutsidePausedWalkingNoOp() {
        let (session, notePlayer, _) = makeFixture()
        session.resume()  // from .idle without pause
        #expect(notePlayer.playCallCount == 0)
    }

    // MARK: - Cue frequency correctness

    @Test("orienting cue at position 1 plays the lower anchor frequency in equal temperament")
    func anchorCueIsEqualTemperedLowerAnchorFreq() async {
        let (session, notePlayer, settings) = makeFixture(lowerAnchor: MIDINote(69))
        session.start(settings: settings)
        await notePlayer.waitForPlay()

        let expectedFreq = TuningSystem.equalTemperament.frequency(
            for: MIDINote(69),
            referencePitch: Frequency(440.0)
        )
        #expect(notePlayer.lastFrequency == expectedFreq.rawValue)
    }
}

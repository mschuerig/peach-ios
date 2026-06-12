import Testing
import Foundation
@testable import Peach

@Suite("ChromaticConstructionSession Tests")
struct ChromaticConstructionSessionTests {

    // MARK: - Fixtures

    /// Build a session with a MockNotePlayer set to instantPlayback mode.
    private static func makeSession() -> (session: ChromaticConstructionSession, notePlayer: MockNotePlayer) {
        let notePlayer = MockNotePlayer()
        notePlayer.instantPlayback = true
        let session = ChromaticConstructionSession(notePlayer: notePlayer)
        return (session, notePlayer)
    }

    /// Build settings with a fixed ascending P3 ladder (300 cents / 100-cent target → slotCount = 2).
    /// Small slotCount keeps stepBack tests focused without combinatorial blowup.
    private static func makeAscendingP3Settings() throws -> ChromaticConstructionSettings {
        let userSettings = MockUserSettings()
        userSettings.tuningSystem = .equalTemperament
        userSettings.referencePitch = .concert440
        var rng = SeededRNG(seed: 1)
        return try ChromaticConstructionSettings.from(
            userSettings: userSettings,
            outerCents: Cents(300.0),
            lowerAnchor: MIDINote(60),
            directionPolicy: .ascending,
            rng: &rng
        )
    }

    // MARK: - Initial state

    @Test("Starts in idle state")
    func startsInIdleState() async {
        let (session, _) = Self.makeSession()
        #expect(session.isIdle)
        guard case .idle = session.state else {
            Issue.record("Expected .idle, got \(session.state)")
            return
        }
    }

    // MARK: - start(settings:)

    @Test("start(settings:) transitions to walking with activeSlotIndex=1, empty committed")
    func startTransitionsToWalking() async throws {
        let (session, notePlayer) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        guard case .walking(let activeSlot, let committed, let ladder) = session.state else {
            Issue.record("Expected .walking, got \(session.state)")
            return
        }
        #expect(activeSlot.index == 1)
        #expect(activeSlot.state == .active)
        #expect(activeSlot.placedCents == nil)
        #expect(committed.isEmpty)
        #expect(ladder.slotCount == 2)
        #expect(!session.isIdle)

        // Orienting cue: lower-anchor frequency must have played.
        await Task.yield()
        #expect(notePlayer.playCallCount >= 1)
        let expected = settings.ladder.lowerAnchor.frequency(
            in: .equalTemperament,
            referencePitch: settings.referencePitch
        )
        #expect(notePlayer.lastFrequency == expected.rawValue)
    }

    @Test("start(settings:) from non-idle is a no-op (warns)")
    func startFromNonIdleIsNoOp() async throws {
        let (session, _) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        // Second start should be ignored — state stays walking with index 1.
        session.start(settings: settings)
        guard case .walking(let activeSlot, _, _) = session.state else {
            Issue.record("Expected .walking")
            return
        }
        #expect(activeSlot.index == 1)
    }

    // MARK: - place(cents:) — interior slot

    @Test("place(cents:) at slot 1 commits and advances to slot 2 (interior)")
    func placeInteriorSlot() async throws {
        let (session, notePlayer) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        notePlayer.reset()
        notePlayer.instantPlayback = true

        session.place(cents: Cents(95.0))

        guard case .walking(let activeSlot, let committed, _) = session.state else {
            Issue.record("Expected .walking, got \(session.state)")
            return
        }
        #expect(activeSlot.index == 2)
        #expect(activeSlot.state == .active)
        #expect(activeSlot.placedCents == nil)
        #expect(committed.count == 1)
        #expect(committed[0].index == 1)
        #expect(committed[0].placedCents == Cents(95.0))
        #expect(committed[0].state == .committed)

        // Orienting cue for slot 2: predecessor's pitch (slot 1 at +95 cents from lower anchor).
        await Task.yield()
        let lowerAnchorFreq = settings.ladder.lowerAnchor.frequency(
            in: .equalTemperament,
            referencePitch: settings.referencePitch
        )
        let expectedPredecessorFreq = lowerAnchorFreq * pow(2.0, Cents(95.0) / Cents.perOctave)
        #expect(notePlayer.lastFrequency == expectedPredecessorFreq.rawValue)
    }

    // MARK: - place(cents:) — final slot (implicit submit)

    @Test("place(cents:) at final slot transitions directly to showingResult (no awaitingSubmit)")
    func placeFinalSlotImplicitSubmit() async throws {
        let (session, notePlayer) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        session.place(cents: Cents(95.0))   // slot 1 commits → spawns slot-2 orienting cue task
        await Task.yield()                  // drain queued play()
        let playCountBeforeFinal = notePlayer.playCallCount

        session.place(cents: Cents(205.0))  // slot 2 commits → showingResult (slotCount = 2)

        guard case .showingResult(let ladder, let committed) = session.state else {
            Issue.record("Expected .showingResult, got \(session.state)")
            return
        }
        #expect(ladder.slotCount == 2)
        #expect(committed.count == 2)
        #expect(committed[1].placedCents == Cents(205.0))
        // No orienting cue for the result phase: place call count must not advance
        // beyond what was already in flight from the prior interior transition.
        await Task.yield()
        #expect(notePlayer.playCallCount == playCountBeforeFinal,
                "place() at final slot must not initiate a new orienting cue")
        // stopAll must be called as part of the final-slot transition.
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    // MARK: - stepBack from walking

    @Test("stepBack at slot 1 is a no-op")
    func stepBackAtSlotOneIsNoOp() async throws {
        let (session, _) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        session.stepBack()

        guard case .walking(let activeSlot, let committed, _) = session.state else {
            Issue.record("Expected .walking")
            return
        }
        #expect(activeSlot.index == 1)
        #expect(committed.isEmpty)
    }

    @Test("stepBack at slot 2 reactivates slot 1 with its previous placedCents preserved")
    func stepBackReactivatesPriorSlot() async throws {
        let (session, _) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        session.place(cents: Cents(95.0))   // slot 1 committed at 95
        session.stepBack()                  // back to slot 1

        guard case .walking(let activeSlot, let committed, _) = session.state else {
            Issue.record("Expected .walking")
            return
        }
        #expect(activeSlot.index == 1)
        #expect(activeSlot.state == .active)
        #expect(activeSlot.placedCents == Cents(95.0))  // previous value preserved
        #expect(committed.isEmpty)
    }

    // MARK: - stepBack from showingResult

    @Test("stepBack in showingResult returns to walking at final slot with its placedCents preserved")
    func stepBackFromShowingResult() async throws {
        let (session, _) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        session.place(cents: Cents(95.0))
        session.place(cents: Cents(205.0))  // showingResult

        session.stepBack()

        guard case .walking(let activeSlot, let committed, _) = session.state else {
            Issue.record("Expected .walking after stepBack from showingResult")
            return
        }
        #expect(activeSlot.index == 2)
        #expect(activeSlot.placedCents == Cents(205.0))
        #expect(committed.count == 1)
        #expect(committed[0].placedCents == Cents(95.0))
    }

    // MARK: - nextTrial

    @Test("nextTrial in showingResult returns to idle")
    func nextTrialReturnsToIdle() async throws {
        let (session, _) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        session.place(cents: Cents(95.0))
        session.place(cents: Cents(205.0))

        session.nextTrial()

        guard case .idle = session.state else {
            Issue.record("Expected .idle")
            return
        }
        #expect(session.isIdle)
    }

    @Test("nextTrial while walking is a no-op")
    func nextTrialWhileWalkingIsNoOp() async throws {
        let (session, _) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)

        session.nextTrial()

        guard case .walking(let activeSlot, _, _) = session.state else {
            Issue.record("Expected .walking")
            return
        }
        #expect(activeSlot.index == 1)
    }

    // MARK: - pause / resume

    @Test("pause preserves walking state and isIdle stays false")
    func pausePreservesState() async throws {
        let (session, notePlayer) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)
        session.place(cents: Cents(95.0))

        notePlayer.reset()
        notePlayer.instantPlayback = true

        session.pause()

        guard case .walking(let activeSlot, let committed, _) = session.state else {
            Issue.record("Expected .walking preserved")
            return
        }
        #expect(activeSlot.index == 2)
        #expect(committed.count == 1)
        #expect(!session.isIdle)
        await Task.yield()
        #expect(notePlayer.stopAllCallCount >= 1, "pause must call scheduleStopAll")
    }

    @Test("resume replays the active-slot orienting cue without changing state")
    func resumeReplaysOrientingCue() async throws {
        let (session, notePlayer) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)
        session.place(cents: Cents(95.0))
        session.pause()

        notePlayer.reset()
        notePlayer.instantPlayback = true

        session.resume()

        guard case .walking(let activeSlot, _, _) = session.state else {
            Issue.record("Expected .walking after resume")
            return
        }
        #expect(activeSlot.index == 2)

        await Task.yield()
        // Predecessor pitch (slot 1 at +95 cents from lower anchor) is the cue.
        let lowerAnchorFreq = settings.ladder.lowerAnchor.frequency(
            in: .equalTemperament,
            referencePitch: settings.referencePitch
        )
        let expectedPredecessorFreq = lowerAnchorFreq * pow(2.0, Cents(95.0) / Cents.perOctave)
        #expect(notePlayer.lastFrequency == expectedPredecessorFreq.rawValue)
    }

    @Test("pause from idle is a no-op")
    func pauseFromIdleIsNoOp() async {
        let (session, notePlayer) = Self.makeSession()
        session.pause()
        await Task.yield()
        #expect(session.isIdle)
        #expect(notePlayer.stopAllCallCount == 0)
    }

    // MARK: - stop

    @Test("stop returns to idle and clears state")
    func stopClearsState() async throws {
        let (session, notePlayer) = Self.makeSession()
        let settings = try Self.makeAscendingP3Settings()
        session.start(settings: settings)
        session.place(cents: Cents(95.0))

        notePlayer.reset()
        notePlayer.instantPlayback = true

        session.stop()

        #expect(session.isIdle)
        guard case .idle = session.state else {
            Issue.record("Expected .idle")
            return
        }
        await Task.yield()
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from idle is a no-op (no audio call)")
    func stopFromIdleIsNoOp() async {
        let (session, notePlayer) = Self.makeSession()
        session.stop()
        await Task.yield()
        #expect(session.isIdle)
        #expect(notePlayer.stopAllCallCount == 0)
    }
}

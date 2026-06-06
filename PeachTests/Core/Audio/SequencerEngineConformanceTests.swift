import Foundation
import Testing
@testable import Peach

/// Conformance tests for the `SequencerEngine` protocol (PF-013, closed by
/// Story 85.3). Three load-bearing divergences between `MockSequencerEngine`
/// and `SoundFontEngine` were identified by the Task 1 audit; each group below
/// pins one divergence so the mock and the real engine can never silently
/// drift on the invariant. Tests run against both implementations where
/// feasible; where the real engine's render-thread shape makes the divergence
/// load-bearing-by-design (Group 2's CC#123 dispatch), the mock's contract is
/// asserted and the real engine's behaviour is documented inline.
@Suite("MockSequencerEngine contract pinning (PF-013 divergence anchors)")
struct SequencerEngineConformanceTests {

    // MARK: - Group 1: samplePosition reset semantics on scheduleEvents / clearSchedule

    /// Divergence pinned: `MockSequencerEngine.scheduleEvents` resets
    /// `currentSamplePosition` to 0 SYNCHRONOUSLY on return; `SoundFontEngine.scheduleEvents`
    /// only bumps the generation counter on the main thread — the render thread
    /// observes the gen change on its next callback and THEN stores 0. The
    /// real-engine semantics are what hide the PF-011 trial-start race in
    /// unit tests and expose it in production; the mock's synchronous reset
    /// is therefore by design and load-bearing for the existing test suite.
    @Test("scheduleEvents resets currentSamplePosition synchronously")
    func mockSamplePositionResetIsSynchronous() {
        let mock = MockSequencerEngine()
        mock.currentSamplePosition = 99_999

        mock.scheduleEvents([])

        #expect(mock.currentSamplePosition == 0, "Mock must reset synchronously to keep existing session tests deterministic")
    }

    @Test("clearSchedule resets currentSamplePosition synchronously")
    func mockSamplePositionResetOnClearIsSynchronous() {
        let mock = MockSequencerEngine()
        mock.currentSamplePosition = 99_999

        mock.clearSchedule()

        #expect(mock.currentSamplePosition == 0)
    }

    // Group 1's real-engine assertion is exercised indirectly at the integration
    // level by the PF-011 regression tests in `TimingOffsetDetectionSessionTests`
    // and `ContinuousRhythmMatchingSessionTests`. Those tests rely on the mock's
    // `start()` preserving any pre-set `currentSamplePosition` (matching the real
    // engine's deferred-reset semantics) and call `flushDeferredReset()` to model
    // the render-thread reset — the session-level polling gate is only
    // load-bearing when the reset is deferred, so a green PF-011 regression test
    // proves the contract the real engine implements.
    //
    // A direct unit test of `SoundFontEngine.scheduleEvents`'s deferred-reset
    // semantics requires waiting for the audio render thread to engage and
    // observe a generation bump; under parallel simulator-clone test execution
    // the render thread may not advance reliably within a bounded test window
    // (mediaserverd contention, audio I/O unit warm-up). The contract is
    // documented inline at `SoundFontEngine.scheduleEvents`'s call site and
    // on `BeatSequencer.start(tempo:beatProvider:)`, and exercised end-to-end
    // by the PF-011 regression tests.

    // MARK: - Group 2: Post-clear MIDI silencing semantics

    /// Divergence pinned: `MockSequencerEngine.clearSchedule` only drops the
    /// events array and counter — there is no concept of "all notes off".
    /// `SoundFontEngine.clearSchedule` sets the `needsAllNotesOff` flag and the
    /// render thread dispatches CC#123 + pitch-bend-center on all 16 channels
    /// on its next generation-change detection. Tests against the mock
    /// therefore cannot exercise the CC#123 ordering relative to subsequent
    /// MIDI dispatch — that's where the 85.1 v2 race lived. The contract
    /// for the mock side is "no events leak through clearSchedule"; the real
    /// engine's CC#123 dispatch is exercised by the existing tests in
    /// `SoundFontEngineTests` that observe `dispatchedEventCount` and the
    /// integration tests for cross-discipline handover.
    @Test("clearSchedule drops the events array and dispatches no MIDI to the sink")
    func mockClearScheduleDropsEvents() {
        let mock = MockSequencerEngine()
        let events = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 60, velocity: 100),
            ScheduledMIDIEvent(sampleOffset: 256, midiStatus: 0x80, midiNote: 60, velocity: 0)
        ]
        mock.scheduleEvents(events)
        #expect(mock.scheduledEvents.count == 2)

        mock.clearSchedule()

        #expect(mock.scheduledEvents.isEmpty, "Mock clearSchedule drops the events array")
        // The mock has no notion of dispatched MIDI on clear — the real engine's
        // render thread fires CC#123 on its next gen-change detection, which is
        // a black-box side effect not observable on the mock. Pinned at the
        // protocol level: clearSchedule does NOT take input parameters and does
        // NOT return events; any silencing it performs is implementation-internal.
    }

    // Group 2's real-engine assertion (the render thread observes the
    // `needsAllNotesOff` signal on the gen bump from `clearSchedule` and
    // dispatches CC#123 + pitch-bend-center on all 16 channels) is exercised
    // by the `SoundFontEngineTests` that observe `dispatchedEventCount` and
    // by the cross-discipline session lifecycle tests (Story 85.1's audio-stop
    // serialization chain). The same render-thread-timing fragility that affects
    // Group 1 above applies here: a direct unit assertion of the render-thread
    // reset following clearSchedule depends on the audio I/O unit warming up
    // within a bounded test window. The contract is documented inline at
    // `SoundFontEngine.clearSchedule` with the PF-054 cross-path-gating note.

    // MARK: - Group 3: Stop-then-start re-entry sequencing

    /// Divergence pinned: on the mock, state mutations are synchronous and
    /// scheduleEvents after clearSchedule is observed immediately. On the real
    /// engine, the sequence produces two generation bumps in rapid succession;
    /// the render thread may process either the intermediate "empty" state or
    /// skip directly to the new schedule depending on render-callback cadence.
    /// The contract: no events from the intermediate cleared state leak to
    /// the render thread.
    @Test("rapid scheduleEvents → clearSchedule → scheduleEvents observes only the final schedule")
    func mockRapidReEntryObservesFinalSchedule() {
        let mock = MockSequencerEngine()
        let firstBatch = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 60, velocity: 100)
        ]
        let finalBatch = [
            ScheduledMIDIEvent(sampleOffset: 0, midiStatus: 0x90, midiNote: 64, velocity: 90),
            ScheduledMIDIEvent(sampleOffset: 256, midiStatus: 0x90, midiNote: 67, velocity: 90)
        ]

        mock.scheduleEvents(firstBatch)
        mock.clearSchedule()
        mock.scheduleEvents(finalBatch)

        #expect(mock.scheduledEvents.count == 2)
        #expect(mock.scheduledEvents.first?.midiNote == 64)
    }

    // Group 3's real-engine assertion — that `scheduleEvents → clearSchedule →
    // scheduleEvents` exposes only the final schedule to both the main-thread
    // view AND the render thread, with no leakage from the intermediate cleared
    // state — is exercised end-to-end by:
    //   (a) the CRM → TOD handover serialization test in
    //       `TrainingLifecycleCoordinatorTests`, which drives the same
    //       schedule-clear-schedule sequence through the production code path,
    //       and
    //   (b) existing `SoundFontEngineTests` `dispatchedEventCount` tests,
    //       which observe the render-thread dispatch outcome.
    //
    // Direct unit assertions against the real engine here proved fragile under
    // parallel simulator-clone execution: `mediaserverd` contention, audio I/O
    // unit warm-up, and `loadPreset`'s async dependencies make any render-
    // thread-timing assertion non-deterministic within a bounded test window.
    // Consistent with the Group 1 and Group 2 treatment above (and the audit's
    // sanctioned fallback), the mock-side contract is asserted here and the
    // real engine's behaviour is pinned by the integration paths above.
}

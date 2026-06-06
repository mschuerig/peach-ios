protocol BeatSequencer {
    var currentBeat: Beat? { get }
    var timing: SequencerTiming { get }

    /// Starts the sequencer at `tempo`, driving `beatProvider.nextBeat()` for
    /// the duration of the run.
    ///
    /// **Polling-task contract — post-start `samplePosition` reset latency.**
    /// The reset of `timing.samplePosition` to 0 is observed on the render
    /// thread's next callback, NOT synchronously on return — the production
    /// implementation (`SoundFontBeatSequencer` → `SoundFontEngine`) only
    /// bumps a generation counter on the main thread; the render thread
    /// detects the change and stores 0 on its next callback. Caller polling
    /// tasks that derive cycle / subdivision indices from `samplePosition`
    /// MUST gate their first cap-check / cycle-accumulation against the
    /// pre-start `samplePosition` value: capture it IMMEDIATELY BEFORE
    /// `await`ing `start(...)` and skip those checks while
    /// `timing.samplePosition >= (captured upper bound)`. A post-await
    /// snapshot races the render thread — by the time control returns the
    /// reset may already be observed and the upper bound is lost. Otherwise
    /// an unlucky polling tick at the boundary reads the previous trial's
    /// tail and trips the cap before any audible note. See PF-011 audit
    /// (Story 85.3 spec) and `TimingOffsetDetectionSession` /
    /// `ContinuousRhythmMatchingSession` for the canonical caller-side gate.
    func start(tempo: TempoBPM, beatProvider: any BeatProvider) async throws

    func stop() async throws
    func playImmediateNote(velocity: MIDIVelocity) throws
    func samplePosition(forHostTime hostTime: UInt64) -> Int64
}

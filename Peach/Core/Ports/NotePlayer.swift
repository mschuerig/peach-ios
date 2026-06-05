protocol NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle

    func play(frequency: Frequency, duration: Duration, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws

    func stopAll() async throws

    /// Synchronously enqueues a stop-all onto the player's serial audio chain.
    /// Use this from synchronous contexts — state-machine effects, `pause()`,
    /// `stop()` — so the stop's slot is committed at call time. A subsequent
    /// `play()` (whose registration only happens when its `Task` body runs)
    /// then necessarily sees the stop in the chain regardless of `Task`
    /// scheduling order. Spawning `Task { await stopAll() }` instead defers
    /// registration to the `Task` body and races every concurrent `play()`.
    @discardableResult
    func scheduleStopAll() -> Task<Void, Never>
}

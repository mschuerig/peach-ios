protocol NotePlayer {
    func play(frequency: Frequency, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws -> PlaybackHandle

    func play(frequency: Frequency, duration: Duration, velocity: MIDIVelocity, amplitudeDB: AmplitudeDB) async throws

    func stopAll() async throws
}

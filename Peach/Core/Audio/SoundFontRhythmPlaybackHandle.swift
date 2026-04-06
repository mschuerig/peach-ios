final class SoundFontRhythmPlaybackHandle: RhythmPlaybackHandle {

    private let engine: SoundFontEngine
    private let channel: MIDIChannel
    private var hasStopped = false

    init(engine: SoundFontEngine, channel: MIDIChannel) {
        self.engine = engine
        self.channel = channel
    }

    func stop() async throws {
        guard !hasStopped else { return }
        hasStopped = true
        engine.clearSchedule()
        await engine.stopNotes(channel: channel, stopPropagationDelay: .zero)
    }
}

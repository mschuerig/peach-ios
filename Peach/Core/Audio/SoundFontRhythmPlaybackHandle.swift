final class SoundFontRhythmPlaybackHandle: RhythmPlaybackHandle {

    private let engine: SoundFontEngine
    private let channel: SoundFontEngine.ChannelID
    private var hasStopped = false

    init(engine: SoundFontEngine, channel: SoundFontEngine.ChannelID) {
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

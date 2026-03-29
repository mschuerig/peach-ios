@testable import Peach

final class MockStepSequencerEngine: StepSequencerEngine {
    var sampleRate: SampleRate = .standard44100
    var currentSamplePosition: Int64 = 0

    private(set) var ensureAudioSessionConfiguredCallCount = 0
    private(set) var ensureEngineRunningCallCount = 0
    private(set) var loadPresetCallCount = 0
    private(set) var scheduledEvents: [ScheduledMIDIEvent] = []
    private(set) var scheduleCallCount = 0
    private(set) var clearScheduleCallCount = 0
    private(set) var stopNotesCallCount = 0
    private(set) var immediateNoteOnCallCount = 0
    private(set) var lastImmediateNoteOnVelocity: UInt8?
    private(set) var lastImmediateNoteOnNote: UInt8?
    private(set) var immediateNoteOffCallCount = 0
    var onImmediateNoteOff: (() -> Void)?

    func ensureAudioSessionConfigured() throws {
        ensureAudioSessionConfiguredCallCount += 1
    }

    func ensureEngineRunning() throws {
        ensureEngineRunningCallCount += 1
    }

    func loadPreset(_ preset: SF2Preset, channel: SoundFontEngine.ChannelID) async throws {
        loadPresetCallCount += 1
    }

    func scheduleEvents(_ events: [ScheduledMIDIEvent]) {
        scheduledEvents = events
        scheduleCallCount += 1
        currentSamplePosition = 0
    }

    func clearSchedule() {
        clearScheduleCallCount += 1
        scheduledEvents = []
        currentSamplePosition = 0
    }

    func stopNotes(channel: SoundFontEngine.ChannelID, stopPropagationDelay: Duration) async {
        stopNotesCallCount += 1
    }

    func immediateNoteOn(channel: SoundFontEngine.ChannelID, note: UInt8, velocity: UInt8) {
        immediateNoteOnCallCount += 1
        lastImmediateNoteOnNote = note
        lastImmediateNoteOnVelocity = velocity
    }

    func immediateNoteOff(channel: SoundFontEngine.ChannelID, note: UInt8, delaySamples: Int64) {
        immediateNoteOffCallCount += 1
        onImmediateNoteOff?()
    }

    var samplePositionForHostTimeOverride: Int64?

    func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
        samplePositionForHostTimeOverride ?? currentSamplePosition
    }
}
